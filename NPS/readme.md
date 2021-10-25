# RADIUS Configuration Sync Script
Microsoft NPS service currently (November 2021) offers no inbuilt mechanism to synchronise settings between a farm of NPS servers within a production environment. The current best practice to faciltate this is the use of a powershell script. 

## About the Powershell Script
The powershell script is installed on what is considered the "Master" NPS server and performs a one way replication to other configured slave NPS servers. This action will overwrite any configuration on slave NPS servers.

The following is a high level description of how the script runs:

1. Environment variables initialised
2. Checks are made that folder locations on NPS master exist
3. NPS configuration exported to a file
4. NPS configuration file is copied to destination using PSSession, removing the need to use a file share on slave NPS servers
5. NPS configuration file is imported to slave NPS Server
6. Delete old NPS configuration files
7. Write Success/Failure to windows System eventlog

Please note that the script has important requirements to run successfully. These are documented in the comments at the top of the script. Notably:
* Script must be run as administrator (highest level privileges) to have access to the logs
* $backup_dir directory MUST be created manually on NPS slave servers or the script will fail.
