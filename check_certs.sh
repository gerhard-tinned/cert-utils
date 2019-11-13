#!/bin/sh
#
# BSD 2-Clause License
# 
# Copyright (c) 2019, cs@brnfck.at and gerhard@tinne-software.net
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

function usage
{
  echo "Usage: `basename $0` [-h|--help] <destination|filename> [openssl-options]"
  echo ""
  echo "Options:"
  echo "  -h, --help       Print this usage and exit"
  echo "  destination      Connect string used by openssl s-client to connect to."
  echo "  filename         Filename to read certificates from."
  echo "  openssl-options  Openssl x509 options to show required details for the certificates."
  echo "                   Default: -subject -issuer -email -dates -fingerprint -noout"
  echo ""
  exit 1
}

if [ $# -lt 1 ]; then
  echo "ERROR: at least one argument (destination or local filename) required."
  usage
  exit 1
fi

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  usage
elif [ -r "$1" ]; then 
  CCMD=$(cat "$1")
else
  CCMD=$(echo | openssl s_client -connect $1 -showcerts)
fi

shift
if [ ! -z "$*" ]; then
  SSLOPTS=$*
else
  SSLOPTS="-subject -issuer -email -dates -fingerprint -noout"
fi

FILETMP=$(mktemp)

echo -e "${CCMD}" | \
    awk -v SSLOPTS="${SSLOPTS}" -v FILETMP="${FILETMP}" '
        /-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/ \
            {
                print >>FILETMP
            }
        /-----END CERTIFICATE-----/ \
            { 
                printf("\nCertificate details\n===================\n")
                system("cat "FILETMP" | openssl x509 "SSLOPTS" ; echo >"FILETMP)
            }
        END \
            { 
                print "----------------------------" ;
                system("rm "FILETMP)
            }'
