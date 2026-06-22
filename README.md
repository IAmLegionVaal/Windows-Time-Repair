# Windows Time Repair

> **Testing note:** This was tested by me to be working. User experience may vary.

Included script: `Repair-WindowsTime.ps1`

```powershell
.\Repair-WindowsTime.ps1
.\Repair-WindowsTime.ps1 -Repair
.\Repair-WindowsTime.ps1 -TimeZoneId 'South Africa Standard Time'
```

The script records Windows time status and provides optional synchronisation and timezone actions with `-WhatIf` support.

Logs: `C:\ProgramData\WindowsTimeRepair\Logs`

Exit codes: `0` success, `1` fatal error, `2` warnings.

Use at your own risk. Managed devices may receive time settings from policy.

MIT License.
