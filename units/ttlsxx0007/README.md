# TLS Outbound Server Certificate Verification #

Summary: tls client side - server certificate verification and verify_server_name

Kamailio relays requests over TLS to its own TLS sockets, each serving a
different certificate:

  * 5061 - signed by the test CA, subjectAltName `DNS:sip.test`
  * 5062 - self-signed (rogue), subjectAltName `DNS:sip.test`
  * 5063 - signed by the test CA, subjectAltName `DNS:other.test`

The TLS client profile is selected by `server_id` through `xavp_cfg`:

  * `verify` - verify_certificate, ca_list, server_name `sip.test`,
    verify_server_name
  * `noname` - same, without verify_server_name (server_name
    `noname.sip.test`)
  * `none` - no verification (server_name `none.sip.test`)

Each profile has its own server_name: with `tls_connection_match_domain`
the domain used to match connections is `any:<server_name>`, so profiles
sharing a server_name would share connections.

Following tests are done:

  * `verify`: 5061 succeeds, 5062 (untrusted) and 5063 (wrong name) fail
  * `noname`: 5063 succeeds (only the name check rejected it), 5062 fails
  * `none`: 5062 succeeds (the rogue server itself works)
  * after `none`/`noname` have open connections to 5062/5063, `verify`
    still fails on both, i.e. it does not reuse their connections

Requires `openssl` and `sipsak`.
