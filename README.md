# Script for creating cold snapshots of VMs on TrueNas Scale

This is an amalgam of [script](https://www.truenas.com/community/threads/backup-bhyve-windows-vm.85705/post-601264) by user [bal0an](https://www.truenas.com/community/members/bal0an.22184/) from TrueNas community forums and an elegent command [sugested on serverfault.com](https://serverfault.com/a/340846) with few of my own modifications. So 99% of the credit goes to the folks above. 

Features:
* [new] if <vm_dataset> parameter is set to auto script will atempt to detect all DISK devices in VM config and use them as snapshot targets.
* Stops VM before creating a snapshot
  * If VM does not stop in specified time (can be configured in file) retries sending vm.stop
  * Number of retries can be configured in file (1 by default)
  * If VM does not stop, script aborts
* Restarts VM after creating snapshot if the VM was running when the script was launched
* Removes oldest snapshots leaving only specified number of most recent ones.
* Common part of snapshot names can be configured in file "vmbk" by default

# Usage
```
./vmbk.sh <vm_name> <vm_dataset> [number_of_snapshots_to_keep]
```

Example:
```
./vmbk.sh large_dockie nvme_pool/data/vm/large_dockie-reum7yp 4
```

Example Output:
```
2021-12-13 12:23:23 VM large_dockie has id 1.
2021-12-13 12:23:23 Will take snapshot of nvme_pool/data/vm/large_dockie-reum7yp for VM large_dockie.
2021-12-13 12:23:23 Shutting down VM large_dockie...
5624
2021-12-13 12:23:24 Wait for VM large_dockie to terminate...(1/12)
2021-12-13 12:23:29 VM large_dockie stopped.
2021-12-13 12:23:29 Taking snapshot nvme_pool/data/vm/large_dockie-reum7yp@vmbk-2021-12-13_12-23.
2021-12-13 12:23:29 Starting up VM large_dockie.
null
2021-12-13 12:23:32 Destroying older snapshoots of dataset nvme_pool/data/vm/large_dockie-reum7yp. Keeping 4 latest.
will destroy nvme_pool/data/vm/large_dockie-reum7yp@vmbk-2021-12-12_14-10
will reclaim 3.93M
will destroy nvme_pool/data/vm/large_dockie-reum7yp@vmbk-2021-12-12_02-00
will reclaim 17.6M
2021-12-13 12:23:33 Done.
```

Example with auto zvol detection:
```
./vmbk.sh arch auto 2
```

Example Output with auto zvol detection:
```
2021-12-12 14:02:02 VM arch has id 3.
2021-12-12 14:02:02 Will take snapshot of nvme_pool/data/vm/arch-4mspi for VM arch.
2021-12-12 14:02:02 Will take snapshot of nvme_pool/data/vm/arch-test for VM arch.
2021-12-12 14:02:02 VM arch not running.
2021-12-12 14:02:02 Taking snapshot nvme_pool/data/vm/arch-4mspi@vmbk-2021-12-12_14-02.
2021-12-12 14:02:02 Taking snapshot nvme_pool/data/vm/arch-test@vmbk-2021-12-12_14-02.
2021-12-12 14:02:02 Destroying older snapshoots of dataset nvme_pool/data/vm/arch-4mspi. Keeping 2 latest.
will destroy nvme_pool/data/vm/arch-4mspi@vmbk-2021-12-12_14-00
will reclaim 0B
will destroy nvme_pool/data/vm/arch-4mspi@vmbk-2021-12-12_13-59
will reclaim 0B
will destroy nvme_pool/data/vm/arch-4mspi@vmbk-2021-12-12_13-58
will reclaim 0B
2021-12-12 14:02:03 Destroying older snapshoots of dataset nvme_pool/data/vm/arch-test. Keeping 2 latest.
will destroy nvme_pool/data/vm/arch-test@vmbk-2021-12-12_14-00
will reclaim 112K
will destroy nvme_pool/data/vm/arch-test@vmbk-2021-12-12_13-59
will reclaim 160K
will destroy nvme_pool/data/vm/arch-test@vmbk-2021-12-12_13-58
will reclaim 532K
2021-12-12 14:02:04 Done.
```

# Installation

```
wget https://raw.githubusercontent.com/ClassicGOD/truenas_scale_cold_vm_snap/main/vmbk.sh
chmod +x vmbk.sh
```
Example Cron Job setup:

![Example Cron Job](/images/vmbk_cron_job_example.jpg | width=100)
