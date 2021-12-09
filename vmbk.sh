#!/bin/bash
if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    echo "Usage: vmbk.sh <vm_name> <dataset> [snapshots_to_keep]"
    exit 1
fi
VM_NAME=$1
DATASET=$2
KEEP=$3

#config variables
WAIT=12 #5sec cycles to wait for vm to shutdown. Default: 12 (1min)
RETRY=1 #times to retry sending vm.stop if the vm is still running Default: 1
SNAP_NAME="vmbk" #common part of snapshot name. Default "vmbk"

RC=$(zfs list $DATASET)

if [ $? -eq 1 ]; then
    echo "Error: Dataset $DATASET not found. Aborting."
    exit 1
fi

echo $(date '+%Y-%m-%d %H:%M:%S') "Taking snapshot of $DATASET for VM $VM_NAME."
VM_ID=$(midclt call vm.query | jq ".[] | if .name == \"$VM_NAME\" then .id else empty end")

if [ "$VM_ID" == "" ]; then
    echo "Error: No VM found with name $VM_NAME. Aborting."
    exit 1
fi

if [ "$VM_ID" == "" ]; then
    echo "Error: No VM found with name $VM_NAME. Aborting."
    exit 1
fi

echo $(date '+%Y-%m-%d %H:%M:%S') "vm $VM_NAME has id $VM_ID."

if [ $(midclt call vm.status $VM_ID | jq '.state') != "\"STOPPED\"" ]; then
    echo $(date '+%Y-%m-%d %H:%M:%S') "Shutting down VM $VM_NAME..."
    midclt call vm.stop $VM_ID

    WAIT_CNT=0
    RETRY_CNT=0

    while [ $(midclt call vm.status $VM_ID | jq '.state') != "\"STOPPED\"" ]; do
        WAIT_CNT=$((WAIT_CNT+1))

        if [ "$WAIT_CNT" -gt "$WAIT" ]; then
            if [ "$RETRY_CNT" -lt "$RETRY" ]; then
                RETRY_CNT=$((RETRY_CNT+1))
                WAIT_CNT=1
                echo $(date '+%Y-%m-%d %H:%M:%S') "vm $VM_NAME still running. Retrying vm.stop... ($RETRY_CNT/$RETRY)"
                midclt call vm.stop $VM_ID
            else
                echo "Error: Failed to stop $VM_NAME. Aborting."
                exit 1
            fi
        fi

        echo $(date '+%Y-%m-%d %H:%M:%S') "Wait for vm $VM_NAME to terminate...($WAIT_CNT/$WAIT)"
        sleep 5
    done
fi

echo $(date '+%Y-%m-%d %H:%M:%S') "vm $VM_NAME stopped"
SNAPSHOT_NAME=$(date "+$DATASET@$SNAP_NAME-%Y-%m-%d_%H-%M")
echo $(date '+%Y-%m-%d %H:%M:%S') "Taking snapshot $SNAPSHOT_NAME"
zfs snapshot $SNAPSHOT_NAME
echo $(date '+%Y-%m-%d %H:%M:%S') "Starting up VM $VM_NAME"
midclt call vm.start $VM_ID

KEEP_TAIL=$((KEEP+1))
if [ "$KEEP_TAIL" -gt "1" ]; then
    echo $(date '+%Y-%m-%d %H:%M:%S') "Destroying older snapshoots. Keeping $KEEP latest."
    SNAP_TO_DESTROY=$(zfs list -t snapshot -o name -S creation | grep "^$DATASET@$SNAP_NAME" | tail -n +$KEEP_TAIL)
    if [ "$SNAP_TO_DESTROY" == "" ]; then
         echo $(date '+%Y-%m-%d %H:%M:%S') "No snapshots to destroy."
    else
         echo $SNAP_TO_DESTROY | xargs -n 1 zfs destroy -vr
    fi
else
    echo $(date '+%Y-%m-%d %H:%M:%S') "Number of snapshots to keep not provided. Skipping."
fi

echo $(date '+%Y-%m-%d %H:%M:%S') "Done."
