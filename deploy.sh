#! /usr/bin/env bash
set -e

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)
      host="$2"
      shift
      shift
      ;;
    --bundle)
      bundle="$2"
      shift
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      echo "Unknown positional $1"
      exit 1
      ;;
  esac
done


# exceptions
if [ -z "$host" ]; then
  echo "--host required" >&2
  exit 1
fi

if [ -z "$bundle" ]; then
  echo "--bundle required" >&2
  exit 1
fi

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
bundletar=$(basename ${bundle})
bundledir=${bundletar%.tar.gz}
targettmp=/tmp/${timestamp}
sshhost=root@${host}

ssh ${sshhost} "mkdir ${targettmp}"
scp ${bundle} ${sshhost}:${targettmp}
ssh ${sshhost} "tar -xv -C ${targettmp} -f ${targettmp}/${bundletar}"
ssh ${sshhost} "${targettmp}/${bundledir}/install.sh"
ssh ${sshhost} "rm -r ${targettmp}"
