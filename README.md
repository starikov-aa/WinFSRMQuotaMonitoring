#  Windows Server FSRM quota monitoring

This template is designed to monitor quotas created in the File Server Resource Manager (FSRM) service in Windows Server 2008. Monitoring is performed by parsing reports from the STORREPT.EXE utility

### Main features:
- Discovery of quotas
- Monitoring quota usage

## Macros used
- **{$QUOTA_SCOPE}** - The paths to be scanned. You can specify multiple with |. For example D:\share|C:\dir1
- **{$HIGH_QUOTA_USAGE}** - Maximum quota usage (%) for a trigger with HIGH severity

## Items:
- **Quota usage information** - This is the master item.
- **Quota usage information: Error message** - Error Information
- **Quota usage information: {#FOLDER} quota size in bytes**
- **Quota usage information: {#FOLDER} quota usage in bytes**
- **Quota usage information: {#FOLDER} quota usage in percentage**

## Triggers:
- **Error getting quota information: "{ITEM.LASTVALUE}"**
- **Quota used by {ITEM.LASTVALUE} for {#FOLDER}**

## Discovery rules
| Name |Description|
| :------------ | :------------ |
|   Quota detection  | Macros available:<br>{#KEY} - used to link to the Master Item<br>{#FOLDER} - full path to the folder for which the quota was found. For example: D:\Shares\user<br>{#FOLDER_URL} network path to {#FOLDER}. For example: \\\\FS\Shares\user |

## Requirements:
- Windows Server 2008R2
- Powerhell
- Zabbix >= 4.2 versions

## It was checked for:
PowerShell v5.0, Windows Server 2008R2, Zabbix 5.4.3

## Installation:
1. Import a template
2. Assign template to host
3. On the host, in the {$QUOTA_SCOPE} macro, specify the directories to be scanned
4. Copy the script to a machine with FSRM, for example, in the Zabbix Agent folder
5. Add to zabbix_agentd.conf:

```
Timeout = 30
UnsafeUserParameters=1
UserParameter=WinFSRMQuotaMonitoring[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\WinFSRMQuotaMonitoring.ps1" "$1" "$2"
```