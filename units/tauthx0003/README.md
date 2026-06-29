# XKeys Authentication - HMAC Algorithms (KEMI Lua) #

Summary: xkeys authentication - hmac-sha256/384/512 round-trip using kemi lua script

Following tests are done:

  * run kamailio with `kamailio-tauthx0003.cfg` and do xkeys authentication
  using a KEMI Lua script, exercising the HMAC algorithms added to the
  `auth_xkeys` module

Each of the algorithms `hmac-sha256`, `hmac-sha384` and `hmac-sha512` is tested
in turn (selected via the `AUTHX_ALG` environment variable). For every algorithm
the script first adds an `X-AuthXKeys-Token` header with `auth_xkeys_add()` and
forwards the request to itself, then validates the token with
`auth_xkeys_check()`. A successful round-trip logs `auth xkeys <alg> ok`.
