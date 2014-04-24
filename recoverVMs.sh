#!/bin/bash
#
function quit
{
  echo "$*" ; exit
}

function usage 
{ 
  echo "Usage $0 -i -n -t -r [-x] [-z] [-h]"
  echo "-i virtual disk which should be restored"
  echo "-n name of the virtual machine"
  echo "-t the backup tar archive"
  echo "-r virtual disk image to be restored from the tar archive"
  echo "-x passphrase, if a passphras is set, the bakup will be encrypted"
  echo "-z compression program for tar e.g. gzip oder pigz. (default is gzip)"
  echo "-h shows this help"
  quit
}

while getopts "i:n:t:r:x:z:h" Option
do
  case $Option in
    i)vmHddFile="$OPTARG";;           # Option -i
    n)nameOfVm="$OPTARG";;            # Option -n
    t)backupTar="$OPTARG";;           # Option -t
    r)backupHddForRecover="$OPTARG";; # Option -r
    x)encKey="$OPTARG";;              # Option -x
    z)compressProgram="$OPTARG";;     # Option -Z
    h)usage;;                         # Option -h
  esac
done

if test ! -f ${vmHddFile} ; then 
  quit "Error(-i): the file ${vmHddFile}  does not exsist"
fi

stateOfVm=`virsh domstate $nameOfVm`
if test "${stateOfVm}" == "shut off" ; then 
  echo "VM ${nameOfVm} is shut off"
else
  quit "Error(-n): The VM ${nameOfCm} is ${stateOfVm}, but they must be shut off"
fi

if test -z ${backupHddForRecover} ; then 
  quit "Error(-r): you must specify a file from the tar backup archive"
fi
    
if test ! -f ${backupTar} ; then 
  quit "Error(-t): the file ${backupTar} does not exsist"
fi  

if test -z "${encKey}" ; then 
  enableEncryption="false"
  else
  enableEncryption="true"
fi

if test -z "${compressProgram}" ; then
  compressProgram="gzip"
fi

echo "start recovering"

echo "$enableEncryption"
if test "${enableEncryption}" == "true"
  then
  echo "encryption is on"
  openssl enc -d -aes-256-cbc -salt -pass pass:${encKey} -in ${backupTar} | tar -x -v --use-compress-program=${compressProgram} -f - ${backupHddForRecover} -O | dd of=${vmHddFile}
  else
  echo "encryption is off"
  tar -x -v --use-compress-program=${compressProgram} -f ${backupTar} ${backupHddForRecover} -O | dd of=${vmHddFile}
fi
