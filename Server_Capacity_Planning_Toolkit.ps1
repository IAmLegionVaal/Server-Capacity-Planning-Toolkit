#requires -Version 5.1
<#
.SYNOPSIS
    Server Capacity Planning Toolkit.
.DESCRIPTION
    Read-only Windows Server capacity and resource assessment reporter.
#>
[CmdletBinding()]
param([string]$OutputPath)
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Server_Capacity_Reports'}
New-Item -Path $OutputPath -ItemType Directory -Force|Out-Null
$os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem;$cpu=Get-CimInstance Win32_Processor
$summary=[PSCustomObject]@{Computer=$env:COMPUTERNAME;OS=$os.Caption;Build=$os.BuildNumber;LastBoot=$os.LastBootUpTime;UptimeHours=[math]::Round(((Get-Date)-$os.LastBootUpTime).TotalHours,2);MemoryGB=[math]::Round($cs.TotalPhysicalMemory/1GB,2);LogicalProcessors=($cpu|Measure-Object NumberOfLogicalProcessors -Sum).Sum;Generated=Get-Date}
$disks=Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3'|ForEach-Object{[PSCustomObject]@{Drive=$_.DeviceID;VolumeName=$_.VolumeName;SizeGB=[math]::Round($_.Size/1GB,2);FreeGB=[math]::Round($_.FreeSpace/1GB,2);FreePercent=[math]::Round(($_.FreeSpace/$_.Size)*100,2)}}
$processes=Get-Process|Sort-Object WorkingSet64 -Descending|Select-Object -First 15 Name,Id,CPU,@{n='MemoryMB';e={[math]::Round($_.WorkingSet64/1MB,2)}}
$summary|Export-Csv (Join-Path $OutputPath "server_summary_$stamp.csv") -NoTypeInformation -Encoding UTF8
$disks|Export-Csv (Join-Path $OutputPath "disk_capacity_$stamp.csv") -NoTypeInformation -Encoding UTF8
$processes|Export-Csv (Join-Path $OutputPath "top_processes_$stamp.csv") -NoTypeInformation -Encoding UTF8
@{Summary=$summary;Disks=$disks;TopProcesses=$processes}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputPath "capacity_report_$stamp.json") -Encoding UTF8
$html="<h1>Server Capacity - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Summary</h2>$(@($summary)|ConvertTo-Html -Fragment)<h2>Disk Capacity</h2>$($disks|ConvertTo-Html -Fragment)<h2>Top Processes</h2>$($processes|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'Server Capacity Planning'|Set-Content (Join-Path $OutputPath "capacity_report_$stamp.html") -Encoding UTF8
$summary|Format-List
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
