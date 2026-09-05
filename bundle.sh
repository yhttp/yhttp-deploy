#! /usr/bin/env bash
set -e
PS4='+ ${BASH_SOURCE}:${LINENO}: '
shopt -s nullglob

assets=""
xtrace=false
libdir="$(realpath $(dirname $(readlink -f ${BASH_SOURCE[0]})))"
outdir=bundles
userconfigfile="production.yml"
publicdir=public
nginxgroup=www-data


while [[ $# -gt 0 ]]; do
  case $1 in
    -v)
      xtrace=true
      shift
      ;;
    --pkg-name)
      pkgname="$2"
      shift
      shift
      ;;
    --namespace)
      namespace="$2"
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
    --target-ssldomain)
      targetssldomain="$2"
      shift
      shift
      ;;
    --target-aliasdomains)
      targetaliasdomains="$2"
      shift
      shift
      ;;
    --assets-manifest)
      assetsmanifest="$2"
      shift
      shift
      ;;
    --configuration-file)
      userconfigfile="$2"
      shift
      shift
      ;;
    --admin-email)
      adminemail="$2"
      shift
      shift
      ;;
    --pyver)
      pyver="$2"
      shift
      shift
      ;;
    --nginx-configfile)
      nginxconfigfile="$2"
      shift
      shift
      ;;
    --nginx-group)
      nginxgroup="$2"
      shift
      shift
      ;;
    --public-directory)
      publicdir="$2"
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

if ${xtrace}; then
  set -x
fi


# validation
if [ -z "${pkgname}" ]; then
  echo "--pkg-name required" >&2
  exit 1
fi

if [ -z "${namespace}" ]; then
  namespace=${pkgname}
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

if [ -z "${targetssldomain}" ]; then
  targetssldomain=${targetdomain}
fi

if [ ! -f "${userconfigfile}" ]; then
  echo "cannot find ${userconfigfile}, please provide this file or specify \
another file with --configuration-file option." >&2
fi

if [ -z "${adminemail}" ]; then
  echo "--admin-email required" >&2
  exit 1
fi

if [ -z "${pyver}" ]; then
  echo "--pyver required" >&2
  exit 1
fi

if [ -z "${nginxconfigfile}" ]; then
  nginxconfigfile=${targetdomain}
fi


# setup vars
bundlename=${pkgname}-bundle-${pkgver}-${targetdomain}
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


# public files
if [ -d "${publicdir}" ] && [ -n "$(ls -A ${publicdir})" ]; then
  mkdir -p ${bundledir}/public
  cp -r ${publicdir}/* ${bundledir}/public
fi


# install.sh
cp ${libdir}/target-install.sh ${bundledir}/install.sh
cp ${libdir}/target-uninstall.sh ${bundledir}/uninstall.sh
chmod +x ${bundledir}/install.sh
chmod +x ${bundledir}/uninstall.sh


# user configuration file
cp ${userconfigfile} ${bundledir}


# vars
echo -n "\
pydist=$(basename ${pkgdist})
pypkg=${pkgname}
pynamespace=${namespace}
user=${targetuser}
instance=${targetinstance}
domain=${targetdomain}
ssldomain=${targetssldomain}
aliasdomains=${targetaliasdomains}
userconfigfile=${userconfigfile}
adminemail=${adminemail}
pyver=${pyver}
nginxconfigfile=${nginxconfigfile}
nginxgroup=${nginxgroup}
" > ${bundledir}/.vars


# bundle
outfile=${outdir}/${bundlename}.tar.gz
tar -cv -C ${outdir} -f ${outfile} ${bundlename}


# cleanup
rm -r ${outdir}/${bundlename}


# report
echo "bundle successfully generated: ${outfile}"
