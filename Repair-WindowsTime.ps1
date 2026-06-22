<#
.SYNOPSIS
Diagnoses and repairs Windows time synchronisation.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$Repair,
    [string]$TimeZoneId,
    [string]$LogRoot="$env:ProgramData\WindowsTimeRepair\Logs"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$runPath=Join-Path $LogRoot (Get-Date -Format 'yyyyMMdd_HHmmss')
$warnings=New-Object System.Collections.Generic.List[string]

function Test-Admin{
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Run-W32{
    param([string]$Name,[string[]]$Arguments)
    w32tm.exe @Arguments 2>&1|Out-File (Join-Path $runPath ($Name+'.txt'))
    if($LASTEXITCODE -ne 0){$script:warnings.Add("$Name returned $LASTEXITCODE")}
}

try{
    if($env:OS -ne 'Windows_NT'){throw 'Windows is required.'}
    if(($Repair -or $TimeZoneId) -and -not(Test-Admin)){throw 'Run PowerShell as Administrator for changes.'}
    New-Item $runPath -ItemType Directory -Force|Out-Null

    Get-TimeZone|Format-List *|Out-File (Join-Path $runPath 'TimeZone.txt')
    Get-Service W32Time|Select-Object Name,Status,StartType|Export-Csv (Join-Path $runPath 'TimeService.csv') -NoTypeInformation
    Run-W32 'Status' @('/query','/status')
    Run-W32 'Configuration' @('/query','/configuration')
    Run-W32 'Peers' @('/query','/peers')

    if($TimeZoneId -and $PSCmdlet.ShouldProcess('Windows time zone',"Set to $TimeZoneId")){
        if(-not(Get-TimeZone -ListAvailable|Where-Object Id -eq $TimeZoneId)){throw "Unknown time-zone ID: $TimeZoneId"}
        Set-TimeZone -Id $TimeZoneId
    }

    if($Repair -and $PSCmdlet.ShouldProcess('Windows Time service','Configure, start and resynchronise')){
        Set-Service W32Time -StartupType Automatic
        Start-Service W32Time
        w32tm.exe /resync /rediscover 2>&1|Out-File (Join-Path $runPath 'Resync.txt')
        if($LASTEXITCODE -ne 0){$warnings.Add("Resync returned $LASTEXITCODE")}
    }

    Get-Date|Out-File (Join-Path $runPath 'LocalTime-After.txt')
    $warnings|Out-File (Join-Path $runPath 'Warnings.txt')
    if($warnings.Count -gt 0){Write-Host "[WARN] Completed with warnings. Logs: $runPath" -ForegroundColor Yellow;exit 2}
    Write-Host "[OK] Completed. Logs: $runPath" -ForegroundColor Green;exit 0
}catch{Write-Error $_.Exception.Message;exit 1}
