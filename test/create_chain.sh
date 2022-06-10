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
#

PARAM_CONFIG_CA="-config openssl-ca.cnf"
PARAM_KEY="-nodes -batch"

function usage
{
  echo 
  echo "Usage: `basename $0` [-h] [--clean]"
  echo "  -h  --help               Print this usage and exit"
  echo "      --clean              Remove all test files generated"
  echo 
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
	usage
	exit 0
fi

#
# Cleanup if required
#
if [[ "$1" == "--clean" ]]; then
	rm *.pem *.csr *.srl 
	rm ca-serial* ca-certindex.txt*
	exit
fi


#
# CA preconditions
#
echo '100001' >ca-serial
echo -n >ca-certindex.txt


#
# Create a self signes root certificate including a key (valid 10 years)
#
echo -e "\n#\n# Generate root certificate requests\n#\n"
openssl dsaparam -out param-dsa.pem 2048
openssl ecparam -name prime256v1 -out param-ec.pem
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey rsa:4096          -keyout root-key-rsa.pem $PARAM_KEY -days 3650 -out root-cert-rsa.csr -subj "/C=AT/O=Test Organisation/CN=TestCA root rsa certificate"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey dsa:param-dsa.pem -keyout root-key-dsa.pem $PARAM_KEY -days 3650 -out root-cert-dsa.csr -subj "/C=AT/O=Test Organisation/CN=TestCA root dsa certificate"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey ec:param-ec.pem   -keyout root-key-ec.pem $PARAM_KEY -days 3650 -out root-cert-ec.csr  -subj "/C=AT/O=Test Organisation/CN=TestCA root ec certificate"

echo -e "\n#\n# Sign root certificate requests\n#\n"
openssl ca -selfsign -batch $PARAM_CONFIG_CA -in root-cert-rsa.csr -keyfile root-key-rsa.pem -out root-cert-rsa.pem -extensions v3_ca
openssl ca -selfsign -batch $PARAM_CONFIG_CA -in root-cert-dsa.csr -keyfile root-key-dsa.pem -out root-cert-dsa.pem -extensions v3_ca
openssl ca -selfsign -batch $PARAM_CONFIG_CA -in root-cert-ec.csr  -keyfile root-key-ec.pem  -out root-cert-ec.pem -extensions v3_ca


#
# Create a first Intermediat certificate (8 years)
#

# Create the Certificate Signing Request (CSR)
echo -e "\n#\n# Generate Intermediate A requests\n#\n"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey rsa:4096 		 -keyout intermediateA1-key.pem $PARAM_KEY -out intermediateA1-csr.pem -subj "/C=AT/O=Test Organisation/CN=TestCA intermediate A1 certificate"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey dsa:param-dsa.pem -keyout intermediateA2-key.pem $PARAM_KEY -out intermediateA2-csr.pem -subj "/C=AT/O=Test Organisation/CN=TestCA intermediate A2 certificate"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey ec:param-ec.pem   -keyout intermediateA3-key.pem $PARAM_KEY -out intermediateA3-csr.pem -subj "/C=AT/O=Test Organisation/CN=TestCA intermediate A3 certificate"

# Create the signed certificate from the CSR (8 years)
echo -e "\n#\n# Sign Intermediate A requests\n#\n"
openssl ca -batch $PARAM_CONFIG_CA -cert root-cert-rsa.pem -keyfile root-key-rsa.pem -md sha1 -days 2920 -out intermediateA1-cert.pem -in intermediateA1-csr.pem -extensions v3_ca
openssl ca -batch $PARAM_CONFIG_CA -cert root-cert-dsa.pem -keyfile root-key-dsa.pem -md sha1 -days 2920 -out intermediateA2-cert.pem -in intermediateA2-csr.pem -extensions v3_ca
openssl ca -batch $PARAM_CONFIG_CA -cert root-cert-ec.pem  -keyfile root-key-ec.pem  -md sha1 -days 2920 -out intermediateA3-cert.pem -in intermediateA3-csr.pem -extensions v3_ca


#
# Create a second Intermediat certificate (6 years)
#

# Create the Certificate Signing Request (CSR)
echo -e "\n#\n# Generate Intermediate B requests\n#\n"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey rsa:4096          -keyout intermediateB1-key.pem $PARAM_KEY -out intermediateB1-csr.pem -subj "/C=AT/O=Test Organisation/CN=TestCA intermediate B1 certificate"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey dsa:param-dsa.pem -keyout intermediateB2-key.pem $PARAM_KEY -out intermediateB2-csr.pem -subj "/C=AT/O=Test Organisation/CN=TestCA intermediate B2 certificate"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey ec:param-ec.pem   -keyout intermediateB3-key.pem $PARAM_KEY -out intermediateB3-csr.pem -subj "/C=AT/O=Test Organisation/CN=TestCA intermediate B3 certificate"

# Create the signed certificate from the CSR (6 years)
echo -e "\n#\n# Sign Intermediate B requests\n#\n"
openssl ca -batch $PARAM_CONFIG_CA -cert intermediateA1-cert.pem -keyfile intermediateA1-key.pem -md sha1 -days 2190 -out intermediateB1-cert.pem -in intermediateB1-csr.pem -extensions v3_ca
openssl ca -batch $PARAM_CONFIG_CA -cert intermediateA2-cert.pem -keyfile intermediateA2-key.pem -md sha1 -days 2190 -out intermediateB2-cert.pem -in intermediateB2-csr.pem -extensions v3_ca
openssl ca -batch $PARAM_CONFIG_CA -cert intermediateA3-cert.pem -keyfile intermediateA3-key.pem -md sha1 -days 2190 -out intermediateB3-cert.pem -in intermediateB3-csr.pem -extensions v3_ca


#
# Create an website certificate (2 years) - www.example.com
#

# Create the Certificate Signing Request (CSR)
echo -e "\n#\n# Generate webserver com requests\n#\n"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey rsa:4096 -keyout www_example_com-key.pem $PARAM_KEY -out www_example_com-csr.pem -subj "/C=AT/O=Customer Organisation/CN=www.example.com"

# Create the signed certificate from the CSR (2 years)
echo -e "\n#\n# Sign webserver com requests\n#\n"
openssl ca -batch $PARAM_CONFIG_CA -cert intermediateB3-cert.pem -keyfile intermediateB3-key.pem -md sha1 -days 712 -out www_example_com-cert.pem -in www_example_com-csr.pem -extensions v3_leaf


#
# Create an website certificate (2 years) - sub.example.com
#

# Create the Certificate Signing Request (CSR)
echo -e "\n#\n# Generate webserver com requests\n#\n"
openssl req $PARAM_CONFIG_CA -new -sha256 -key www_example_com-key.pem $PARAM_KEY -out sub_example_com-csr.pem -subj "/C=AT/O=Customer Organisation/CN=sub.example.com"

# Create the signed certificate from the CSR (2 years)
echo -e "\n#\n# Sign webserver com requests\n#\n"
openssl ca -batch $PARAM_CONFIG_CA -cert intermediateB3-cert.pem -keyfile intermediateB3-key.pem -md sha1 -days 712 -out sub_example_com-cert.pem -in sub_example_com-csr.pem -extensions v3_leaf



#
# Create an website certificate (2 years) - www.example.org
#

# Create the Certificate Signing Request (CSR)
echo -e "\n#\n# Generate webserver org requests\n#\n"
openssl req $PARAM_CONFIG_CA -new -sha256 -newkey rsa:4096 -keyout www_example_org-key.pem $PARAM_KEY -out www_example_org-csr.pem -subj "/C=AT/O=Customer Organisation/CN=www.example.org"

# Create the signed certificate from the CSR (2 years)
echo -e "\n#\n# Sign webserver org requests\n#\n"
openssl ca -batch $PARAM_CONFIG_CA -cert intermediateB1-cert.pem -keyfile intermediateB1-key.pem -md sha1 -days 712 -out www_example_org-cert.pem -in www_example_org-csr.pem -extensions v3_leaf


# XXXXX










