#! /usr/bin/env bash
set -e
shopt -s nullglob

assets=""
libdir="$(realpath $(dirname $(readlink -f ${BASH_SOURCE[0]})))"
outdir=bundles

while [[ $# -gt 0 ]]; do
  case $1 in
    --pkg-name)
      pkgname="$2"
      shift
      shift
      ;;
    --pkg-dist)
      pkgdist="$2"
      shift
      shift
      ;;
    --pkg-version)
      pkgver="$2"
      shift
      shift
      ;;
    --output-directory)
      outdir="$2"
      shift
      shift
      ;;
    --target-user)
      targetuser="$2"
      shift
      shift
      ;;
    --target-instance)
      targetinstance="$2"
      shift
      shift
      ;;
    --target-domain)
      targetdomain="$2"
      shift
      shift
      ;;
    --assets-manifest)
      assetsmanifest="$2"
      shift
      shift
      ;;
    --)
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      assets="${assets} $1"
      shift 
      ;;
  esac
done

# exceptions
if [ -z "${pkgname}" ]; then
  echo "--pkg-name required" >&2
  exit 1
fi

if [ -z "${pkgver}" ]; then
  echo "--pkg-version required" >&2
  exit 1
fi

if [ -z "${pkgdist}" ]; then
  echo "--pkg-dist required" >&2
  exit 1
fi

if [ -z "${targetuser}" ]; then
  echo "--target-user required" >&2
  exit 1
fi

if [ -z "${targetinstance}" ]; then
  echo "--target-instance required" >&2
  exit 1
fi

if [ -z "${targetdomain}" ]; then
  echo "--target-domain required" >&2
  exit 1
fi

# setup vars
bundlename=${pkgname}-bundle-${pkgver}
bundledir=${outdir}/${bundlename}

# create a temporary directory
mkdir -p ${bundledir}


# cleanup the pre-existing files
if [ -d ${bundledir} ]; then
  rm -fr ${bundledir}/*
  rm -fr ${bundledir}/.*
fi


# copy python distribution 
cp ${pkgdist} ${bundledir}


# assets
if [ -n "${assets}" ]; then
  mkdir -p ${bundledir}/assets
  cp ${assets} ${bundledir}/assets
fi

if [ -n "${assetsmanifest}" ]; then
  cp ${assetsmanifest} ${bundledir}/assets-manifest.json
fi


# install.sh
cp ${libdir}/target-install.sh ${bundledir}/install.sh
chmod +x ${bundledir}/install.sh


# vars
echo -n "\
pydist=$(basename ${pkgdist})
pypkg=${pkgname}
user=${targetuser}
instance=${targetinstance}
domain=${targetdomain}
" > ${bundledir}/.vars

# bundle
outfile=${outdir}/${bundlename}.tar.gz
tar -cv -C ${outdir} -f ${outfile} ${bundlename}

# cleanup
rm -r ${outdir}/${bundlename}

# report
echo "bundle successfully generated: ${outfile}"
