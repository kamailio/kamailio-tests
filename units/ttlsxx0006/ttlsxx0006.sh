#!/bin/bash
# variables shared with the sourced etc/config, libs/utils and libs/tlsutils
# shellcheck disable=SC1091,SC2034,SC2154
# TLS SNI: server domain and certificate selection by server_name / server_name_mode

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

UNIT=ttlsxx0006
HOST=127.0.0.1
TLSPORT=5061
WORKDIR="/tmp/${UNIT}"
CFG="kamailio-${UNIT}.cfg"

. ../../libs/tlsutils

# expect_cert SNI EXPECTED_CN
expect_cert() {
	local cn
	cn=$(tls_cert_cn "${TLSPORT}" "$1")
	if [ "${cn}" != "$2" ]; then
		tls_fail "SNI '${1:-<none>}': got certificate '${cn}', expected '$2'"
	fi
}

tls_require_tools
tls_workdir_init

for n in default a b c; do
	tls_mk_selfsigned "${n}" "${n}-cert"
	if [ ! -s "${WORKDIR}/${n}.crt" ]; then
		echo "failed to generate ${n} certificate, not run"
		rm -rf "${WORKDIR}"
		exit 0
	fi
done

cat > "${WORKDIR}/tls.cfg" <<-EOF
[server:default]
method = TLSv1.2+
certificate = ${WORKDIR}/default.crt
private_key = ${WORKDIR}/default.key

[server:any]
method = TLSv1.2+
server_name = a.test
server_name_mode = 0
certificate = ${WORKDIR}/a.crt
private_key = ${WORKDIR}/a.key

[server:any]
method = TLSv1.2+
server_name = b.test
server_name_mode = 1
certificate = ${WORKDIR}/b.crt
private_key = ${WORKDIR}/b.key

[server:any]
method = TLSv1.2+
server_name = c.test
server_name_mode = 2
certificate = ${WORKDIR}/c.crt
private_key = ${WORKDIR}/c.key

[client:default]
verify_certificate = no
EOF

if ! tls_start_kamailio "${WORKDIR}/tls.cfg"; then
	tls_fail "kamailio did not start"
	tls_end_test
fi

echo "--- test 1: no SNI gets the default domain"
expect_cert "" default-cert

echo "--- test 2: server_name_mode 0 (exact)"
expect_cert a.test a-cert
expect_cert x.a.test default-cert

echo "--- test 3: server_name_mode 1 (domain and subdomains)"
expect_cert b.test b-cert
expect_cert x.b.test b-cert
expect_cert y.x.b.test b-cert
expect_cert xb.test default-cert

echo "--- test 4: server_name_mode 2 (subdomains only)"
expect_cert c.test default-cert
expect_cert x.c.test c-cert

echo "--- test 5: SNI match is case-insensitive"
expect_cert A.TEST a-cert
expect_cert X.B.Test b-cert

echo "--- test 6: SNI and selected certificate visible to the config"
for spec in "a.test:a-cert" "sub.b.test:b-cert" "x.c.test:c-cert" "none.test:default-cert"; do
	sni="${spec%%:*}"
	want="${spec#*:}"
	got=$(tls_probe options "${HOST}" "${TLSPORT}" --sni "${sni}" --header X-SNI)
	[ "${got}" = "${sni}" ] \
		|| tls_fail "SNI '${sni}': \$tls_peer_server_name is '${got}'"
	got=$(tls_probe options "${HOST}" "${TLSPORT}" --sni "${sni}" --header X-My-CN)
	[ "${got}" = "${want}" ] \
		|| tls_fail "SNI '${sni}': \$tls_my_subject_cn is '${got}', expected '${want}'"
done

echo "--- test 7: server still running"
tls_kamailio_alive || tls_fail "kamailio stopped or a child died"

tls_end_test
