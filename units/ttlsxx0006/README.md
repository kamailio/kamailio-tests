# TLS SNI Server Domain Selection #

Summary: tls sni - server domain and certificate selection by server_name and server_name_mode

Three `[server:any]` profiles with their own certificates sit next to
`[server:default]` on the same socket:

  * `a.test` with `server_name_mode = 0` (exact name)
  * `b.test` with `server_name_mode = 1` (name and subdomains)
  * `c.test` with `server_name_mode = 2` (subdomains only)

Following tests are done:

  * no SNI gets the default certificate
  * mode 0: `a.test` matches, `x.a.test` falls back to default
  * mode 1: `b.test`, `x.b.test` and `y.x.b.test` match, `xb.test` does not
    (match is on a label boundary)
  * mode 2: `x.c.test` matches, `c.test` falls back to default
  * SNI matching is case-insensitive (`A.TEST`, `X.B.Test`)
  * SIP OPTIONS over a connection with SNI: `$tls_peer_server_name` is the
    SNI sent and `$tls_my_subject_cn` is the CN of the selected certificate

Requires `openssl` and `python3`; uses `libs/tlsprobe.py`.
