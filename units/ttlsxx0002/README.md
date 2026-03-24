# TLS Dual-Cert Support (RSA + ECDSA) #

Summary: tls dual-cert support - RSA and ECDSA certificate selection

Following tests are done:

  * dual-cert default handshake picks ECDSA
  * dual-cert forced RSA via sigalgs negotiation
  * dual-cert forced ECDSA via sigalgs negotiation
  * SIP OPTIONS over TLS receives a response
  * RSA-only configuration serves RSA cert
  * ECDSA-only configuration serves ECDSA cert
