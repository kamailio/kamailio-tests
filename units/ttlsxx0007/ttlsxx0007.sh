#!/bin/bash
# variables shared with the sourced etc/config, libs/utils and libs/tlsutils
# shellcheck disable=SC1091,SC2034,SC2154
# TLS client side: server certificate verification and verify_server_name

# Copyright (C) 2026 Kamailio project contributors
#
# This file is part of Kamailio, a free SIP server.
#
# Kamailio is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version
#
# Kamailio is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

. ../../etc/config
. ../../libs/utils

UNIT=ttlsxx0007
HOST=127.0.0.1
WORKDIR="/tmp/${UNIT}"
CFG="kamailio-${UNIT}.cfg"

. ../../libs/tlsutils

# relay_status PROFILE PORT - print the final status code sipsak received
relay_status() {
	sipsak -H localhost -s "sip:${HOST}:5060" -v \
		--headers "X-Profile: $1\nX-Port: $2\n" 2>&1 \
		| awk '/^SIP\/2.0 [0-9][0-9][0-9]/{ code=$2 } END { print code }'
}

# expect PROFILE PORT ok|fail DESC
expect() {
	local code
	code=$(relay_status "$1" "$2")
	case "$3" in
		ok)
			[ "${code}" = "200" ] \
				|| tls_fail "$4: got '${code}', expected 200" ;;
		fail)
			if [ -z "${code}" ] || [ "${code}" = "200" ]; then
				tls_fail "$4: got '${code:-no reply}', expected an error reply"
			fi ;;
	esac
}

tls_require_tools sipsak
tls_workdir_init

tls_mk_ca testca
tls_mk_cert good sip.test testca "DNS:sip.test"
tls_mk_selfsigned rogue sip.test "DNS:sip.test"
tls_mk_cert wrongname other.test testca "DNS:other.test"

for f in testca good rogue wrongname; do
	if [ ! -s "${WORKDIR}/${f}.crt" ]; then
		echo "failed to generate ${f} certificate, not run"
		rm -rf "${WORKDIR}"
		exit 0
	fi
done

cat > "${WORKDIR}/tls.cfg" <<-EOF
[server:default]
certificate = ${WORKDIR}/good.crt
private_key = ${WORKDIR}/good.key

[server:${HOST}:5061]
certificate = ${WORKDIR}/good.crt
private_key = ${WORKDIR}/good.key

[server:${HOST}:5062]
certificate = ${WORKDIR}/rogue.crt
private_key = ${WORKDIR}/rogue.key

[server:${HOST}:5063]
certificate = ${WORKDIR}/wrongname.crt
private_key = ${WORKDIR}/wrongname.key

[client:default]
verify_certificate = no

[client:any]
server_id = verify
server_name = sip.test
verify_certificate = yes
verify_server_name = yes
ca_list = ${WORKDIR}/testca.crt

[client:any]
server_id = noname
server_name = noname.sip.test
verify_certificate = yes
ca_list = ${WORKDIR}/testca.crt

[client:any]
server_id = none
server_name = none.sip.test
verify_certificate = no
EOF

if ! tls_start_kamailio "${WORKDIR}/tls.cfg"; then
	tls_fail "kamailio did not start"
	tls_end_test
fi

echo "--- test 1: verify + verify_server_name"
expect verify 5061 ok   "trusted CA, matching name"
expect verify 5062 fail "untrusted self-signed server"
expect verify 5063 fail "trusted CA, wrong name"

echo "--- test 2: verify without verify_server_name"
expect noname 5063 ok   "trusted CA, wrong name, no name check"
expect noname 5062 fail "untrusted self-signed server"

echo "--- test 3: no verification"
expect none 5062 ok     "untrusted self-signed server, no verification"

echo "--- test 4: connections of other profiles are not reused"
# the 'none' and 'noname' profiles now have connections open to 5062 and
# 5063; with tls_connection_match_domain=yes the 'verify' profile must open
# its own connection and verify it, not reuse those
expect verify 5062 fail "untrusted server after an unverified connection"
expect verify 5063 fail "wrong name after a connection without name check"
expect verify 5061 ok   "trusted CA, matching name, after other profiles"

echo "--- test 5: server still running"
tls_kamailio_alive || tls_fail "kamailio stopped or a child died"

tls_end_test
