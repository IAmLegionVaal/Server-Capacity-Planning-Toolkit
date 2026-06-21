# Server Capacity Planning Toolkit

Created by **Dewald Pretorius**.

A read-only PowerShell 5.1 toolkit for Windows Server capacity assessment and automation-friendly threshold validation.

## Files

- `Server_Capacity_Planning_Toolkit.ps1` — CPU, memory, disk, uptime, and top-process reports.
- `Validate-Capacity.ps1` — evaluates configurable disk, memory, and processor thresholds and returns meaningful exit codes.

```powershell
.\Server_Capacity_Planning_Toolkit.ps1
.\Validate-Capacity.ps1
.\Validate-Capacity.ps1 -MinimumDiskFreePercent 20 -MinimumMemoryAvailablePercent 20 -MaximumProcessorLoadPercent 80
```

Validation exits with `0` when healthy, `1` when a threshold warning is found, and `5` when data collection fails. JSON and CSV evidence is written to the report directory.

The toolkit intentionally does not resize disks, stop workloads, change virtual hardware, or alter production capacity. Source-reviewed for Windows PowerShell 5.1; not runtime-tested on every server platform.
