# TLS Robustness - Malformed, Aborted And Fragmented Input #

Summary: tls robustness - survive malformed/aborted handshakes, fragmented and pipelined SIP

A crashed TCP/TLS worker makes the main process shut down the whole
server, so after every step the unit checks that Kamailio is still running,
that no child died by a signal, and that a SIP OPTIONS over TLS still gets a
200 reply.

Following tests are done:

  * TCP connect and close without sending anything
  * plaintext SIP sent to the TLS port
  * random non-TLS bytes and a bogus TLS record header
  * truncated ClientHello at several lengths
  * ClientHello with a 255-byte SNI and an SNI that does not match any domain
  * many concurrent full handshakes, idle connects and half handshakes
  * SIP OPTIONS split over many small TLS records
  * several SIP OPTIONS pipelined in one TLS write

Requires `openssl` and `python3`; uses `libs/tlsprobe.py`.
