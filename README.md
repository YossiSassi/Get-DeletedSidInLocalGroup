# Get-DeletedSidInLocalGroup
### Get deleted domain accounts (showing just SIDs) in Local Groups membership
Helps with assessing deleted domain accounts (showing just SIDs) in Local Group membership, to aid with cleanup later.<br>
Can run with SCCM (locally), WinRM (Remotely) or any other agent/tool.<br>
Results can be collected via WEC/WEF, or queried remotely from the event log, event id 666 😈<br><br>
#### EXAMPLES ####
Example 1:
```
.\Get-DeletedSidInLocalGroup.ps1 -ComputerName lon-cl1
```
Check for deleted SIDs (deleted domain accounts still members in local groups on the remote host). <br>
![Sample results](/screenshots/getdeletedsids_sshot1.png) <br><br>

Example 2:
```
.\Get-DeletedSidInLocalGroup.ps1 -ComputerName lon-cl1 -WriteResultToEventLog
```
Check for deleted SIDs on the Remote host, and write results to the local event log:<br>
![Sample results](/screenshots/getdeletedsids_sshot2.png) <br><br>

Example 3:
```
Get-WinEvent -ComputerName lon-cl1 -FilterHashtable @{logname='System';id=666} -MaxEvents 1 | select -ExpandProperty message
```
Get the event log entry with the results, and show the message:<br>
![Sample results](/screenshots/getdeletedsids_sshot3.png) <br><br>

Example 4:
Results view from event viewer MMC:<br>
![Sample results](/screenshots/getdeletedsids_sshot4.png) 
