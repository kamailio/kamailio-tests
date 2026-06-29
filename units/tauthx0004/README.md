# XKeys Authentication - HMAC Known-Answer Test #

Summary: xkeys authentication - hmac-sha256 token matches an independently computed HMAC

Following tests are done:

  * run kamailio with `kamailio-tauthx0004.cfg`, add an `X-AuthXKeys-Token`
  header with `auth_xkeys_add()` using the `hmac-sha256` algorithm over a fixed
  data string keyed with a fixed key value, forward the request to itself and
  log the produced token

The token logged by kamailio is compared against the HMAC-SHA256 computed
independently with the `openssl` command line tool over the same data and key.
A match proves the `auth_xkeys` HMAC implementation is RFC 2104 compliant (data
keyed with the key value, lowercase hex output) and interoperable with standard
tooling.
