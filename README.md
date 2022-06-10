# cert-utils
Collection of little helpful scripts around Certificates and SSL/TLS.

## check_certs.sh

Show the certificate details of all certificates returned from a ssl/tls connect (s_client) or from all certificates in a pem file. List of certificates is shown in the order found in the file or returned from the connection. The shown details can be defined by providing openssl x509 options.

The script will check if the provided destination is a file. With a file, it is loaded and listed. Otherwise the script uses the openssl s_client command to connect to the URL and shows the returned  certificates.

There are two options that are passed to the different openssl commands. The "-tls" options allows to specify the tls protocol used while connecting to the URL. The "openssl-options" however are passed to the openssl command parsing the returned certificates. Those options can be used to show additional certificate details if needed.

```
Usage: check_certs.sh [-h|--help] [--tls protocol] <destination|filename> [openssl-options]

Options:
  -h, --help       Print this usage and exit
  -v  --version           Print version information and exit
  --tls protocol   The starttls protocol used by s_client --starttls
                   'smtp', 'pop3', 'imap', 'ldap', ... see all in the s_client(1) man page
  destination      Connect string used by openssl s_client to connect to.
  filename         Filename to read certificates from.
  openssl-options  Openssl x509 options to show required details for the certificates.
                   Default: -subject -issuer -email -dates -fingerprint -noout
```

## check-cert-chain.sh

With this script, a number of certificates and keys can be analysed and related to each other. 

It reads a list of provided PEM formatted files containing keys and certificates. As the PEM format allows multiple certificates and keys to be added into a single file, those are split into separate files. In a second step, the certificated and keys are matching to each other building up a relation tree. This tree of relations is then displayed.

Additionally to just displaying the complete relation of all the keys and certificates, the script also allows to extract the complete chain of a specified item. The specified item is identified by the internal ID shown in the output. If the selected item is specified (using the --chain-for-item argument), the script will identify from that item its parent certificates (and its key if available). The output will then only show the specified item, its parent certificate and the items key. 

The so Isolated chain can be saved to a specified directory in 3 files. Those contain the usual group of certificates and keys. The key-file contains the key of the selected certificate, the cert-file contains the selected certificate and the chain-file contains the intermediate certificate (excluding the actual root certificate).

```
Usage: check-cert-chain.sh [-hv] [--temp-path /path/to/temp/director/] [--chain-for-item ID] [--save-chain DIRECTORY] cert-file1.pem ... cert-fileN.pem
  -h  --help               Print this usage and exit
  -v  --version            Print version information and exit
      --temp-path          Specify a directory where the script can create temporary files
                           This directory will contain the individual parts of PEM files
      --chain-for-item ID  Create the chain for the key (key needs to be provided in the files)
      --save-chain DIR     Save the chain files as key, certificate and chain
                           Save-chain requires --chain-for-item to function
  -d                       Show more details about the certificate chain
  -n  --no-colour          Do not use ANSI colours.
```

### generate-test-certs.sh

The "test" directory contains the openssl configuration file "openssl-ca.cnf" and a script "create_chain.sh" to generate a set of certificates to test the script. It will generate 3 different self signed root certificates each with a chain of two levels of intermediate certificates and 3 leaf certificates as they would be used for web servers. 

Those certificates can be used to test the "check-cert-chain.sh" script. They represent a set of common relations between the certificates. 

* Self signed root certificate
* Multiple intermediate certificates
* Mix of RSA, DSA and EC Certificates and keys
* Multiple certificates with the same key (as seen with certificate renewals)

To clear the test directory after testing, the script provides a "--clean" option.

```
Usage: generate-test-certs.sh [-h] [--clean]
  -h  --help               Print this usage and exit
      --clean              Remove all test files generated
```