<# 
* Get Deleted Domain Sid(s) in Local Groups *
Helps with assessing deleted domain accounts (showing just SIDs) in Local Group membership, to aid with cleanup later.
Can run with SCCM (locally - possibly with -WriteResultToEventLog parameter), WinRM (Remotely) or any other agent/tool. 
Results can be collected via WEC/WEF, or queried remotely from the event log if parameter -WriteResultToEventLog specific (creates event id 666 if found deleted Sids ;) or eid 667 if none found).

Comments to yossis@protonmail.com
version 1.2 - Added check for local domain Sid and specifying in 'AccountType' if deleted Sid is from a foreign domain + added 445 port ping before continuing + few error handling and other fixes.
Version 1.1 - Added ComputerName parameter (default: localhost), and a parameter to write results to EventLog.
Version 1.0 - Initial script
#>
param(
    [string]$ComputerName = 'localhost',
    [switch]$WriteResultToEventLog
)

# Get computer object in ADSI using WinNT namespace
$Obj = [ADSI]"WinNT://$ComputerName,Computer";

# Get current computer domain Sid, for later comparison to detect foreign domain deleted sid
if ($Computername -eq 'localhost')
    {
        $domain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain());
        $domainSID = (New-Object System.Security.Principal.NTAccount("$($domain.Name)\Domain Admins")).Translate([System.Security.Principal.SecurityIdentifier]).Value -replace '-512$'
    }
else
    {
        # first, ensure connectivity (WinNT:// uses both 445 and 135 + RPC ephemeral ports later)
        if (!$(((New-Object System.Net.Sockets.TcpClient).ConnectAsync($ComputerName,445)).Wait(100))) {
            Write-Host "[!] Computer $ComputerName Not available on port 445 (SMB+RPC required).";
            break
        }

        # Get computer domain Sid
        $ComputerSid = (New-Object System.Security.Principal.NTAccount("$COMPUTERNAME$")).Translate([System.Security.Principal.SecurityIdentifier]).Value;
        $domainSID = $ComputerSid.Split('-')[0..6] -join '-'
    }

# Set up CSV object(s) fields/properties
$Entries = @();
$Entries += "DeletedAccountSid,LocalGroupName,ComputerName,AccountType";

# Ensure we get the objects (e.g. host is available), otherwise - quit
$childObjects = $Obj.Children;
if (!$?)
    {
        Write-Host "[!] Error: $($Error[0].exception.message)";
        break
    }

# Enumerate child objects under the computer object
foreach ($childObject in $($Obj.Children)) {

    switch ($childObject.Class)
        {
        # not really needed.. but -
        "User" {  
            if ($childObject.Name[0] -like "S-1-") {
                    #$(($childObject.Name[0]).ToString().Trim())
                    $type = "System.Security.Principal.SecurityIdentifier";
                    $childObjectSID = new-object $type($childObject.objectSID[0],0);
                    $Entries += "$($childObjectSID.Value),$($childObject.Name[0]),$ComputerName,LOCALUSER"
                }
            }

        # The main class we target
        "Group"
            {
                $childObject.psbase.Invoke('Members') |
                foreach {
                        $Member = $_.GetType().InvokeMember('ADspath', 'GetProperty', $null, $_, $null).Replace('WinNT://','');
                        if ($Member -like "S-1-*") {
                            # Check if same computer domain or foreign sid
                            if ($domainSID -eq $($Member.Split('-')[0..6] -join '-')) 
                                {
                                    $AccountType = 'SameDomainAccount'
                                }
                            else
                                {
                                    $AccountType = 'ForeignDomainAccount'
                                }
                            # Add entry
                            $Entries += "$($Member.Trim()),$($childObject.Name[0]),$ComputerName,$AccountType"
                        }
                    }
            }

        default {}
    }
}

if ($Entries.Count -gt 1)
    {
        $($Entries | ConvertFrom-Csv | Out-String);

        if ($WriteResultToEventLog) 
            {
                # Write an event to System log with the Deletd Sids found (NOTE: Custom events cannot be created into security log)
                $Result = eventcreate /ID 666 /L SYSTEM /T INFORMATION /SO "DeletedSid_Check" /D "Deleted account Sid(s) found in local groups:`n$($Entries | ConvertFrom-Csv | Out-String)"; 
                
                # Alternative: using Write-EventLog, but you need to register an event source FIRST, e.g. New-EventLog -LogName Security -Source "DeletedSid_Check"
                # Write-EventLog -LogName Security -Source 'DeletedSid_Check' -EventId 666 -EntryType Information -Message "Deleted account Sid(s) found in local groups:`n$($Entries | ConvertFrom-Csv)";

                # Show error haif write failed, or result
                if ($Result -like "*error*") 
                    {
                        Write-Host "[!] $Result"
                    }
                else
                    {
                        $Result
                    }
        }
}
else
    {
        Write-Host "[x] No deleted Sid(s) found on $ComputerName.";

        if ($WriteResultToEventLog)
            # Write log entry that no deleted Sids were found
            {
                eventcreate /ID 667 /L SYSTEM /T INFORMATION /SO "DeletedSid_Check" /D "No Deleted account Sid(s) found in local groups."; 
            }
    }