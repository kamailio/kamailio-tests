#!/bin/bash
# variables shared with the sourced etc/config, libs/utils and libs/tlsutils
# shellcheck disable=SC1091,SC2034,SC2154
# TLS robustness: malformed, aborted, fragmented and pipelined input

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

UNIT=ttlsxx0004
HOST=127.0.0.1
TLSPORT=5061
WORKDIR="/tmp/${UNIT}"
CFG="kamailio-${UNIT}.cfg"

. ../../libs/tlsutils

fail() { tls_fail "$@"; }
end_test() { tls_end_test; }

# kamailio alive and a TLS OPTIONS still gets a 200 reply
check_alive() {
	local step="$1"
	sleep 0.3
	if ! tls_kamailio_alive; then
		fail "kamailio stopped or a child died after: ${step}"
		end_test
	fi
	if ! tls_probe options "${HOST}" "${TLSPORT}" > /dev/null; then
		fail "no 200 reply to OPTIONS over TLS after: ${step}"
	fi
}

tls_require_tools
tls_workdir_init
tls_mk_selfsigned srv "kamailio-${UNIT}"

cat > "${WORKDIR}/tls.cfg" <<-EOF
[server:default]
method = TLSv1.2+
certificate = ${WORKDIR}/srv.crt
private_key = ${WORKDIR}/srv.key
verify_certificate = no
require_certificate = no

[client:default]
verify_certificate = no
require_certificate = no
EOF

if ! tls_start_kamailio "${WORKDIR}/tls.cfg"; then
	fail "kamailio did not start"
	end_test
fi

echo "--- test 0: baseline OPTIONS over TLS"
check_alive "startup"
[ "${ret}" -ne 0 ] && end_test

echo "--- test 1: TCP connect and close without data"
for _ in $(seq 1 20); do
	tls_probe raw "${HOST}" "${TLSPORT}" ""
done
check_alive "empty connections"

echo "--- test 2: plaintext SIP to the TLS port"
tls_probe raw "${HOST}" "${TLSPORT}" \
	'OPTIONS sip:127.0.0.1 SIP/2.0\r\nVia: SIP/2.0/TCP 127.0.0.1:1;branch=z9hG4bKx\r\nFrom: <sip:a@b>;tag=1\r\nTo: <sip:c@d>\r\nCall-ID: x\r\nCSeq: 1 OPTIONS\r\nContent-Length: 0\r\n\r\n'
check_alive "plaintext SIP"

echo "--- test 3: non-TLS garbage and bogus record headers"
tls_probe raw "${HOST}" "${TLSPORT}" "$(head -c 512 /dev/urandom | od -An -tx1 | tr -d ' \n' | sed 's/../\\x&/g')"
# handshake record, TLS 1.2, length 0xffff, no body
tls_probe raw "${HOST}" "${TLSPORT}" '\x16\x03\x03\xff\xff'
# handshake record with length 0
tls_probe raw "${HOST}" "${TLSPORT}" '\x16\x03\x01\x00\x00'
# alert record before any handshake
tls_probe raw "${HOST}" "${TLSPORT}" '\x15\x03\x03\x00\x02\x02\x28'
# application data before any handshake
tls_probe raw "${HOST}" "${TLSPORT}" '\x17\x03\x03\x00\x05hello'
check_alive "garbage records"

echo "--- test 4: truncated ClientHello"
for n in 1 5 6 9 40 100 200; do
	tls_probe partialhello "${HOST}" "${TLSPORT}" "${n}" --sni truncated.test
done
check_alive "truncated ClientHello"

echo "--- test 5: long, unknown and malformed SNI"
# 253 bytes, the longest valid DNS name
LONGSNI="$(printf 'a%.0s' $(seq 1 63)).$(printf 'b%.0s' $(seq 1 63)).$(printf 'c%.0s' $(seq 1 63)).$(printf 'd%.0s' $(seq 1 56)).test"
if [ ${#LONGSNI} -ne 253 ]; then
	fail "internal: long SNI is ${#LONGSNI} bytes, not 253"
fi
if ! tls_probe options "${HOST}" "${TLSPORT}" --sni "${LONGSNI}" > /dev/null; then
	fail "OPTIONS with a 253-byte SNI was not answered"
fi
if ! tls_probe options "${HOST}" "${TLSPORT}" --sni unknown.example.invalid > /dev/null; then
	fail "OPTIONS with an unknown SNI was not answered by the default domain"
fi
# hand-built ClientHellos with SNI values normal clients refuse to send
tls_probe rawhello "${HOST}" "${TLSPORT}" --sni ""
tls_probe rawhello "${HOST}" "${TLSPORT}" --sni a --sni-len 300
tls_probe rawhello "${HOST}" "${TLSPORT}" --sni a --sni-len 16000
tls_probe rawhello "${HOST}" "${TLSPORT}" --sni 'a\x00b.test'
tls_probe rawhello "${HOST}" "${TLSPORT}" --sni '%s%n%s.test'
tls_probe rawhello "${HOST}" "${TLSPORT}" --sni x.test --list-delta 5
tls_probe rawhello "${HOST}" "${TLSPORT}" --sni x.test --list-delta -2
tls_probe rawhello "${HOST}" "${TLSPORT}" --sni x.test --name-delta 4
tls_probe rawhello "${HOST}" "${TLSPORT}" --sni x.test --name-delta -3
check_alive "long/unknown/malformed SNI"

echo "--- test 6: concurrent handshakes, idle connects and half handshakes"
if ! tls_probe flood "${HOST}" "${TLSPORT}" 50 --mode handshake; then
	fail "concurrent full handshakes failed"
fi
tls_probe flood "${HOST}" "${TLSPORT}" 50 --mode idle
tls_probe flood "${HOST}" "${TLSPORT}" 50 --mode half
check_alive "connection flood"

echo "--- test 7: OPTIONS split over small TLS records"
for frag in 1 7 64; do
	if ! tls_probe options "${HOST}" "${TLSPORT}" --frag "${frag}" --delay 2 > /dev/null; then
		fail "fragmented OPTIONS (${frag}-byte records) not answered"
	fi
done
check_alive "fragmented SIP"

echo "--- test 8: pipelined OPTIONS in one TLS write"
if ! tls_probe options "${HOST}" "${TLSPORT}" --pipeline 10 > /dev/null; then
	fail "not all of 10 pipelined OPTIONS were answered"
fi
check_alive "pipelined SIP"

end_test
