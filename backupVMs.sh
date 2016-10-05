#!/bin/bash
#
function quit
{
echo "$*" ; exit
}

function usage
{
  echo "Usage: $0 -d [-c] -p -l -g -v -s [-x] [-z] [-h]"
  echo "-d Space-seperated list of the virtuel disks e.g. /vm/HDD1.img /vm/HDD2.img"
  echo "-c comment (this will be enterd in the backups name)"
  echo "-p directory to store the backups"
  echo "-l directory to mount the logical volume snapshot"
  echo "-g name of virtual disks contained logical volume GROUP"
  echo "-v name of virtual disks contained logical volume"
  echo "-s size of the logical volume snapshot e.g. 10G for 10 giga bytes"
  echo "-x passphrase, if a passphras is set, the bakup will be encrypted"
  echo "-z compression program for tar e.g. gzip or pigz. (default is gzip)"
  echo "-h shows this help"
  quit
}

function removeLv
{
echo "remove Snapshot"
if ! lvremove -f /dev/"${nameOfVolumeGroup}"/"${nameOfSnapshotVolume}"; then
 quit "Error: faild to remove the logical volume snapshot \n(a maual correction is necessary !)"
fi
}

while getopts "d:c:p:l:g:v:s:x:z:h" Option
do
  case $Option in
    d)toBackupVmHdds="$OPTARG";;       # Option -d
    c)backupComment="$OPTARG";;        # Option -c
    p)pathOfBackupDir="$OPTARG";;      # Option -p
    l)pathOfSnapshotDir="$OPTARG" ;;   # Option -l
    g)nameOfVolumeGroup="$OPTARG";;    # Option -g
    v)nameOfLogicalVolume="$OPTARG";;  # Option -v
    s)sizeOfSnapshot="$OPTARG";;       # Option -s
    x)encKey="$OPTARG";;               # Option -x
    z)compressProgram="$OPTARG";;      # Option -z
    h)usage;;                          # Option -h
  esac
done

if test -z "${toBackupVmHdds}" ; then
  quit "Error(-d): no virtual disk selected"
fi

if test ! -d "${pathOfBackupDir}" ; then
  quit "Error(-p): directory ${pathOfBackupDir} does not exsist"
fi

if test -z "${pathOfSnapshotDir}" ; then
  quit "Error(-l): you must specify a directory, to mount the logical volume snapshot."
fi

if test ! -e /dev/"${nameOfVolumeGroup}"/"${nameOfLogicalVolume}" ; then
  quit "Error(-g/-v): volume name (${nameOfLogicalVolume}) or/and volume group (${nameOfVolumeGroup}) does not exsist"
fi

if test -z "${sizeOfSnapshot}" ; then
  quit "Error(-s): you must specify a size for the logical volume snapshot"
fi

if test -z "${encKey}" ; then
  enableEncryption="false"
  else
  enableEncryption="true"
fi

if test -z "${compressProgram}" ; then
  compressProgram="gzip"
fi

backupVolumeNameSuffix="_Snapshot"
dateAndTime=$(date +"%d.%m.%y-%H%M") # will be added to the backups name
mountPointLogicalVolume=$(mount | grep "${nameOfLogicalVolume}" | grep "${nameOfVolumeGroup}" | awk 'BEGIN {FS=" "} ; {print $3}' | sed "s/\//\\\\\\\\\//g")
nameOfSnapshotVolume="${nameOfLogicalVolume}""${backupVolumeNameSuffix}"
listOfHdds=$(echo "$toBackupVmHdds" | sed "s/ /_/g" | sed "s/\//:/g" | awk 'BEGIN {FS=":"} ; {print $NF}') # replace space by '_' and replace '/' by ':'
comment=$(echo "$backupComment" | sed "s/ /_/g") #replace spaces in the comment by '_'
nameOfBackup=${dateAndTime}-${comment}
pathOfSnapshotDirTmp=$(echo "$pathOfSnapshotDir" | sed "s/\//\\\\\\\\\//g") # replace '/' by '\/'
toBackupVmHdds=$(echo "$toBackupVmHdds" | sed "s/${mountPointLogicalVolume}/${pathOfSnapshotDirTmp}/g") # replace the original path through the snapshots one

# start of backup process

echo "enable kernelmodul dm-snapshot"
if ! modprobe dm-snapshot; then
 quit "Error: when activating kernel module: dm-snapshot"
fi

echo "create $nameOfSnapshotVolume Snapshot"
if ! lvcreate --size "${sizeOfSnapshot}" --snapshot --name "${nameOfSnapshotVolume}" /dev/"${nameOfVolumeGroup}"/"${nameOfLogicalVolume}" ; then
 quit "Error: when creating the logical volume snapshot"
fi

echo "create directory ${pathOfSnapshotDir}, if it does not exist"
if ! mkdir -p "${pathOfSnapshotDir}" ; then
  removeLv ; quit "Error: could not create directory ${pathOfSnapshotDir}"
fi

echo "mount Snapshot (read only)"
if ! mount --read-only  /dev/"${nameOfVolumeGroup}"/"${nameOfSnapshotVolume}" "${pathOfSnapshotDir}" ; then
 removeLv ; quit "Error: could not mount the snapshot"
fi

echo "backup the virtual hard disks"
if test "${enableEncryption}" == "true"
  then
    echo "encryption in on"
    tar --create --use-compress-program=${compressProgram} --verbose -f - "${toBackupVmHdds}" | openssl enc -e -aes-256-cbc -salt -pass "pass:${encKey}" -out "${pathOfBackupDir}"/"${nameOfBackup}".tar.aes256
  else
    echo "encryption is off"
    tar --create --use-compress-program=${compressProgram} --verbose -f "${pathOfBackupDir}"/"${nameOfBackup}".tar "${toBackupVmHdds}"
fi

echo "umount ${pathOfSnapshotDir}"
if ! umount "${pathOfSnapshotDir}"; then
 removeLv ; quit "Error: when umount the virtual volume \n(a manual correction is necessary !)"
fi

echo "remove ${pathOfSnapshotDir}"
rmdir "${pathOfSnapshotDir}"

# remove logical volume snapshot
removeLv

