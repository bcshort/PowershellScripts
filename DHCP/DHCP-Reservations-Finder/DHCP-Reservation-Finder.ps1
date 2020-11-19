<#############################################################################
DHCP-Reservation-Finder.ps1

Specify a DHCP Server target. Scans subnet for responding IP Addresses and
determines Hostname from PTR Records and whether a DHCP Reservation 
Exists for IP.

Changelog
19/11/20    v1.0    Initial Release

Requires:

Assumptions:
 - User executing script has access to view reservations on DHCP Server
 - DHCP Server is at least Windows Server 2012 R2
#############################################################################>

# Report on Missing Reservations, or attempt to create them (interactively)
# set to $true to offer abilty to create Reservations
$createReservations = $false

# Interactive Configuration
Clear-Host
Write-output "DHCP Reservation Checker"
Write-output "------------------------"
$DHCPTargetServer = Read-Host -Prompt "Input Target DHCP Server"
Write-Host "Enter first three 'dotted quads' for subnet. eg. 192.168.1"
$TargetSubnet = Read-Host "Subnet (partial)"
Write-host "Enter Start IP. eg. '1'"
[int]$StartIP = Read-Host -Prompt "Enter Start IP"
Write-output "Enter End IP. e.g. '255'"
[int]$EndIP = Read-Host -Prompt "Enter End IP"

# Enumerate DHCP Scopes from DHCP Server
# Used for Scope Lookups for IP Addresses. Stored as Variable to reduce DHCP Server Queries
try {
    $DHCPScopeArray = Get-DhcpServerv4Scope -ComputerName $DHCPTargetServer
    }
catch {
    Write-Host -ForegroundColor Red "Unable to Connect to DHCP Server. Exiting..."
    exit
}

# Function CreateDHCPReservation
# Try to Create DHCP Reservation by ARP Lookup. Only will work if servers are on same subnet as script host.
function CreateDHCPReservation([string]$IpAddr) {
    $addReservation = read-Host "Try to create Reservation? (Y/N)"
    if ($addReservation -eq "Y"){
        # Discover DHCP Scope for IP Address
        $DHCPScope =  $DHCPScopeArray| where-object {$_.startrange -match $TargetSubnet -or $_.endrange -match $TargetSubnet -or $_.ScopeId -match $TargetSubnet }
        $DHCPScopeID = $DHCPScope.ScopeID.IpAddressToString
        # ARP Lookup of IP Address for target
        $arp = Get-NetNeighbor | where-object {$_.ipaddress -eq $IPAddr}
        if ($arp) {
            # Create ClientID from MAC Address & Create Reservation
            [string]$macaddr = $arp.LinkLayerAddress
            $macaddr = $macaddr.Replace("-","")
            try {
                Add-DhcpServerv4Reservation -ComputerName $DHCPTargetServer -IPAddress $IPAddr -Description $($hostname.hostname) -ClientId $macaddr -ScopeId $DHCPScopeID -Name $($hostname.hostname) -ErrorAction SilentlyContinue
                }
            catch {
                Write-Host -ForegroundColor Yellow "Unable to Create Reservation :("
                }
            Write-Host -ForegroundColor Yellow "Created Reservation for $IPAddress, ClientID $macaddr, $($hostname.hostname)"
            }
        else {
            Write-Host -ForegroundColor Yellow "Unable to create reservation. ARP not found. Are you running the script on the same network?"
            }
        }
    else {
            Write-Host -ForegroundColor Yellow "User Skipped Reservation Creation" 
        }    
    }

# Scan specified IP Range and Query DHCP Server to see if reservation exists
# Report if Lease Found
# If Lease not found, Ping IP to see if active, and if so attempt a DNS reverse lookup.
# If hostname found, offer to create reservation, otherwise warn and continue to next IP

for ($i = $StartIP; $i -lt $EndIP+1; $i++) {
    $IpAddress = "$TargetSubnet.$i"
    $DHCPLease = Get-DhcpServerv4Reservation -ComputerName $DHCPTargetServer -IPAddress $IpAddress -ErrorAction SilentlyContinue
    if ($null -ne $DHCPLease) {
        Write-Output "DHCP Lease found for $IPaddress - $($DHCPLease.IPAddress) - $($DHCPLease.Name)"
        Continue
    }
    else {
        $pingresult = Test-Connection $IpAddress -Count 1 -ErrorAction SilentlyContinue
        if ($null -eq $pingresult) {
            Write-Host -ForegroundColor Yellow "$ipaddress not responding"
            }
        else {
            try {
                $Hostname = [System.Net.Dns]::GetHostByAddress($IpAddress)
                Write-Host -ForegroundColor red "No DHCP Reservation for $IPaddress - $($hostname.hostname)"    
                if ($createReservations) {
                CreateDHCPReservation($IpAddress)
                }
            }
            catch {
                Write-Host -ForegroundColor red "No DHCP Reservation for $IPaddress - (no hostname) - Cannot Offer Create Reservation: No PTR Record"
            }
        }
    }  
} 