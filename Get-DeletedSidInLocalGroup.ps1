<# 
* Get Deleted Domain Sid(s) in Local Groups *
Helps with assessing deleted domain accounts (showing just SIDs) in Local Group membership, to aid with cleanup later.
Can run with SCCM (locally), WinRM (Remotely) or any other agent/tool. 
Results can be collected via WEC/WEF, or queried remotely from the event log, eid 666 hahaa

Comments to yossis@protonmail.com
Version 1.0
#>

$Obj = [ADSI]"WinNT://localhost,Computer";

$Entries = @();
$Entries += "DeletedAccountSid,LocalGroupName,ComputerName,AccountType";

foreach ($childObject in $($Obj.Children)) {

    switch ($childObject.Class)
        {
        "User" {
            if ($childObject.Name[0] -like "S-1-") {
                    $(($childObject.Name[0]).ToString().Trim())
                    $type = "System.Security.Principal.SecurityIdentifier";
                    $childObjectSID = new-object $type($childObject.objectSID[0],0);
                    $Entries += "$(($childObject.Name[0]).ToString().Trim()),,$env:COMPUTERNAME,LOCALUSER"
                }
            }

        "Group"
            {
                $childObject.psbase.Invoke('Members') |
                foreach {
                        $Member = $_.GetType().InvokeMember('ADspath', 'GetProperty', $null, $_, $null).Replace('WinNT://','');
                        if ($Member -like "S-1-*") {
                            $Entries += "$($Member.Trim()),$($childObject.Name[0]),$env:COMPUTERNAME,DOMAINACCOUNT"
                        }
                    }
            }

        default {}
    }
}

if ($Entries.Count -gt 1)
    {
        # Write an event to System log with the Deletd Sids found (NOTE: Custom events cannot be created into security log)
        eventcreate /ID 666 /L SYSTEM /T INFORMATION /SO "DeletedSid_Check" /D "Deleted account Sid(s) found in local groups:`n$($Entries | ConvertFrom-Csv | Out-String)";   
        
        # Alternative: using Write-EventLog, but you need to register an event source FIRST, e.g. New-EventLog -LogName Security -Source "DeletedSid_Check"
        # Write-EventLog -LogName Security -Source 'DeletedSid_Check' -EventId 666 -EntryType Information -Message "Deleted account Sid(s) found in local groups:`n$($Entries | ConvertFrom-Csv)";
}