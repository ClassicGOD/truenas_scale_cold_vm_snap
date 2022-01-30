#!/bin/bash

# Defaults
VM_NAME=""
CHECK_TIME=5
DATASETS=""
KEEP_SNAP=0
RETRY_COUNT=1
SNAP_NAME="vmbk"
WAIT_COUNT=20

NUM_RE='^[0-9]+$'

# Get Arguments
while getopts ":hc:d:k:r:n:t:w:" opt; do
  case $opt in
    h)
      echo "Usage: vmbk.sh [OPTIONS] VM_NAME"
      echo ""
      echo " Option			Meaning"
      echo " -d <dataset>		Dataset to backup. Setting -d diables automatic dataset detection."
      echo "			(use multiple -d options for multiple datasets)"
      echo " -h 			Display this message"
      echo " -k <number>		Number of latest shapshots to keep. (default: unlimited)"
      echo " -n <name>  		Common part of snapshot name. (default: vmbk)"
      echo " -r <number>		Number of retries to shut the vm down before giving up. (default: 1)"
      echo " -t <number>		Time between vm status checks in sec. (default: 5)"
      echo " -w <number>		Number of status checks while waiting for vm to shut down (default: 20)"
      exit 0
      ;;
    d)
      if [ "$DATASETS" != "" ]; then
        DATASETS+=$'\n'
      fi
      DATASETS+=$OPTARG
      ;;
    k)
      if ! [[ $OPTARG =~ $NUM_RE ]]; then
        echo "Option -$opt argument has to be a number."
        exit 1
      fi
      KEEP_SNAP=$OPTARG
      ;;
    n)
      SNAP_NAME=$OPTARG
      ;;
    r)
      if ! [[ $OPTARG =~ $NUM_RE ]]; then
        echo "Option -$opt argument has to be a number."
        exit 1
      fi
      RETRY_COUNT=$OPTARG
      ;;
    t)
      if ! [[ $OPTARG =~ $NUM_RE ]]; then
        echo "Option -$opt argument has to be a number."
        exit 1
      fi
      CHECK_TIME=$OPTARG
      ;;
    w)
      if ! [[ $OPTARG =~ $NUM_RE ]]; then
        echo "Option -$opt argument has to be a number."
        exit 1
      fi
      WAIT_COUNT=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

VM_NAME=$1

if [ "$VM_NAME" == "" ]; then
  echo "VM_NAME required"
  exit 1
fi

echo $(date '+%H:%M:%S') "[Info] VMBK starting" $(date '+%Y-%m-%d %H:%M:%S')

# Get VM id
VM_ID=$(midclt call vm.query | jq ".[] | if .name == \"$VM_NAME\" then .id else empty end")
if [ "$VM_ID" == "" ]; then
    echo $(date '+%H:%M:%S') "[Error] VM $VM_NAME not found"
    exit 1
fi

echo $(date '+%H:%M:%S') "[Info] $VM_NAME has id $VM_ID"

# Get dataset list if not provided
if [ "$DATASETS" == "" ]; then
    DATASETS=$(midclt call vm.query | jq ".[] | if .id == $VM_ID then .devices else empty end | .[] | if .dtype == \"DISK\" then .attributes.path else empty end" |  sed -e "s/^\"\/dev\/zvol\///" -e "s/\"$//")
fi

# Check if all datasets exist
echo "$DATASETS" | while read DATASET ; do
    RC=$(zfs list $DATASET 2> /dev/null 1> /dev/null)
    if [ $? -eq 1 ] ; then
        echo  $(date '+%H:%M:%S') "[Error] dataset $DATASET not found"
	exit 1
    fi
    echo $(date '+%H:%M:%S') "[Info] dataset to snapshot: $DATASET"
done

if [ $? -eq 1 ] ; then
  exit 1
fi

# Get and store vm state
VM_STATE=$(midclt call vm.status $VM_ID | jq '.state')

# Shutdown VM if it's running
if [ "$VM_STATE" != "\"STOPPED\"" ]; then
    midclt call vm.stop $VM_ID | xargs echo $(date '+%H:%M:%S') "[Info] shutting down $VM_NAME"

    WAIT_COUNTER=0
    RETRY_COUNTER=0

    while [ $(midclt call vm.status $VM_ID | jq '.state') != "\"STOPPED\"" ]; do
        WAIT_COUNTER=$((WAIT_COUNTER+1))

        if [ "$WAIT_COUNTER" -gt "$WAIT_COUNT" ]; then
            if [ "$RETRY_COUNTER" -lt "$RETRY_COUNT" ]; then
                RETRY_COUNT=$((RETRY_COUNT+1))
                WAIT_COUNTER=1
                echo $(date '+%H:%M:%S') "[Info] $VM_NAME still running - retrying ($RETRY_COUNTER/$RETRY_COUNT)"
                midclt call vm.stop $VM_ID | xargs echo $(date '+%H:%M:%S') "[Info] shutting down $VM_NAME."
            else
                echo $(date '+%H:%M:%S') "[Error] failed to stop $VM_NAME"
                exit 1
            fi
        fi

        echo $(date '+%H:%M:%S') "[Info] waiting for $VM_NAME to shutdown ($WAIT_COUNTER/$WAIT_COUNT)"
        sleep $CHECK_TIME
    done
    echo $(date '+%H:%M:%S') "[Info] $VM_NAME stopped"
else
    echo $(date '+%H:%M:%S') "[Info] $VM_NAME is not running"
fi

# Snapshot datasets on list
echo "$DATASETS" | while read DATASET ; do
    SNAPSHOT_NAME=$(date "+$DATASET@$SNAP_NAME-%Y-%m-%d_%H-%M")
    zfs snapshot $SNAPSHOT_NAME | xargs echo $(date '+%H:%M:%S') "[Info] taking snapshot $SNAPSHOT_NAME"
done

# Start the vm if it was not stopped initialy
if [ "$VM_STATE" != "\"STOPPED\"" ]; then
    echo $(date '+%H:%M:%S') "[Info] starting $VM_NAME"
    midclt call vm.start $VM_ID > /dev/null
fi

# Destroy older snapshots if requested
KEEP_TAIL=$((KEEP_SNAP+1))
if [ "$KEEP_SNAP" -gt "0" ]; then
    KEEP_TAIL=$((KEEP_SNAP+1))
    echo "$DATASETS" | while read DATASET ; do
        echo $(date '+%H:%M:%S') "[Info] destroying older snapshots for $DATASET"
        echo $(date '+%H:%M:%S') "[Info] keeping $KEEP_SNAP latest"
        SNAPS_TO_DESTROY=$(zfs list -t snapshot -o name -S creation | grep "^$DATASET@$SNAP_NAME" | tail -n +$KEEP_TAIL)
        if [ "$SNAPS_TO_DESTROY" == "" ]; then
             echo $(date '+%H:%M:%S') "[Info] no snapshots to destroy"
        else
            echo "$SNAPS_TO_DESTROY" | while read SNAP_TO_DESTROY ; do
              zfs destroy -vr $SNAP_TO_DESTROY | xargs echo $(date '+%H:%M:%S') "[Info]"
            done
        fi
    done
else
    echo $(date '+%H:%M:%S') "[Info] number of snapshots to keep not provided - skipping"
fi

echo $(date '+%H:%M:%S') "[Info] done"
