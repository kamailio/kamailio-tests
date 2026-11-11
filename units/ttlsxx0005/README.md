# TLS Client Certificate Verification (mutual TLS) #

Summary: tls client certificate verification - verify_client on, optional and optional_no_ca

A private test CA signs the server certificate and a client certificate.
A second, self-signed client certificate with the same subject plays the
rogue client. Each verify_client mode has its own listen port.

Following tests are done:

  * `verify_client = on` (port 5061)
    * no client certificate is rejected
    * rogue self-signed certificate is rejected
    * certificate signed by the CA is accepted, `$tls_peer_verified` is 1
      and `$tls_peer_subject_cn` / `$tls_peer_issuer_cn` are correct
  * `verify_client = optional` (port 5062)
    * no client certificate is accepted, `$tls_peer_verified` is 0
    * rogue certificate is rejected
    * CA-signed certificate is accepted and verified
  * `verify_client = optional_no_ca` (port 5063)
    * rogue certificate is accepted but `$tls_peer_verified` is 0
    * CA-signed certificate is accepted and verified

Requires `openssl` and `python3`; uses `libs/tlsprobe.py`.
