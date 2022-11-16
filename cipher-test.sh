#!/bin/bash
#
# BSD 2-Clause License
# 
# Copyright (c) 2019-2022, cs@brnfck.at and gerhard@tinned-software.net
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
#
VERSION=0.2.0
#

# Color definition
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
RED='\e[0;31m'
BLUE='\e[0;36m'
RST='\e[0m'

#
# Help screen
#
function help_screen () {
    echo 
    echo "Usage: $(basename $0) [-hv] [--tls protocol] [--out DIR] hostname:port"
    echo "  -h  --help              print this usage and exit"
    echo "  -v  --version           print version information and exit"
    echo "      --tls protocol      The starttls protocol used by s_client --starttls"
    echo "                          'smtp', 'pop3', 'imap', 'ldap', ... see all in the s_client(1) man page"
    echo "      --out DIR           Set the output directory for the openssl output."
    echo "      hostname:port       Connect string used by openssl s_client to connect to."
    echo ""
}

function version_screen
{
    echo 
    echo "`basename $0` Version $VERSION"
    echo
    echo "Copyright (c) 2019-2022 gerhard@tinned-software.net"
    echo "BSD 2-Clause License <https://opensource.org/licenses/BSD-2-Clause>"
    echo 
}

function errorout () {
    echo -e "$@" >&2
}

function echoout () {
    echo -e "$@"
}

function cleanexit () {
    if [[ "${CLEANUP}" == "1" ]]; then
        rm -f ${OUT_DIR}/${HOSTDETAIL}_*.out
        rmdir ${OUT_DIR}
    fi
    exit $1
}

# catch signal and call cleanexit to cleanup temporary files
trap 'cleanexit' SIGINT

OUT_DIR=""
STARTTLS=""
while [ $# -gt 0 ]; do
    case $1 in
        # General parameter
        -h|--help)
            help_screen
            cleanexit 0
            ;;

        -v|--version)
            version_screen
            cleanexit 0
            ;;

        --tls)
            if [[ ! -z "$2" ]]; then
                STARTTLS="-starttls $2"
            else
                errorout "ERROR: No starttls protocolspecified."
                help_screen
                cleanexit 1
            fi
            shift 2
            ;;

        --out)
            if [[ ! -z "$2" ]] && [[ -d "$2" ]]; then
                OUT_DIR=$2
            else
                errorout "ERROR: Specified directory '$2' does not exist."
                help_screen
                cleanexit 1
            fi
            shift 2
            ;;

        *)
			HOSTDETAIL=$1
            shift 1
            ;;
    esac
done

# Load the configuration file
if [[ -z "${HOSTDETAIL}" ]]; then
    errorout "ERROR: No destination host specified."
    help_screen
    cleanexit 1
fi

###############################################################################
###############################################################################


# If no output directory is provided, create a temp directory
# If a temp directory is created, set cleanup variable to cleanup at the end
if [[ "${OUT_DIR}" == "" ]]; then
	OUT_DIR=$(mktemp -d -t cipher-test-XXXXXXXX)
    CLEANUP=1
else
    CLEANUP=0
fi

# List of protocols to loop through
PROTOCOL_NAME_LIST=(  "SSLv2" "SSLv3" "TLSv1" "TLSv1.1" "TLSv1.2" "TLSv1.3")
PROTOCOL_OPTION_LIST=("-ssl2" "-ssl3" "-tls1" "-tls1_1" "-tls1_2" "-tls1_3")

for (( I = 0; I <= ${#PROTOCOL_NAME_LIST}; I++ )); do
    # Get the protocol name and openssl protocol option
    PROTO_NAME=${PROTOCOL_NAME_LIST[$I]}
    PROTO_OPTION=${PROTOCOL_OPTION_LIST[$I]}

    # Check if ciphers are listed by the local openssl 
    CIPHER_LIST=$(openssl ciphers -v 'ALL:NULL' | grep "${PROTO_NAME}"| awk '{print $1}')
    if [[ "${PIPESTATUS[0]}" -ne 0  ]] || [[ "${PIPESTATUS[2]}" -ne 0  ]] || [[ -z "${CIPHER_LIST}" ]]; then
        # if an error occured or the list is empty, openssl is not supporting 
        # this tls/ssl protocol - continue with the next
        continue
    fi

    # openssl versions with TLSv1.3 support use a different cipher argument 
    # for the TSLv1.3 ciphers
    if [[ "${PROTO_NAME}" == "TLSv1.3" ]]; then
        CIPHER_OPTION="-ciphersuites"
    else
        CIPHER_OPTION="-cipher"
    fi

    # loop through the list of ciphers for this protocol version
    for C in ${CIPHER_LIST}; do
        # use the correct protocol version argument to for this version of SSL/TLS
        # set the specific cipher with "-cipher" or for TLSv1.3 "-ciphersuites"
        echo -e "QUIT" | openssl s_client -debug ${STARTTLS} -connect ${HOSTDETAIL} ${PROTO_OPTION} ${CIPHER_OPTION} $C &>${OUT_DIR}/${HOSTDETAIL}_${PROTO_NAME}_${C}.out 
        # check the return code and print out the OK or Failed message
        if [[ "$?" -eq "0" ]]; then
            CIPHER_REPORTED=$(grep "^New, " ${OUT_DIR}/${HOSTDETAIL}_${PROTO_NAME}_${C}.out | sed -e "s/^New, //")
            echoout "${PROTO_NAME} ${C} ... ${BLUE}${CIPHER_REPORTED}${RST} ... ${GREEN}OK${RST}"
        else
            errorout "${PROTO_NAME} ${C} ... ${RED}FAILED${RST}"
        fi
    done

done 

cleanexit 0