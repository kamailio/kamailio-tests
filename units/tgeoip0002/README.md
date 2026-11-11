# Geoip2 Module - Lookups With Generated Test Database #

Summary: geoip2 module - lookups, containers and distance on a generated database

Unlike `tgeoip0001`, this unit does not need the GeoLite2 database: it
builds a small database with fixed records using `libs/mkmmdb.py`
(documentation address ranges only), so it runs in the default images.

Records in the test database:

  * `192.0.2.0/24` - RO, Bucharest, full city record
  * `198.51.100.0/25` - US, San Francisco, with metro code
  * `198.51.100.128/25` - only `registered_country` JP, no location
  * `2001:db8:1::/48` - DE, Berlin
  * everything else (e.g. `203.0.113.0/24`) - no entry

Following tests are done:

  * all `$gip2(pvc=>key)` keys for a full IPv4 record and an IPv6 record
  * `cc` falls back to `registered_country`, missing keys are `<null>`
  * `regn` (read on its own)
  * `nmask` for an IPv6 record
  * no match for an address without entry, a private address, an invalid
    string and an empty string
  * `geoip2_match("$si", ...)` for the local sender has no entry
  * two containers in the same request keep their own results
  * a container reused for a shorter address gets the new result
  * `geoip2_distance()` result, and -2 for no entry and no location

Requires `python3` and `sipsak`.
