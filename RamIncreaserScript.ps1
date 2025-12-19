$Host.UI.RawUI.WindowTitle = 'Committed RAM Increaser'
$ErrorActionPreference = 'Stop'

function Show-Header {
    Clear-Host
    Write-Host '==================================================' -ForegroundColor Cyan
    Write-Host '           COMMITTED RAM INCREASER TOOL           ' -ForegroundColor White
    Write-Host '               Made by Pratyaksh                  ' -ForegroundColor Yellow
    Write-Host '        https://github.com/OneforAll-Deku         ' -ForegroundColor Gray
    Write-Host '==================================================' -ForegroundColor Cyan
    Write-Host ''
}

try {
    Show-Header
    Write-Host '[*] Analyzing System Memory...' -ForegroundColor Yellow
    $sysInfo = Get-CimInstance Win32_ComputerSystem
    $ramMB = $sysInfo.TotalPhysicalMemory / 1MB
    $ramGB = [math]::Round($ramMB / 1024, 2)
    Write-Host "    Physical RAM: $ramGB GB" -ForegroundColor Gray

    $pagefile = Get-CimInstance Win32_PageFileUsage
    if ($pagefile) {
        $currentLimit = [math]::Round(($ramMB + ($pagefile | Measure-Object -Property AllocatedBaseSize -Sum).Sum) / 1024, 2)
        Write-Host "    Current Estimated Commit Limit: ~$currentLimit GB" -ForegroundColor Gray
    }
    else {
        Write-Host "    Current PageFile: System Managed / None" -ForegroundColor Gray
    }

    $targetMin = 16384
    $targetMax = 32768
    if ($ramMB -gt 16384) {
        $targetMin = $ramMB 
        $targetMax = $ramMB * 2
    }

    Write-Host '--------------------------------------------------' -ForegroundColor DarkGray
    Write-Host " Proposed Settings:" -ForegroundColor Cyan
    Write-Host "  - Initial Size: $([math]::Round($targetMin/1024, 1)) GB" -ForegroundColor White
    Write-Host "  - Maximum Size: $([math]::Round($targetMax/1024, 1)) GB" -ForegroundColor White
    Write-Host ''
    Write-Host ' [1] Apply Optimization (Recommended)' -ForegroundColor Green
    Write-Host ' [2] Revert to Windows Default' -ForegroundColor Yellow
    Write-Host ' [3] Exit' -ForegroundColor Red
    Write-Host ''
    
    $choice = Read-Host ' Enter your choice [1]'

    if ($choice -eq '' -or $choice -eq '1') {
        Write-Host ''
        Write-Host '[*] Applying settings...' -ForegroundColor Yellow
        
        try {
            $sys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
            if ($sys.AutomaticManagedPagefile) {
                $sys.AutomaticManagedPagefile = $false
                $sys.Put() | Out-Null
                Write-Host '    - Automatic Management Disabled (WMI).' -ForegroundColor Gray
            }
        }
        catch {
            Write-Host '    [!] method 1 failed, trying fallback method...' -ForegroundColor Yellow
            $res = cmd /c "wmic computersystem where name='%computername%' set AutomaticManagedPagefile=False" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host '    - Automatic Management Disabled (WMIC).' -ForegroundColor Gray
            }
            else {
                throw "Failed to disable automatic pagefile. Error: $res"
            }
        }

        try {
            $pfs = Get-WmiObject Win32_PageFileSetting -EnableAllPrivileges
            if ($pfs) { 
                $pfs | ForEach-Object { $_.Delete() } 
                Start-Sleep -Seconds 1
            }

            Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name = 'C:\pagefile.sys'; InitialSize = $targetMin; MaximumSize = $targetMax } -EnableAllPrivileges | Out-Null
            
            Write-Host '    - PageFile Size set successfully.' -ForegroundColor Green
            Write-Host ''
            Write-Host '[SUCCESS] Committed RAM Limit Increased!' -ForegroundColor Cyan
            Write-Host 'You MUST restart your PC for these changes to take full effect.' -ForegroundColor Red
        }
        catch {
            Write-Host '    [!] Failed to set new PageFile size.' -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host '    Attempting fallback via WMIC...' -ForegroundColor Yellow
            
            cmd /c "wmic pagefileset where name='C:\\pagefile.sys' set InitialSize=$targetMin,MaximumSize=$targetMax" | Out-Null
            cmd /c "wmic pagefileset create name='C:\\pagefile.sys', InitialSize=$targetMin, MaximumSize=$targetMax" | Out-Null
            
            Write-Host '[INFO] Fallback commands executed. Please check settings after restart.' -ForegroundColor Yellow
        }

    }
    elseif ($choice -eq '2') {
        Write-Host '[*] Reverting...' -ForegroundColor Yellow
        cmd /c "wmic computersystem where name='%computername%' set AutomaticManagedPagefile=True" | Out-Null
        Write-Host '[SUCCESS] Reverted to System Managed.' -ForegroundColor Green
        Write-Host 'Restart required.' -ForegroundColor Red
    }
}
catch {
    Write-Host ''
    Write-Host '[ERROR] An error occurred.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ''
Read-Host 'Press Enter to Exit...'
