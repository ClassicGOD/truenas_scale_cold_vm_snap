#!/bin/bash
if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    echo "Usage: vmbk.sh <vm_name> <dataset> [snapshots_to_keep]"
    echo "Info: if <dataset> is set to auto snapshot of all DISK devices for the VM will be taken."
    exit 1
fi
VM_NAME=$1
DATASET=$2
KEEP=$3

#config variables
WAIT=12 #5sec cycles to wait for vm to shutdown. Default: 12 (1min)
RETRY=1 #times to retry sending vm.stop if the vm is still running Default: 1
SNAP_NAME="vmbk" #common part of snapshot name. Default "vmdk"

VM_ID=$(midclt call vm.query | jq ".[] | if .name == \"$VM_NAME\" then .id else empty end")
if [ "$VM_ID" == "" ]; then
    echo "Error: No VM found with name $VM_NAME. Aborting."
    exit 1
fi

echo $(date '+%Y-%m-%d %H:%M:%S') "VM $VM_NAME has id $VM_ID."

if [ "$DATASET" != "auto" ]; then
    DATASETS="$DATASET"
else
    DATASETS=$(midclt call vm.query | jq ".[] | if .id == $VM_ID then .devices else empty end | .[] | if .dtype == \"DISK\" then .attributes.path else empty end" |  sed -e "s/^\"\/dev\/zvol\///" -e "s/\"$//")
fi

echo "$DATASETS" | while read DATASET ; do
    RC=$(zfs list $DATASET)

    if [ $? -eq 1 ]; then
        echo "Error: Dataset $DATASET not found. Aborting."
        exit 1
    fi
    echo $(date '+%Y-%m-%d %H:%M:%S') "Will take snapshot of $DATASET for VM $VM_NAME."
done

VM_STATE=$(midclt call vm.status $VM_ID | jq '.state')
if [ "$VM_STATE" != "\"STOPPED\"" ]; then
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
                echo $(date '+%Y-%m-%d %H:%M:%S') "VM $VM_NAME still running. Retrying vm.stop... ($RETRY_CNT/$RETRY)"
                midclt call vm.stop $VM_ID
            else
                echo "Error: Failed to stop VM $VM_NAME. Aborting."
                exit 1
            fi
        fi

        echo $(date '+%Y-%m-%d %H:%M:%S') "Wait for VM $VM_NAME to terminate...($WAIT_CNT/$WAIT)"
        sleep 5
    done
    echo $(date '+%Y-%m-%d %H:%M:%S') "VM $VM_NAME stopped."
else
    echo $(date '+%Y-%m-%d %H:%M:%S') "VM $VM_NAME not running."
fi

echo "$DATASETS" | while read DATASET ; do
    SNAPSHOT_NAME=$(date "+$DATASET@$SNAP_NAME-%Y-%m-%d_%H-%M")
    echo $(date '+%Y-%m-%d %H:%M:%S') "Taking snapshot $SNAPSHOT_NAME."
    zfs snapshot $SNAPSHOT_NAME
done

if [ "$VM_STATE" != "\"STOPPED\"" ]; then
    echo $(date '+%Y-%m-%d %H:%M:%S') "Starting up VM $VM_NAME."
    midclt call vm.start $VM_ID
fi

KEEP_TAIL=$((KEEP+1))
if [ "$KEEP_TAIL" -gt "1" ]; then
    echo "$DATASETS" | while read DATASET ; do
        echo $(date '+%Y-%m-%d %H:%M:%S') "Destroying older snapshoots of dataset $DATASET. Keeping $KEEP latest."
        SNAP_TO_DESTROY=$(zfs list -t snapshot -o name -S creation | grep "^$DATASET@$SNAP_NAME" | tail -n +$KEEP_TAIL)
        if [ "$SNAP_TO_DESTROY" == "" ]; then
             echo $(date '+%Y-%m-%d %H:%M:%S') "No snapshots to destroy."
        else
            echo $SNAP_TO_DESTROY | xargs -n 1 zfs destroy -vr
        fi
    done
else
    echo $(date '+%Y-%m-%d %H:%M:%S') "Number of snapshots to keep not provided. Skipping."
fi

echo $(date '+%Y-%m-%d %H:%M:%S') "Done."
