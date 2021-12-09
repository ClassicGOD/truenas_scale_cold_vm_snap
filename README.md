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

# Usage
```
./vmbk.sh <vm_name> <vm_dataset> [number_of_snapshots_to_keep]
```

Example:
```
./vmbk.sh large_dockie nvme_pool/data/vm/large_dockie-reum7yp 7
```

Example Output:
```
2021-12-09 14:12:49 Taking snapshot of nvme_pool/data/vm/large_dockie-reum7yp for VM large_dockie.
2021-12-09 14:12:49 vm large_dockie has id 1.
2021-12-09 14:12:49 Shutting down VM large_dockie...
5435
2021-12-09 14:12:50 Wait for vm large_dockie to terminate...(1/12)
2021-12-09 14:12:55 vm large_dockie stopped
2021-12-09 14:12:55 Taking snapshot nvme_pool/data/vm/large_dockie-reum7yp@vmbk-2021-12-09_14-12
2021-12-09 14:12:55 Starting up VM large_dockie
null
2021-12-09 14:12:58 Destroying older snapshoots. Keeping 7 latest.
will destroy nvme_pool/data/vm/large_dockie-reum7yp@vmbk-2021-12-09_13-35
will reclaim 4.12M
2021-12-09 14:12:59 Done.
```
