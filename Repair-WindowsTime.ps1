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
    param([string]$Name,[string[]]$Arguments,[switch]$RecordFailure)
    w32tm.exe @Arguments 2>&1|Out-File (Join-Path $runPath ($Name+'.txt'))
    $code=$LASTEXITCODE
    if($RecordFailure -and $code -ne 0){$script:warnings.Add("$Name returned $code")}
    $code
}

try{
    if($env:OS -ne 'Windows_NT'){throw 'Windows is required.'}
    if(($Repair -or $TimeZoneId) -and -not(Test-Admin)){throw 'Run PowerShell as Administrator for changes.'}
    New-Item $runPath -ItemType Directory -Force|Out-Null

    Get-TimeZone|Format-List *|Out-File (Join-Path $runPath 'TimeZone-Before.txt')
    Get-Service W32Time -ErrorAction Stop|Select-Object Name,Status,StartType|Export-Csv (Join-Path $runPath 'TimeService-Before.csv') -NoTypeInformation
    [void](Run-W32 'Status-Before' @('/query','/status') -RecordFailure:(-not $Repair))
    [void](Run-W32 'Configuration-Before' @('/query','/configuration') -RecordFailure:(-not $Repair))
    [void](Run-W32 'Peers-Before' @('/query','/peers') -RecordFailure:(-not $Repair))

    if($TimeZoneId -and $PSCmdlet.ShouldProcess('Windows time zone',"Set to $TimeZoneId")){
        if(-not(Get-TimeZone -ListAvailable|Where-Object Id -eq $TimeZoneId)){throw "Unknown time-zone ID: $TimeZoneId"}
        Set-TimeZone -Id $TimeZoneId -ErrorAction Stop
    }

    if($Repair -and $PSCmdlet.ShouldProcess('Windows Time service','Configure, start and resynchronise')){
        Set-Service W32Time -StartupType Automatic -ErrorAction Stop
        $service=Get-Service W32Time -ErrorAction Stop
        if($service.Status -ne 'Running'){Start-Service W32Time -ErrorAction Stop}
        (Get-Service W32Time -ErrorAction Stop).WaitForStatus('Running',[TimeSpan]::FromSeconds(30))

        w32tm.exe /resync /rediscover 2>&1|Out-File (Join-Path $runPath 'Resync.txt')
        if($LASTEXITCODE -ne 0){$warnings.Add("Resync returned $LASTEXITCODE")}
    }

    Get-TimeZone|Format-List *|Out-File (Join-Path $runPath 'TimeZone-After.txt')
    $after=Get-Service W32Time -ErrorAction Stop
    $after|Select-Object Name,Status,StartType|Export-Csv (Join-Path $runPath 'TimeService-After.csv') -NoTypeInformation
    [void](Run-W32 'Status-After' @('/query','/status') -RecordFailure)
    [void](Run-W32 'Configuration-After' @('/query','/configuration') -RecordFailure)
    [void](Run-W32 'Peers-After' @('/query','/peers') -RecordFailure)
    Get-Date|Out-File (Join-Path $runPath 'LocalTime-After.txt')

    if($Repair -and $after.Status -ne 'Running'){$warnings.Add('Windows Time service is not running after repair.')}
    if($TimeZoneId -and (Get-TimeZone).Id -ne $TimeZoneId){$warnings.Add("Time zone verification failed for $TimeZoneId.")}

    $warnings|Out-File (Join-Path $runPath 'Warnings.txt') -Encoding UTF8
    if($warnings.Count -gt 0){Write-Host "[WARN] Completed with warnings. Logs: $runPath" -ForegroundColor Yellow;exit 2}
    Write-Host "[OK] Completed. Logs: $runPath" -ForegroundColor Green;exit 0
}catch{Write-Error $_.Exception.Message;exit 1}
