<#############################################################################
nps-sync.ps1

To be installed on "Master" Server, script when run will push configuration
to all "Slave" NPS Servers. Note this will overwrite existting slave settings

Changelog
25/10/21    v1.0    Initial Release

Requires:
 - Run with highest privileges.
 - Run from NPS "Master"
 - $backup_dir to be created on NPS slaves manually
 
Assumptions:
 - DHCP Server is at least Windows Server 2012
 - Executing account has admin access on both Master and Slave NPS Servers 

Sections of this script have been copied/modified from:
https://gist.github.com/Jamesits/6c742087bca908327d51ad1b3bbed5dc

#############################################################################>
# User Defined Variables
#############################################################################
#Slave NPS Servers in Array Below eg @('server1','server2')
$Computers = @('lab1-srv1.lab')

#Working Directories on NPS Servers
$backup_dir = "C:\workspace"
$archive_dir = "c:\workspace\Archive"
#############################################################################
# Script Below
#############################################################################
# Define date format
$date = get-date -Format yyyy_MM_dd

# Delete files older than 10 days
$limit = (Get-Date).AddDays(-10)

#Create an NPS Sync Event Source if it doesn't already exist
if (!(get-eventlog -logname "System" -source "NPS-Sync")) {new-eventlog -logname "System" -source "NPS-Sync"}
 
#Write an error and exit the script if an exception is ever thrown
trap {write-eventlog -logname "System" -eventID 1 -source "NPS-Sync" -EntryType "Error" -Message "An Error occured during NPS Sync: $_. Script run from $($MyInvocation.MyCommand.Definition)"; exit}

# Check to see if backup dir exists and create if it doesnt.
if (!(Test-Path $backup_dir)) {
    New-Item -ItemType Folder -Path $backup_dir
}

# Check to see if archive dir exists and create if it doesnt.
if (!(Test-Path $archive_dir)) {
    New-Item -ItemType Folder -Path $archive_dir
}

# Export NPS Config
Export-NpsConfiguration -Path $archive_dir\NPS_config_$date.xml
Export-NpsConfiguration -Path $backup_dir\NPS_config.xml

$backup_file = "$backup_dir\NPS_config.xml"

# Copy config to destination server
$Computers | Foreach-Object { 
    $SlaveSession = New-PSSession -ComputerName $_
    Copy-Item -ToSession $SlaveSession -Path $backup_file -Destination $backup_file
}

# Import new config in destination server 
$Computers | Foreach-Object { Invoke-Command -ComputerName $_ -ArgumentList $backup_file -scriptblock {param ($backup_file) Import-NPSConfiguration -Path $backup_file}}

# Delete files older than the $limit.
Get-ChildItem -Path $archive_dir -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force

#Compose and Write Success Event
$successText = "Network Policy Server Configuration successfully synchronized to Slaves
Script was run from $($MyInvocation.MyCommand.Definition)"
write-eventlog -logname "System" -eventID 1 -source "NPS-Sync" -EntryType "Information" -Message $successText