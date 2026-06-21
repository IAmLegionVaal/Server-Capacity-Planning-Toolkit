#requires -Version 5.1
<#
.SYNOPSIS
  Validates server capacity against configurable thresholds.
.DESCRIPTION
  Created by Dewald Pretorius. This is intentionally read-only: capacity
  planning should report risk rather than change production resources.
#>
[CmdletBinding()]
param(
    [ValidateRange(1,100)][int]$MinimumDiskFreePercent=15,
    [ValidateRange(1,100)][int]$MinimumMemoryAvailablePercent=15,
    [ValidateRange(1,100)][int]$MaximumProcessorLoadPercent=85,
    [string]$OutputPath=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'Server_Capacity_Reports')
)
$ErrorActionPreference='Stop'
$ExitHealthy=0;$ExitWarning=1;$ExitPrerequisite=3;$ExitFailure=5
try{
    New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
    $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
    $os=Get-CimInstance Win32_OperatingSystem
    $cpu=@(Get-CimInstance Win32_Processor)
    $disks=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3')
    if(-not $os -or $cpu.Count -eq 0){throw 'Required CIM data was not available.'}
    $memoryAvailablePercent=[math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,2)
    $processorLoad=[math]::Round((($cpu|Measure-Object LoadPercentage -Average).Average),2)
    $diskRows=@($disks|ForEach-Object{
        $freePercent=if($_.Size -gt 0){[math]::Round(($_.FreeSpace/$_.Size)*100,2)}else{0}
        [pscustomobject]@{Drive=$_.DeviceID;SizeGB=[math]::Round($_.Size/1GB,2);FreeGB=[math]::Round($_.FreeSpace/1GB,2);FreePercent=$freePercent;Pass=($freePercent -ge $MinimumDiskFreePercent)}
    })
    $findings=@()
    if($memoryAvailablePercent -lt $MinimumMemoryAvailablePercent){$findings+="Available memory is $memoryAvailablePercent%, below $MinimumMemoryAvailablePercent%."}
    if($processorLoad -gt $MaximumProcessorLoadPercent){$findings+="Processor load is $processorLoad%, above $MaximumProcessorLoadPercent%."}
    foreach($disk in $diskRows|Where-Object{-not $_.Pass}){$findings+="Drive $($disk.Drive) has $($disk.FreePercent)% free, below $MinimumDiskFreePercent%."}
    $result=[ordered]@{
        Computer=$env:COMPUTERNAME;Generated=(Get-Date);MemoryAvailablePercent=$memoryAvailablePercent;ProcessorLoadPercent=$processorLoad
        Thresholds=[ordered]@{MinimumDiskFreePercent=$MinimumDiskFreePercent;MinimumMemoryAvailablePercent=$MinimumMemoryAvailablePercent;MaximumProcessorLoadPercent=$MaximumProcessorLoadPercent}
        Disks=$diskRows;Findings=$findings;Status=$(if($findings.Count){'Warning'}else{'Healthy'})
    }
    $result|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $OutputPath "capacity_validation_$stamp.json") -Encoding UTF8
    $diskRows|Export-Csv -LiteralPath (Join-Path $OutputPath "capacity_disks_$stamp.csv") -NoTypeInformation -Encoding UTF8
    $result|Select-Object Computer,Generated,MemoryAvailablePercent,ProcessorLoadPercent,Status|Format-List
    if($findings.Count){$findings|ForEach-Object{Write-Warning $_};exit $ExitWarning}
    Write-Host 'Capacity validation passed.' -ForegroundColor Green
    exit $ExitHealthy
}catch{Write-Error $_.Exception.Message;exit $ExitFailure}
