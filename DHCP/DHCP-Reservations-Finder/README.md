# DHCP Reservation Finder

This script is an interactive script to scan an IP Subnet and confirm that IP addresses have associated DHCP Reservations in Microsoft DHCP Server.
If no Reservation is found, optionally try to create a reservation.

Reservation requests are attempted to be created by makig an arp request to obtain MAC address. Therefore to be able to use 'create reservation'
functionality, script must be run on a machine that is on a the same subnet as the target devices. This is toggled with the following
variable in the script:
* $createReservations = $false
