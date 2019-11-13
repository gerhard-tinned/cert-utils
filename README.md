# cert-utils
Collection of little helpful scripts to help manage certificates.

## check_certs.sh
Show the certificate details of all certificates returned from a ssl/tls connect (s_client) or from all certificates in a pem file. List of certificates is shown in the order found in the file or returned from the connection. The shown details can be defined by providing openssl x509 options.
