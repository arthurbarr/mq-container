#!/bin/bash
# -*- mode: sh -*-
# © Copyright IBM Corporation 2018
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Install one or more MQ components into a buildah container

set -ex

readonly ctr=$1
readonly scratchmnt=$2
readonly archive=$3
readonly mq_packages=$4
readonly dir_extract=/tmp/extract

if [[ $* < 3 ]]; then
  printf "Usage: $0 container mount-dir mq-archive mq-packages\n" >&2
  exit 1
fi

groupadd --root $scratchmnt --system --gid 888 mqm
useradd --root $scratchmnt --system --uid 888 --gid mqm mqm
usermod --root $scratchmnt -G root mqm

if [ ! -d ${dir_extract} ]; then
  mkdir -p ${dir_extract}
  tar -zxvf $archive -C ${dir_extract}
fi
#DIR_RPM=$(find ${dir_extract} -name "*.rpm" -printf "%h\n" | sort -u | head -1)
#DIR_RPM=${DIR_RPM#$dir_extract}
#DIR_RPM=$(buildah run $ctr -- find ${dir_extract} -name "*.rpm" -printf "%h\n" | sort -u | head -1)
# Find location of mqlicense.sh
#MQLICENSE=$(buildah run $ctr -- find ${dir_extract} -name "mqlicense.sh")
#MQLICENSE=$(find ${dir_extract} -name "mqlicense.sh")
#MQLICENSE=${MQLICENSE#dir_extract}

# Accept the MQ license
buildah run --volume ${dir_extract}:/mnt/mq-download $ctr -- /mnt/mq-download/MQServer/mqlicense.sh -text_only -accept

buildah run --volume ${dir_extract}:/mnt/mq-download $ctr -- bash -c "cd /mnt/mq-download/MQServer && rpm -ivh $mq_packages"

#rm -rf ${dir_extract}

# Remove 32-bit libraries from 64-bit container
find $scratchmnt/opt/mqm $scratchmnt/var/mqm -type f -exec file {} \; | awk -F: '/ELF 32-bit/{print $1}' | xargs --no-run-if-empty rm -f

# Remove tar.gz files unpacked by RPM postinst scripts
find $scratchmnt/opt/mqm -name '*.tar.gz' -delete

# Recommended: Set the default MQ installation (makes the MQ commands available on the PATH)
buildah run $ctr -- /opt/mqm/bin/setmqinst -p /opt/mqm -i

# Optional: Set these values for the IBM Cloud Vulnerability Report
sed -i 's/PASS_MAX_DAYS\t99999/PASS_MAX_DAYS\t90/' $scratchmnt/etc/login.defs
sed -i 's/PASS_MIN_DAYS\t0/PASS_MIN_DAYS\t1/' $scratchmnt/etc/login.defs
sed -i 's/password\t\[success=1 default=ignore\]\tpam_unix\.so obscure sha512/password\t[success=1 default=ignore]\tpam_unix.so obscure sha512 minlen=8/' $scratchmnt/etc/pam.d/password-auth