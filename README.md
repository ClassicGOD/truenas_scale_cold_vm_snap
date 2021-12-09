# Script for creating cold snapshots od VMs on TrueNas Scale

This is an amalgam of [script](https://www.truenas.com/community/threads/backup-bhyve-windows-vm.85705/post-601264) by user [bal0an](https://www.truenas.com/community/members/bal0an.22184/) from TrueNas community forums and an elegent command [sugested on serverfault.com](https://serverfault.com/a/340846) with few of my own modifications.

Features:
* Stops VM before creating a snapshot
  * If VM does not stop in specified time (can be configured in file) retries sending vm.stop
  * Number of retries can be configured in file (1 by default)
  * If VM does not stop, aborts
* Restarts VM after creating one
* Removes oldest snapshots leaving only specified number of most recent ones.
* Common part of snapshot names can be configured in file "vmdk" by default
