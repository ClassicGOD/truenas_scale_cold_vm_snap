# Script for creating cold snapshots of VMs on TrueNas Scale

This is an amalgam of [script](https://www.truenas.com/community/threads/backup-bhyve-windows-vm.85705/post-601264) by user [bal0an](https://www.truenas.com/community/members/bal0an.22184/) from TrueNas community forums and an elegent command [sugested on serverfault.com](https://serverfault.com/a/340846) with few of my own modifications. So most of the credit goes to the folks above. 

Features:
* if -d option is not set script will atempt to detect all DISK devices in VM config and use them as snapshot targets.
* Stops VM before creating a snapshot
  * If VM does not stop in specified time (can be configured in file) retries sending vm.stop
  * Number of retries can be configurad with -r option (default 1)
  * If VM does not stop, script aborts
* Restarts VM after creating snapshot if the VM was running when the script was launched
* Removes oldest snapshots leaving only specified number of most recent ones.
* Common part of snapshot names can be configured with -n option "vmbk" by default

# Usage
```
Usage: vmbk.sh [OPTIONS] VM_NAME

 Option                 Meaning
 -d <dataset>           Dataset to backup. Setting -d diables automatic dataset detection.
                        (use multiple -d options for multiple datasets)
 -h                     Display this message
 -k <number>            Number of latest shapshots to keep. (default: unlimited)
 -n <name>              Common part of snapshot name. (default: vmbk)
 -r <number>            Number of retries to shut the vm down before giving up. (default: 1)
 -t <number>            Time between vm status checks in sec. (default: 5)
 -w <number>            Number of status checks while waiting for vm to shut down (default: 20)
```

Example:
```
./vmbk.sh -k 7 debian_test
```

Example Output:
```
19:53:01 [Info] VMBK starting 2022-01-30 19:53:01
19:53:02 [Info] 'debian_test' has id '6'
19:53:02 [Info] dataset to snapshot: 'nvme_pool/vm/debian_test-hh8vs5'
19:53:02 [Info] shutting down 'debian_test' 90640
19:53:03 [Info] waiting for 'debian_test' to shutdown...(1/20)
19:53:08 [Info] 'debian_test' stopped.
19:53:08 [Info] taking snapshot nvme_pool/vm/debian_test-hh8vs5@vmbk-2022-01-30_19-53
19:53:08 [Info] starting 'debian_test'
19:53:13 [Info] destroying older snapshots for 'nvme_pool/vm/debian_test-hh8vs5'
19:53:13 [Info] keeping 7 latest
19:53:14 [Info] will destroy nvme_pool/vm/debian_test-hh8vs5@vmbk-2022-01-30_19-51 will reclaim 4.87M
19:53:14 [Info] done
```

# Installation

```
wget https://raw.githubusercontent.com/ClassicGOD/truenas_scale_cold_vm_snap/main/vmbk.sh
```
```
chmod +x vmbk.sh
```
Example Cron Job setup:

<img src="/images/vmbk_cron_job_example.jpg" width="500">

Example Replication setup:

<img src="/images/vmbk_replication_example.jpg" width="500">
