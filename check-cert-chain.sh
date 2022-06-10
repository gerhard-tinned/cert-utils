#!/bin/sh
#
# BSD 2-Clause License <https://opensource.org/licenses/BSD-2-Clause>
# 
# Copyright (c) 2014-2022, Tinned-Software (gerhard@tinned-software.net)
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
VERSION=0.1.8
#

# Color definition
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
RST=$(tput sgr 0)

function usage
{
  echo 
  echo "This script will accept a list of files in PEM format. These files "
  echo "will be analysed to draw the certificate chain. The script also "
  echo "identifies which key is related to what certificate."
  echo 
  echo "Usage: `basename $0` [-hv] [--temp-path /path/to/temp/director/] [--chain-for-item ID] [--save-chain DIRECTORY] cert-file1.pem ... cert-fileN.pem "
  echo "  -h  --help               Print this usage and exit"
  echo "  -v  --version            Print version information and exit"
  echo "      --temp-path          Specify a directory where the script can create temporary files"
  echo "                           This directory will contain the individual parts of PEM files"
  echo "      --chain-for-item ID  Create the chain for the key (key needs to be provided in the files)"
  echo "      --save-chain DIR     Save the chain files as key, certificate and chain"
  echo "                           Save-chain requires --chain-for-item to function"
  echo "  -d                       Show more details about the certificate chain"
  echo "  -n  --no-colour          Do not use ANSI colours."
  echo 
}

function version
{
  echo 
  echo "`basename $0` Version $VERSION"
  echo
  echo "Copyright (c) 2014-2022 Tinned-Software (gerhard@tinned-software.net)"
  echo "BSD 2-Clause License <https://opensource.org/licenses/BSD-2-Clause>"
  echo 
}

# cleanup temporary directory
function clean_temp
{
  if [[ ! -z "${TEMP_PATH}" ]]; then
    if [[ "${DETAILS}" -ge "2" ]]; then echo "*** Cleanup Temp Directory: ${TEMP_PATH} ($(pwd))"; fi
    rm -rf "${TEMP_PATH}"
  fi
}
trap clean_temp exit

#
# Parse all arguments
#
INPUT_FILE_LIST=''
NOCOLOR=0
DETAILS=0
SAVE_CHAIN=''
TEMP_PATH=''
while [ $# -gt 0 ]; do
  case $1 in
    # General arguments
    -h|--help)
      usage
      exit 0
      shift
      ;;
    -v|--version)
      version
      exit 0
      ;;

    # specific arguments
    --temp-path)
      TEMP_PATH=$(mktemp -d $2/XXXXX)
      shift 2
      ;;

    --chain-for-item)
      if [[ "$2" -ge "1" ]]; then
        CHAIN_FOR_KEY="$2"
        shift 2
      else 
        echo "please specify the internal-id of the key."
        usage
        exit 1
        shift 1
      fi
      ;;

    --save-chain)
      if [[ -d "$2" ]]; then
        SAVE_CHAIN=$2
      else 
        echo "ERROR: Save-chain requires a target directory."
        usage
        exit 1
      fi
      shift 2
      ;;

    -d)
      DETAILS=$((DETAILS+1))
      shift 1
      ;;

    -n|--no-colour)
      GREEN=''
      YELLOW=''
      RED=''
      BLUE=''
      RST=''
      shift 1
      ;;


    # Unnamed arguments        
    *)
      if [[ -f $1 ]]; then
        INPUT_FILE_LIST="$INPUT_FILE_LIST $1"
      else
        echo "Unknown option '$1'"
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Check required arguments
if [ "$INPUT_FILE_LIST" == "" ]; then
  echo "ERROR: At least one file parameter is required."
  usage
  exit 1
fi
if [ "$TEMP_PATH" == "" ]; then
  TEMP_PATH=$(mktemp -d)
  echo "The temp-path is not specified, temp-path created as $TEMP_PATH."
fi

# Check argument dependencies
if [[ "${SAVE_CHAIN}" == "YES" ]] && [[ -z "${CHAIN_FOR_KEY}" ]]; then
  echo "ERROR: The option --save-chain requires --chain-for-item."
  usage
  exit 1
fi

# change the command used according to the OS specifics
# Mac OS X ... Darwin
# Linux ...... Linux
DETECTED_OS_TYPE=`uname -s`

# for each file do
echo " ... Processing certificate and key files ..."
if [[ "${DETAILS}" -ge "2" ]]; then echo "*** Splitting up files into certificates and keys ... ${INPUT_FILE_LIST}"; fi
for FILE in $INPUT_FILE_LIST; do
  # Get the number of parts in this file
  PART_COUNT=`grep "\-\-\-\-\-BEGIN" ${FILE} | wc -l`

  # get the repeat value for the csplit command
  REPEAT_COUNT=$((PART_COUNT - 2))

  # get the basename of the certificate file
  FILE_BASENAME=`basename "${FILE}"`

  # if only one certificate in the file, copy it over
  if [[ "${REPEAT_COUNT}" -lt "0" ]]; then
    if [[ "${DETAILS}" -ge "2" ]]; then echo "*** Splitting up file ${FILE} into parts ... only 1 part - copy w/o split"; fi
    cp "${FILE}" "${TEMP_PATH}/${FILE_BASENAME}"
    continue
  fi

  # OS specific parameters to execute csplit
  if [[ "${DETAILS}" -ge "2" ]]; then echo "*** DBG: ${FILE} with ${PART_COUNT} parts ... csplit (${DETECTED_OS_TYPE})" ; fi
  case ${DETECTED_OS_TYPE} in 
    Linux)
      csplit --elide-empty-files -s -f ${TEMP_PATH}/${FILE_BASENAME}_part ${FILE} '/-----BEGIN/' '{*}'
      ;;
    Darwin)
      csplit -s -f ${TEMP_PATH}/${FILE_BASENAME}_part ${FILE} '/-----BEGIN/' "{${REPEAT_COUNT}}"
      ;;
  esac
done


echo " ... Analysing certificates and keys ..."
FLC=0
KEY_LIST=''
for FILE in ${TEMP_PATH}/*; do
  if [[ "${DETAILS}" -ge "2" ]]; then echo "*** Checking parts ... ${FILE}"; fi

  # Detect the type of element (KEY, CERTIFICATE)
  TYPE=`grep -h "\-\-\-\-\-BEGIN" "$FILE" | sed 's/^.* \([A-Z]*\).*$/\1/'`
  mv "$FILE" "${FILE}-${TYPE}"

  # extract and store details for later
  FILE_LIST[$FLC]="${FILE}-${TYPE}"
  if [[ "${TYPE}" == "CERTIFICATE" ]]; then
    FILE_TYPE[$FLC]='CERT'
    FILE_PUB_KEY[$FLC]=$(openssl x509 -pubkey -noout -in "${FILE}-${TYPE}" | openssl sha1 )
    FILE_HASH[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -hash 2>/dev/null )
    FILE_ISSUER_HASH[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -issuer_hash 2>/dev/null )
    FILE_SIG_KEY_ID[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -text 2>/dev/null | grep -A1 "Authority Key Identifier" |grep -v X509 |sed -e 's/^.*keyid://' )
    FILE_KEY_ID[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -text 2>/dev/null | grep -A1 "Subject Key Identifier" | grep -v X509 | sed -e 's/^ *//' )
    FILE_SUBJECT[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -subject 2>/dev/null | sed 's/^subject= //' )
    FILE_ISSUER[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -issuer 2>/dev/null | sed 's/^issuer= //' )
    FILE_FINGERPRINT[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -fingerprint 2>/dev/null)
    FILE_SERIAL[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -serial 2>/dev/null | sed 's/^serial= //' )
    FILE_DATE_START[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -startdate 2>/dev/null | sed 's/^notBefore= //' )
    FILE_DATE_END[$FLC]=$(openssl x509 -in "${FILE}-${TYPE}" -noout -enddate 2>/dev/null | sed 's/^notAfter= //' )
  else
    if [[ "${TYPE}" == "KEY" ]]; then
      FILE_TYPE[$FLC]='KEY'
      # Try guess the key type as there seems to be no other way
      PUB_KEY=$(openssl rsa -in "${FILE}-${TYPE}" -pubout 2>/dev/null)
      if [[ "$?" != "0" ]]; then
        PUB_KEY=$(openssl dsa -in "${FILE}-${TYPE}" -pubout 2>/dev/null)    
        if [[ "$?" != "0" ]]; then
          PUB_KEY=$(openssl ec -in "${FILE}-${TYPE}" -pubout 2>/dev/null)
          if [[ "$?" != "0" ]]; then
            PUB_KEY="-"
          fi
        fi
      fi
      if [[ "$PUB_KEY" != "-" ]]; then
        FILE_PUB_KEY[$FLC]=$(echo "$PUB_KEY" | openssl sha1)
      else 
        FILE_PUB_KEY[$FLC]="-"      
      fi
      FILE_HASH[$FLC]='-'
      FILE_ISSUER_HASH[$FLC]='-'
      FILE_SUBJECT[$FLC]='-'
      KEY_LIST="${KEY_LIST}${FLC} "
    else
      if [[ "${DETAILS}" -ge "2" ]]; then echo "*** Type could not match ... ${FILE}"; fi
      continue
    fi
  fi

  FLC=$((FLC + 1))
done

echo " ... Matching certificates and keys ..."
# Find the child/parent relation between the certificates and match the keys
for (( F = 0; F < $FLC; F++ )); do
  if [[ "${FILE_TYPE[$F]}" == "CERT" ]]; then
    # Check if the certificate is self-signed
    if [[ -z "${FILE_SIG_KEY_ID[$F]}" ]] || [[ "${FILE_SIG_KEY_ID[$F]}" == "${FILE_KEY_ID[$F]}" ]]; then
      FILE_NOTICE[$F]="${RED}Self-Signed${RST}"
      continue
    fi
    for (( CM = 0; CM < $FLC; CM++ )); do
      # find matching issuer certificate
      if [[ "${FILE_SIG_KEY_ID[$F]}" == "${FILE_KEY_ID[$CM]}" ]] && [[ "${FILE_ISSUER_HASH[$F]}" == "${FILE_HASH[$CM]}" ]]; then
        FILE_PARENT[$F]="${FILE_CHILDS[$F]}C$CM "
        if [[ "${FILE_TYPE[$CM]}" == "CERT" ]]; then
          FILE_CHILDS[$CM]="${FILE_CHILDS[$CM]}C$F "
        else 
          FILE_CHILDS[$CM]="${FILE_CHILDS[$CM]}K$F "
        fi
      fi
    done
  fi
  if [[ "${FILE_TYPE[$F]}" == "KEY" ]]; then
    for (( KM = 0; KM < $FLC; KM++ )); do
      if [[ "${FILE_PUB_KEY[$F]}" == "${FILE_PUB_KEY[$KM]}" ]] && [[ "${FILE_TYPE[$KM]}" == "CERT" ]]; then
        KEY_ASSIGNMENT[$KM]=$F;
        FILE_PARENT[$F]="${FILE_PARENT[$F]}C$KM "
        FILE_CHILDS[$KM]="${FILE_CHILDS[$KM]}K$F "
      fi
    done
  fi
  FILE_CHILDS[$F]=$(echo "${FILE_CHILDS[$F]}" | tr  [:space:] '\n' | sort -r | tr '\n' ' ' | sed 's/^ //')
done

# Find the certificate(s) without parent certificate as well as self-signed
for (( i = 0; i < ${FLC}; i++ )); do
  if [[ "${FILE_PARENT[$i]}" == "" ]] && [[ "${FILE_TYPE[$i]}" == "CERT" ]]; then
    ROOT_LIST="${ROOT_LIST} $i"
  fi
done

if [[ "${DETAILS}" -ge "2" ]]; then 
  for (( i = 0; i < ${FLC}; i++ )); do
    echo "*** DBG:  ${YELLOW}$i: ${FILE_LIST[$i]}${RST}"
    echo "*** DBG:               type: ${FILE_TYPE[$i]} ${FILE_NOTICE[$i]}"
    echo "*** DBG:            subject: ${FILE_SUBJECT[$i]}"
    echo "*** DBG:        fingerprint: ${FILE_FINGERPRINT[$i]}"
    echo "*** DBG:             serial: ${FILE_SERIAL[$i]}"
    echo "*** DBG:          notBefore: ${FILE_DATE_START[$i]}"
    echo "*** DBG:           notAfter: ${FILE_DATE_END[$i]}"
    echo "*** DBG:         public-key: ${FILE_PUB_KEY[$i]}"
    echo "*** DBG:               hash: ${FILE_HASH[$i]}"
    echo "*** DBG:             issuer: ${FILE_ISSUER[$i]}"
    echo "*** DBG:        issuer-hash: ${FILE_ISSUER_HASH[$i]}"
    echo "*** DBG:             key-id: ${FILE_KEY_ID[$i]}"
    echo "*** DBG:   signature-key-id: ${FILE_SIG_KEY_ID[$i]}"
    echo "*** DBG:        parent-cert: ${FILE_PARENT[$i]}"
    echo "*** DBG:        child-certs: ${FILE_CHILDS[$i]}"
  done
  echo "*** DBG:  ROOT_LIST: $ROOT_LIST"
fi

#
# Function to print the complete certificate chain
#
function print_certificate_details()
{
  local INTEND="$1"
  local k=$2

  if [[ "${FILE_TYPE[$k]}" == "CERT" ]]; then
    echo "${INTEND}Certificate file          : ${GREEN}${FILE_LIST[$k]}${RST} (internal-id: $k) ${FILE_NOTICE[$k]}"
    echo "${INTEND}Certificate subject       : ${GREEN}${FILE_SUBJECT[$k]}${RST} (hash: ${FILE_HASH[$k]})"
    if [[ "${DETAILS}" -ge "1" ]]; then echo "${INTEND}Certificate serial        : ${FILE_SERIAL[$k]} " ; fi
    if [[ "${DETAILS}" -ge "1" ]]; then echo "${INTEND}Certificate Key Identifier: ${FILE_KEY_ID[$k]}" ; fi
    if [[ "${DETAILS}" -ge "1" ]]; then echo "${INTEND}Certificate Key hash      : ${FILE_PUB_KEY[$k]}" ; fi
    echo "${INTEND}Issuer Subject            : ${FILE_ISSUER[$k]} (issuer hash: ${FILE_ISSUER_HASH[$k]})"
    if [[ "${DETAILS}" -ge "1" ]]; then echo "${INTEND}Issuer Key Identifier     : ${FILE_SIG_KEY_ID[$k]}" ; fi
    if [[ "${DETAILS}" -ge "1" ]]; then echo "${INTEND}Parent item in chain      : ${FILE_PARENT[$k]}" ; fi
    if [[ "${DETAILS}" -ge "1" ]]; then echo "${INTEND}Child item in chain       : ${FILE_CHILDS[$k]}" ; fi
  fi

  if [[ "${FILE_TYPE[$k]}" == "KEY" ]]; then
    echo "${INTEND}Key file                  : ${YELLOW}${FILE_LIST[$k]}${RST} (internal-id: $k)"
    echo "${INTEND}Key hash                  : ${FILE_PUB_KEY[$k]}"
    echo "${INTEND}Parent item in chain      : ${FILE_PARENT[$k]}"
  fi

  echo ""
}

#
# Function to print the complete certificate chain
#
function print_certificates()
{
  local INTEND="$1"
  shift
  local ITEM_LIST=$@

  for k in ${ITEM_LIST}; do
    CHILD_LIST=$(echo "${FILE_CHILDS[$k]}" | tr  [:space:] '\n' | sort -r | tr '\n' ' ' | sed 's/[CK]//g')
      #if [[ "${DETAILS}" -ge "2" ]]; then echo "*** print_certificates - Item List: '${ITEM_LIST}', Item: '$k', Child: '${FILE_CHILDS[$k]}', Child List: ${CHILD_LIST}" ; fi
    print_certificate_details "${INTEND}" "$k"
    print_certificates "${INTEND}    " ${CHILD_LIST}
  done
}

#
# Print the chain for one item by checking the parent relation (also saving the chain)
#
function print_chain_for_item()
{
  local INTEND="$1"
  local ITEM="$2"

  # find the first parent 
  ITEM_PARENT=$(echo "${FILE_PARENT[$ITEM]}" | tr  [:space:] '\n' | sort -r | tr '\n' ' ' | sed -e 's/[CK]//g' -e 's/  / /g' -e 's/ $//')

  # start the chain to display including the key and the certificate
  ITEM_PATH="${ITEM_PARENT} ${ITEM}"

  # start the certificate path for saving the certificate chain into a file
  if [[ "${FILE_TYPE[$ITEM]}" == "CERT" ]]; then
    # if the start item is a certificate, then there is no key available for it
    ITEM_PATH_SAVE="${ITEM_PARENT}"
    ITEM_PATH_SAVE_KEY=$(echo "${FILE_CHILDS[${ITEM}]}" | sed -e 's/[CK]//g' -e 's/ //g')
    ITEM_PATH_SAVE_CERT="${ITEM}"
    ITEM_PATH="${ITEM_PATH} $(echo "${FILE_CHILDS[${ITEM}]}" | sed -e 's/[CK]//g' -e 's/ //g')"
  else
    # if the start item is a key define the key and the first parent as the certificate
    ITEM_PATH_SAVE=""
    ITEM_PATH_SAVE_KEY="${ITEM}"
    ITEM_PATH_SAVE_CERT=$(echo "${ITEM_PARENT}" | sed -e 's/^ *//' -e 's/ .*$//')
  fi

  # get through the parent relationship to find the root element
  ITEM_PARENT=$(echo "${ITEM_PARENT}" | sed -e 's/^ *//' -e 's/ .*$//')
  while [[ ${ITEM_PARENT} != '' ]]; do
    ITEM_PARENT=$(echo "${FILE_PARENT[${ITEM_PARENT}]}" | sed -e 's/[CK]//g' -e 's/ //g')
    ITEM_PATH="${ITEM_PARENT} ${ITEM_PATH}"
    # ignore the root element for the certificate chain
    if [[ ${ITEM_PARENT} != '' ]]; then
      # if there is a parent item, add the item to the chain
      ITEM_PATH_SAVE="${ITEM_PATH_SAVE} ${ITEM_PARENT}"
    fi
  done

  # show the certificate chain
  for i in ${ITEM_PATH}; do
    print_certificate_details "${INTEND}" "$i"
    INTEND="${INTEND}    "
  done

  # save the certificate chain in reverse order and without the root certificate
  if [[ ! -z "${SAVE_CHAIN}" ]]; then
    if [[ "${DETAILS}" -ge "2" ]]; then echo "*** Save-Chain ... Key   ID: ${ITEM_PATH_SAVE_KEY}"; fi
    if [[ "${DETAILS}" -ge "2" ]]; then echo "*** Save-Chain ... Cert  ID: ${ITEM_PATH_SAVE_CERT}"; fi
    if [[ "${DETAILS}" -ge "2" ]]; then echo "*** Save-Chain ... Chain ID: ${ITEM_PATH_SAVE}"; fi
    for j in $ITEM_PATH_SAVE; do
      if [[ "${FILE_NOTICE[$j]}" == "${RED}Self-Signed${RST}" ]]; then
        continue
      fi
      cat "${FILE_LIST[$j]}" >>"${SAVE_CHAIN}/result-$2-chain.pem"
    done
    cat "${FILE_LIST[$ITEM_PATH_SAVE_CERT]}" >"${SAVE_CHAIN}/result-$2-cert.pem"
    cat "${FILE_LIST[$ITEM_PATH_SAVE_KEY]}" >"${SAVE_CHAIN}/result-$2-key.pem"
    echo "Certificate, key and chain are saved to:"
    echo "    ${SAVE_CHAIN}/result-$2-key.pem"
    echo "    ${SAVE_CHAIN}/result-$2-cert.pem"
    echo "    ${SAVE_CHAIN}/result-$2-chain.pem"
  fi
}



# Show the result according to the requested parameters
# 
if [[ -z "${CHAIN_FOR_KEY}" ]]; then
  print_certificates '' ${ROOT_LIST}
else
  echo "========================="
  print_chain_for_item '' "${CHAIN_FOR_KEY}"
  echo "========================="
  echo 
fi


exit 0
