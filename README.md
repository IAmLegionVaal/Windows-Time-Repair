# Windows Time Repair

> **Testing note:** This was tested by me to be working. User experience may vary.

## One-click use

1. Download and extract the repository.
2. Double-click `Run-OneClick.bat`.
3. Approve the Windows administrator prompt.
4. The launcher restores the Windows Time service, requests rediscovery and resynchronisation, and validates the final state. There is no menu.
5. Review the exit code and logs in `C:\ProgramData\WindowsTimeRepair\Logs`.

Included script: `Repair-WindowsTime.ps1`

## PowerShell usage

```powershell
.\Repair-WindowsTime.ps1
.\Repair-WindowsTime.ps1 -Repair
.\Repair-WindowsTime.ps1 -TimeZoneId 'South Africa Standard Time'
.\Repair-WindowsTime.ps1 -Repair -WhatIf
```

The script records Windows time configuration, service status, peers and synchronisation state. Time-zone changes require an explicit ID and are not performed by the one-click launcher.

Exit codes: `0` success, `1` fatal error, `2` repair or verification warnings.

Managed devices may receive time settings from policy. MIT License.
