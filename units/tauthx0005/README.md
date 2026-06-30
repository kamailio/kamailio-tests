# XKeys Authentication - Tampered HMAC Token Rejected #

Summary: xkeys authentication - tampered hmac-sha256 token is rejected (negative test)

Following tests are done:

  * run kamailio with `kamailio-tauthx0005.cfg`, which verifies an
  `X-AuthXKeys-Token` header with `auth_xkeys_check()` using the `hmac-sha256`
  algorithm over a fixed data string keyed with a fixed key value
  * compute the valid HMAC-SHA256 token independently with the `openssl`
  command line tool, then derive a tampered token by flipping its last hex
  nibble (keeping the correct length)
  * send one request carrying the valid token (positive control) and one
  carrying the tampered token

The test requires that the valid token is accepted exactly once and the
tampered token is rejected exactly once. A token of the correct length but
wrong value exercises the constant-time MAC comparison (`CRYPTO_memcmp`) rather
than the length pre-check, proving that `auth_xkeys_check()` rejects forged
tokens. Requiring a matching positive control in the same run guards against a
regression that would make verification always-pass or always-fail.
