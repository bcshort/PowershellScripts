#############################################################################
# iLO Bulk SSL Generation & Installation Script
# Written by Ben Short
# Version 3.0, November 2014
#
# Released under Creative Commons BY,SA 
# http://creativecommons.org.au/learn/licences/
#
# Script enumerates iLO devices from text file and generates 
# CSR to be signed by a Microsoft CA Server. Resulting Certificate
# Installed on iLO
#
# Script requirements
# * HP Powershell cmdlets
#    http://www8.hp.com/au/en/products/server-software/product-detail.html?oid=5440657
# 
# Disclaimer: Script Author accepts no responsibility or liability for
#             Damages script may cause. Script offered as is.
#
# Changelog:
# 2014-11-21 ver 3.0
#	New - Rewritten to use HP Powershell Library
# 2012-02-02 Ver 2.0.0
#   New - Rewritten to support iLO PS Library
#   Mod - Fixed problems with iLO3 signing from version 1.0
#
#
##############################################################################

# Location of iLO Text File

$strTextFileLoc = "ilolist.txt"

# Exclusion List. Sometimes used to deal with 
# iLO Intefaces that cause script to hang.

$exclusions = "BADINTERFACE.mydomain.com", "broken.mydomain.com"

#iLO Domain Name
$striLODomain = "ilo.mydomain.com"

#iLO Administrative Account Details
$striLOUsername = "admin"
$striLOPassword = "password"

# ADCS Server Name
$certificateserver = "caserver.domain.com\Enterprise Root CA"
$certificatetemplate = "WebServer"

#Skipped Hosts
$skippedreport =@()

# Location of Log Folders
$cpqlogfilefolder = "logs"


# Path to Script Location & Support Files
$scriptpath = "C:\testscript"

# Verbose Output
$verbose = $true

#======================================================================================
cls
$ilOInterfaces = Get-Content $strTextFileLoc

function Ping-iLO ([string]$iLOHostName) {
	$ping  = new-object System.Net.NetworkInformation.Ping
	try { 
		$Reply = $ping.send($iLOhostname,500)
		}
	catch { 
		return $false
		}
	if ($Reply.Status -eq "Success") {
		return $true
		}
	}

foreach ($interface in $iLOInterfaces) {
	if (Ping-ilo($interface) -and ($exclusions -notcontains $interface)) {
		$shorthost = $interface.Split(".")
		$shorthost = $shorthost[0]
		write-output "[logging] Now Running: `t$interface"
		$iLOInfo = Get-HPiLOFirmwareVersion -Server $interface -Username $striLOUsername -Password $striLOPassword
		if ($verbose -and ($iLOInfo.STATUS_MESSAGE -eq "OK")) {
			write-output "[verbose] iLO Processor: `t$($iLOinfo.MANAGEMENT_PROCESSOR)"
			write-output "[verbose] iLO Firmware: `t$($iLOinfo.FIRMWARE_VERSION)"
			write-output "[verbose] iLO Firmware Date: `t$($iLOinfo.FIRMWARE_DATE)"
			}
		else {
			write-output "[logging] iLO Processor: `tUnknown - skipping"
			Write-Output "------------------------------------------------------`n"
			$skippedreport += "$interface - Unknown iLO Version"
			continue
			}
		write-output "[logging] iLO Detected: `t$($iLOinfo.MANAGEMENT_PROCESSOR)"
		
		$interfaceNetworking = Get-HPiLONetworkSetting -Server $interface -Username $striLOUsername -Password $striLOPassword
		$nethostname = $interfaceNetworking.DNS_NAME + "." + $interfaceNetworking.DOMAIN_NAME
		if ($verbose) {
			write-output "[verbose] iLO Configured Hostname: $nethostname"
			}
		
		
		if ($interface -eq $nethostname) {
			write-output "[logging] iLO Hostname Matches DNS Record! - Getting CSR..."
				}
		else {
			write-output "[logging] iLO Hostname Does Not Match DNS Record! - Skipping..."
			$skippedreport += "$interface - DNS Hostname Mismatch ($nethostname)"
			Write-Output "------------------------------------------------------`n"
			continue
			}
		
		
		$iLOCSR = Get-HPiLOCertificateSigningRequest -Server $interface -Username $striLOUsername -Password $striLOPassword
		
		$gotCSR=$false
		while ($gotCSR -eq $false) {
		if ($iLOCSR.STATUS_TYPE -eq "OK") {
			if ($iLOCSR.CERTIFICATE_SIGNING_REQUEST -ne "") {
				$iLOCSR.CERTIFICATE_SIGNING_REQUEST | Out-File $scriptpath\currentcsr.txt -Encoding ascii -Force
				Write-Output "[logging] CSR Written to $scriptpath\currentcsr.txt"
				$gotCSR=$true
				}
			else {
				Write-Output "[logging] CSR Generation Failed. Skipping..."
				Write-Output "------------------------------------------------------`n"
				$skippedreport += "$interface - CSR Failed"
				continue
				}
			}
		else {
			Write-Output "[logging] iLO Generating CSR. Script sleeping 120 seconds.."
			Start-Sleep -Seconds 120 
			$iLOCSR = Get-HPiLOCertificateSigningRequest -Server $interface -Username $striLOUsername -Password $striLOPassword
			}
		}
		write-output "[logging] Signing Certificate with $certificateserver"
		if (Test-Path $scriptpath\currentcert.cer) {
			Remove-Item $scriptpath\currentcert.cer
			}
		certreq.exe -config $certificateserver -attrib "CertificateTemplate:$certificatetemplate" "$scriptpath\currentcsr.txt" "$scriptpath\currentcert.cer" |Out-Null
		
		if (Test-Path $scriptpath\currentcert.cer) {
			write-output "[logging] Installing Certificate on iLO"
			$certificate = Get-Content "$scriptpath\currentcert.cer" -Raw
	 		Import-HPiLOCertificate -Server $interface -Username $striLOUsername -Password $striLOPassword -Certificate $certificate	
			}
		else {
			write-output "[logging] Can't Find Signed Certificate, Skipping..."
			$skippedreport += "$interface - Unable to install Signed Cert"
			}
		Write-Output "------------------------------------------------------`n"
		}
	else {
	write-output "[logging] Interface Unreachable/Excluded, Skipping..."
	Write-Output "------------------------------------------------------`n"
	$skippedreport += "$interface - Unreachable/Excluded"
	}
	}

Write-Output "Hosts Skipped"
Write-Output "------------------------"
$skippedreport
Write-Output "`n"