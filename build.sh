#!/bin/bash
set -euo pipefail

LINUX_DISTRO=xenial
LIVY_VERSION=0.6.0
LIVY_TAG="${LIVY_VERSION}-incubating"
LIVY_URL="https://www-eu.apache.org/dist/incubator/livy/${LIVY_TAG}/apache-livy-${LIVY_TAG}-bin.zip"
LIVY_SHA512_URL="${LIVY_URL}.sha512"


CLOUDERA_CSD_DIR="${CLOUDERA_CSD_DIR:-/opt/cloudera/csd}"
CLOUDERA_PARCEL_REPO_DIR="${CLOUDERA_PARCEL_REPO_DIR:-/opt/cloudera/parcel-repo}"
CLOUDERA_MANAGER_USER="cloudera-scm"
CLOUDERA_MANAGER_GROUP="cloudera-scm"

my_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

livy_dl_dest="${my_dir}/download"
livy_bld_dest="${my_dir}/build"
livy_tgt_dest="${my_dir}/target"
livy_archive="${livy_dl_dest}/$( basename $LIVY_URL )"
livy_sha512="${livy_dl_dest}/$( basename $LIVY_SHA512_URL )"
livy_org_folder="${livy_bld_dest}/$( basename $livy_archive .zip )"
livy_folder="${livy_bld_dest}/LIVY-${LIVY_VERSION}"
livy_parcel="${livy_tgt_dest}/LIVY-${LIVY_VERSION}-${LINUX_DISTRO}.parcel"
livy_manifest="${livy_tgt_dest}/manifest.json"
livy_csd_src="${my_dir}/livy-csd-src"
livy_parcel_src="${my_dir}/livy-parcel-src"
validator="${my_dir}/cm_ext/validator.jar"
manifestor="${my_dir}/cm_ext/make_manifest.py"


function get_livy {
  [ -d "${livy_dl_dest}" ] || mkdir "${livy_dl_dest}"
  [ -f "${livy_archive}" ] || wget -O "${livy_archive}" "${LIVY_URL}"
  [ -f "${livy_sha512}" ]  || wget -O "${livy_sha512}" "${LIVY_SHA512_URL}"
  soll_sum=$( tr -d ' \t\n\r' < "${livy_sha512}" | cut -d: -f2 )
  ist_sum=$( sha512sum "${livy_archive}" | cut -d' ' -f1 )
  if [ "${ist_sum,,}" != "${soll_sum,,}" ]; then
    echo "Checksum mismatch for ${livy_archive}" >&2
    exit 1
  fi
  [ -d "${livy_bld_dest}" ] || mkdir "${livy_bld_dest}"
  unzip -q -d "${livy_bld_dest}" "${livy_archive}"
  mv "${livy_org_folder}" "${livy_folder}"
}


function build_livy_parcel {
  [ -d "${livy_folder}" ] || get_livy
  cp -r "${livy_parcel_src}/meta" "${livy_folder}"
  sed -i -e "s/%VERSION%/${LIVY_VERSION}/" "${livy_folder}/meta/parcel.json"
  java -jar "${validator}" -d "${livy_folder}"
  [ -f "${livy_parcel}" ] && rm -f "${livy_parcel}"
  [ -f "${livy_manifest}" ] && rm -f "${livy_manifest}"
  [ -d "${livy_tgt_dest}" ] || mkdir "${livy_tgt_dest}"
  tar zchf "${livy_parcel}" -C "${livy_bld_dest}" "LIVY-${LIVY_VERSION}" --owner=root --group=root
  java -jar "${validator}" -f "${livy_parcel}"
  sha1sum "${livy_parcel}" | cut -d' ' -f1 > "${livy_parcel}.sha"
  python "${manifestor}" "${livy_tgt_dest}"
}


function build_livy_csd {
  csdfile="${livy_tgt_dest}/LIVY-${LIVY_VERSION}.jar"
  [ -f "${csdfile}" ] && rm -f "${csdfile}"
  java -jar "${validator}" -s "${livy_csd_src}/descriptor/service.sdl" -l "SPARK_ON_YARN SPARK2_ON_YARN"
  [ -d "${livy_tgt_dest}" ] || mkdir "${livy_tgt_dest}"
  jar -cvf "${csdfile}" -C "${livy_csd_src}" .
}


make_clean() {
  [ -d "${livy_dl_dest}" ] && rm -rf "${livy_dl_dest}"
  [ -d "${livy_bld_dest}" ] && rm -rf "${livy_bld_dest}"
  [ -d "${livy_tgt_dest}" ] && rm -rf "${livy_tgt_dest}"
}

install() {
  csdfile="${livy_tgt_dest}/LIVY-${LIVY_VERSION}.jar"
  livy_parcel_sha="${livy_parcel}.sha"
  [ -f "${csdfile}" ] && cp "${csdfile}" "${CLOUDERA_CSD_DIR}" && chown "${CLOUDERA_MANAGER_USER}:${CLOUDERA_MANAGER_GROUP}" "${CLOUDERA_CSD_DIR}/`basename ${csdfile}`"
  [ -f "${livy_parcel_sha}" ] && cp "${livy_parcel_sha}" "${CLOUDERA_PARCEL_REPO_DIR}" && chown "${CLOUDERA_MANAGER_USER}:${CLOUDERA_MANAGER_GROUP}" "${CLOUDERA_PARCEL_REPO_DIR}/`basename ${livy_parcel_sha}`"
  [ -f "${livy_parcel}" ] && cp "${livy_parcel}" "${CLOUDERA_PARCEL_REPO_DIR}" && chown "${CLOUDERA_MANAGER_USER}:${CLOUDERA_MANAGER_GROUP}" "${CLOUDERA_PARCEL_REPO_DIR}/`basename ${livy_parcel}`"
}

case "$1" in
clean)
  make_clean
  ;;
parcel)
  build_livy_parcel
  ;;
csd)
  build_livy_csd
  ;;
install)
  install
  ;;
all)
  build_livy_parcel
  build_livy_csd
  ;;
*)
  echo "Usage: $0 [all|parcel|csd|clean|install]"
  ;;
esac
