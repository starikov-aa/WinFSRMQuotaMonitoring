<#PSScriptInfo
.VERSION 1.0
.GUID f5ab33b9-a1b7-4fa7-8e63-3c1e3b7ac8d3
.AUTHOR Starikov Anton < starikov_aa@mail.ru >
.COPYRIGHT (c) 2022 Starikov Anton
.PROJECTURI https://github.com/starikov-aa/WinFSRMQuotaMonitoring
#>

<#
.SYNOPSIS
Collecting and sending quota information to Zabbix

.DESCRIPTION
Collects information on quotas created in the File Server Resource Manager (FSRM) service in Windows Server 2008.
The script is based on parsing reports from the STORREPT.EXE utility.

.PARAMETER COMMAND
DiscoverQuotas - Discover quotas
GetQuotasUsage - Get quotas information

.PARAMETER SCOPE
The paths to be scanned. You can specify multiple with |. For example D:\share|C:\dir1

.OUTPUTS
JSON for Zabbix

.NOTES
# Zabbix agent config
# UserParameter=WinFSRMQuotaMonitoring[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\WinFSRMQuotaMonitoring.ps1" "$1" "$2"

.EXAMPLE
WinFSRMQuotaMonitoring.ps1 DiscoverQuotas C:\shares
#>

param (
	[Parameter(Mandatory = $true)]
	[string]$COMMAND = $args[0],
	[Parameter(Mandatory = $true)]
	[string]$SCOPE = $args[1]
)

$OutputEncoding = [System.Console]::OutputEncoding = [System.Console]::InputEncoding = [System.Text.Encoding]::UTF8

function GenQuotaUsageReport([string]$Scope) {
	<#
.DESCRIPTION
	Runs the storrept.exe utility to generate a quota usage report
	
.PARAMETER Scope
	The paths to be scanned. You can specify multiple with |. For example D:\share|C:\dir1

.OUTPUTS
	The report file name
#>
	# for debug
	if ($env:WinFSRMQuotaMonitoring_TEST_REPORT -eq "yes") {
		return "QuotaUsage.xml"
	}

	if ($Scope -eq "") {
		return $false
	}
	
	$ReportDir = "C:\StorageReports\Interactive"

	if (Test-Path $ReportDir) {
		Remove-Item -Path "$($ReportDir)\zabbix*" -Recurse
	}

	$process = Start-Process storrept.exe -ArgumentList "reports generate /report:quotausage /Name:zabbix /scope:""$($Scope)"" /minuse:0 /format:""xml""" -PassThru -Wait -WindowStyle Hidden

	if ($process.ExitCode -eq 0) {
		return $(Get-ChildItem -Path "$($ReportDir)\zabbix*.xml" | Sort-Object CreationTime -Descending | Select-Object -First 1).Name
	}
 else {
		return -1
	}
}

function GetQuotas([string]$ReportFile) {
	<#
.DESCRIPTION
	Gets quota data from a report
	
.PARAMETER ReportFile
	Full path to the report file

.OUTPUTS
	Array with data on quotas
#>
	if ((Test-Path -Path $ReportFile) -And (-Not (Get-Item -Path $ReportFile).PSIsContainer)) {
		try {
			[xml] $xml = Get-Content -Path $ReportFile
			return $xml.StorageReport.ReportData.ChildNodes
		}
		catch {
			return $false
		}
	}
 else {
		return $false
	}
}

function DiscoverQuotas([array]$Quotas) {
	<#
.DESCRIPTION
	Generates JSON with data to detect quotas
	
.PARAMETER Quotas
	Array with data on quotas

.OUTPUTS
	JSON string | $false
#>
	if ($Quotas -isnot [array]) {
		return $false
	} 

	$result = @()
	$Quotas | % {
		$result += @{
			"{#KEY}"        = $_.Folder -replace '(?i)[^а-яa-z0-9\s]+?', '-'
			"{#FOLDER}"     = $_.Folder;
			"{#FOLDER_URL}" = $_.FolderURL
		}
	}
	return MakeJson $result
}

function GetQuotasUsage([array]$Quotas) {
	<#
.DESCRIPTION
	Generates JSON with quota usage data
	
.PARAMETER Quotas
	Array with data on quotas

.OUTPUTS
	JSON string | $false
#>
	if ($Quotas -isnot [array]) {
		return $false
	} 

	$result = @{}
	$Quotas | % {
		$key = $_.Folder -replace '(?i)[^а-яa-z0-9\s]+?', '-'
		$result += @{$key = @{
				"Used"        = $_.Used;
				"PercentUsed" = $_.PercentUsed.replace(",", ".")
				"Limit"       = $_.Limit;
			}
  }
	}
	return MakeJson $result
}

function MakeJson ($data) {
	<#
.DESCRIPTION
	Make JSON
	
.PARAMETER data
	Data for convert fo json

.OUTPUTS
	JSON string
#>

	return @{ 'data' = $data } | ConvertTo-Json -Compress
}

function ShowError($text, $Exit = $false) {
	<#
.DESCRIPTION
	Error display in JSON format
	
.PARAMETER text
	Text to show

.PARAMETER Exit
	If true, then exit the script after showing the error

.OUTPUTS
	JSON string
#>
	Write-Host (MakeJson @{ 'error' = $text }).ToString()
	if ($Exit) {
		Exit
	}
}

if (@('DiscoverQuotas', 'GetQuotasUsage') -notcontains $COMMAND) {
	ShowError 'Incorrect value of the $COMMAND parameter' $true
}

$QuotaReport = GenQuotaUsageReport $SCOPE

if ($QuotaReport -eq -1) {
	ShowError 'Error starting STORREPT.EXE utility' $true
}
elseif (-Not $QuotaReport) {
	ShowError 'Error generating quota usage report' $true
}

$QuotasList = GetQuotas "C:\StorageReports\Interactive\$($QuotaReport)"

if (-Not $QuotasList) {
	ShowError "No quota info in file $($QuotaReport)" $true
}

switch ($COMMAND) {
	'DiscoverQuotas' {
		DiscoverQuotas $QuotasList
	}

	'GetQuotasUsage' {
		GetQuotasUsage $QuotasList
	}
}