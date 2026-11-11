#!/bin/bash
# variables shared with the sourced etc/config, libs/utils and libs/tlsutils
# shellcheck disable=SC1091,SC2034,SC2154
# TLS client certificate verification: verify_client on / optional / optional_no_ca

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

UNIT=ttlsxx0005
HOST=127.0.0.1
WORKDIR="/tmp/${UNIT}"
CFG="kamailio-${UNIT}.cfg"

. ../../libs/tlsutils

PORT_ON=5061
PORT_OPT=5062
PORT_NOCA=5063

# expect_reject PORT DESC [probe options] - handshake or request must fail
expect_reject() {
	local port="$1" desc="$2"
	shift 2
	if tls_probe options "${HOST}" "${port}" "$@" > /dev/null; then
		tls_fail "${desc}: accepted, expected rejection"
	fi
}

# expect_accept PORT DESC VERIFIED [probe options] - must get 200 and
# X-Peer-Verified must be VERIFIED
expect_accept() {
	local port="$1" desc="$2" verified="$3" out
	shift 3
	if ! out=$(tls_probe options "${HOST}" "${port}" --header X-Peer-Verified "$@"); then
		tls_fail "${desc}: rejected, expected 200 (${out})"
		return
	fi
	if [ "${out}" != "${verified}" ]; then
		tls_fail "${desc}: \$tls_peer_verified is '${out}', expected '${verified}'"
	fi
}

tls_require_tools
tls_workdir_init

tls_mk_ca testca
tls_mk_cert server "kamailio-${UNIT}" testca "IP:127.0.0.1"
tls_mk_cert alice alice.test testca
tls_mk_selfsigned rogue alice.test

for f in testca server alice rogue; do
	if [ ! -s "${WORKDIR}/${f}.crt" ]; then
		echo "failed to generate ${f} certificate, not run"
		rm -rf "${WORKDIR}"
		exit 0
	fi
done

GOOD=(--cert "${WORKDIR}/alice.crt" --key "${WORKDIR}/alice.key")
ROGUE=(--cert "${WORKDIR}/rogue.crt" --key "${WORKDIR}/rogue.key")

{
	for spec in "${PORT_ON}:on" "${PORT_OPT}:optional" "${PORT_NOCA}:optional_no_ca"; do
		echo "[server:${HOST}:${spec%%:*}]"
		echo "method = TLSv1.2+"
		echo "certificate = ${WORKDIR}/server.crt"
		echo "private_key = ${WORKDIR}/server.key"
		echo "ca_list = ${WORKDIR}/testca.crt"
		echo "verify_client = ${spec#*:}"
		echo
	done
	echo "[server:default]"
	echo "certificate = ${WORKDIR}/server.crt"
	echo "private_key = ${WORKDIR}/server.key"
	echo
	echo "[client:default]"
	echo "verify_certificate = no"
} > "${WORKDIR}/tls.cfg"

if ! tls_start_kamailio "${WORKDIR}/tls.cfg"; then
	tls_fail "kamailio did not start"
	tls_end_test
fi

echo "--- test 1: verify_client = on"
expect_reject "${PORT_ON}" "on, no client cert"
expect_reject "${PORT_ON}" "on, rogue self-signed cert" "${ROGUE[@]}"
expect_accept "${PORT_ON}" "on, CA-signed cert" 1 "${GOOD[@]}"

CN=$(tls_probe options "${HOST}" "${PORT_ON}" "${GOOD[@]}" --header X-Peer-CN)
[ "${CN}" = "alice.test" ] || tls_fail "\$tls_peer_subject_cn is '${CN}', expected 'alice.test'"
ICN=$(tls_probe options "${HOST}" "${PORT_ON}" "${GOOD[@]}" --header X-Peer-Issuer-CN)
[ "${ICN}" = "testca" ] || tls_fail "\$tls_peer_issuer_cn is '${ICN}', expected 'testca'"

echo "--- test 2: verify_client = optional"
expect_accept "${PORT_OPT}" "optional, no client cert" 0
expect_reject "${PORT_OPT}" "optional, rogue self-signed cert" "${ROGUE[@]}"
expect_accept "${PORT_OPT}" "optional, CA-signed cert" 1 "${GOOD[@]}"

echo "--- test 3: verify_client = optional_no_ca"
expect_accept "${PORT_NOCA}" "optional_no_ca, rogue self-signed cert" 0 "${ROGUE[@]}"
expect_accept "${PORT_NOCA}" "optional_no_ca, CA-signed cert" 1 "${GOOD[@]}"

echo "--- test 4: server still running"
tls_kamailio_alive || tls_fail "kamailio stopped or a child died"

tls_end_test
