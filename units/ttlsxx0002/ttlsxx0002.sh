#!/bin/bash
# check tls module dual-cert support (RSA + ECDSA)

# Copyright (C) 2026 Aurora Innovation
# Author: Daniel Donoghue
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

TLSPORT=5061
CERT_DIR="/tmp/ttlsxx0002-certs"
CFG="kamailio-ttlsxx0002.cfg"
ret=0

# check openssl is available
if ! (which openssl > /dev/null 2>&1); then
	echo "openssl not found, not run"
	exit 0
fi

# --- generate self-signed certs ---
mkdir -p "$CERT_DIR"
openssl req -x509 -newkey rsa:2048 -nodes \
	-keyout "$CERT_DIR/rsa.key" -out "$CERT_DIR/rsa.crt" \
	-days 1 -subj "/CN=kamailio-test-rsa/O=Test" 2>/dev/null
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
	-keyout "$CERT_DIR/ecdsa.key" -out "$CERT_DIR/ecdsa.crt" \
	-days 1 -subj "/CN=kamailio-test-ecdsa/O=Test" 2>/dev/null

# --- generate tls config files from template ---
gen_tls_cfg() {
	local outfile="$1"
	shift
	cat > "$outfile" <<-TLSCFG
	[server:default]
	method = TLSv1.2+
	verify_certificate = no
	require_certificate = no
	TLSCFG
	for line in "$@"; do
		echo "$line" >> "$outfile"
	done
	cat >> "$outfile" <<-TLSCFG

	[client:default]
	verify_certificate = no
	require_certificate = no
	TLSCFG
}

gen_tls_cfg "$CERT_DIR/tls-dual.cfg" \
	"certificate = $CERT_DIR/rsa.crt" \
	"private_key = $CERT_DIR/rsa.key" \
	"certificate2 = $CERT_DIR/ecdsa.crt" \
	"private_key2 = $CERT_DIR/ecdsa.key"

gen_tls_cfg "$CERT_DIR/tls-rsa.cfg" \
	"certificate = $CERT_DIR/rsa.crt" \
	"private_key = $CERT_DIR/rsa.key"

gen_tls_cfg "$CERT_DIR/tls-ecdsa.cfg" \
	"certificate = $CERT_DIR/ecdsa.crt" \
	"private_key = $CERT_DIR/ecdsa.key"

# --- helper: check which cert the server presents ---
check_cert_cn() {
	local expected_cn="$1"
	shift
	local subject
	subject=$(openssl s_client -connect 127.0.0.1:$TLSPORT "$@" </dev/null 2>&1 \
		| grep '^subject=' | head -1)
	if echo "$subject" | grep -q "$expected_cn"; then
		return 0
	fi
	echo "expected CN containing '$expected_cn', got: ${subject:-(empty)}"
	return 1
}

# --- helper: send SIP OPTIONS over TLS ---
check_sip_options() {
	local callid
	callid="test-$(date +%s)-$$@tls"
	local branch
	branch="z9hG4bK-$(date +%s)-$$"
	local msg="OPTIONS sip:127.0.0.1:${TLSPORT} SIP/2.0\r\nVia: SIP/2.0/TLS 127.0.0.1:15060;branch=${branch};rport\r\nMax-Forwards: 70\r\nFrom: <sip:tester@test.local>;tag=test-$$\r\nTo: <sip:127.0.0.1:${TLSPORT}>\r\nCall-ID: ${callid}\r\nCSeq: 1 OPTIONS\r\nContent-Length: 0\r\n\r\n"
	local response
	response=$(echo -ne "$msg" | timeout 5 openssl s_client -connect 127.0.0.1:$TLSPORT -quiet 2>/dev/null) || true
	if echo "$response" | grep -q "^SIP/2.0 [2-4]"; then
		return 0
	fi
	echo "no SIP response to OPTIONS"
	return 1
}

# --- helper: start kamailio with a given tls config ---
start_with_tls() {
	local tls_cfg="$1"
	local run_cfg="/tmp/ttlsxx0002-kamailio.cfg"
	sed "s|__TLS_CFG__|${tls_cfg}|g" "$CFG" > "$run_cfg"
	${KAMBIN} -P "${KAMPID}" -w "${KAMRUN}" -Y "${KAMRUN}" -a no -f "$run_cfg" &> /dev/null
	local rc=$?
	sleep 1
	return $rc
}

# ============================================================
# Test 1: Dual-cert — default handshake picks ECDSA
# ============================================================
echo
echo "--- test 1: dual-cert default handshake picks ECDSA"
if start_with_tls "$CERT_DIR/tls-dual.cfg"; then
	if ! check_cert_cn "kamailio-test-ecdsa"; then
		echo "FAIL: dual-cert default should pick ECDSA"
		ret=1
	fi
else
	echo "FAIL: kamailio did not start (dual-cert)"
	ret=1
fi

# ============================================================
# Test 2: Dual-cert — force RSA via sigalgs
# ============================================================
if [ "$ret" -eq 0 ]; then
	echo "--- test 2: dual-cert force RSA via sigalgs"
	if ! check_cert_cn "kamailio-test-rsa" -sigalgs RSA-PSS+SHA256:RSA+SHA256; then
		echo "FAIL: dual-cert forced RSA should serve RSA cert"
		ret=1
	fi
fi

# ============================================================
# Test 3: Dual-cert — force ECDSA via sigalgs
# ============================================================
if [ "$ret" -eq 0 ]; then
	echo "--- test 3: dual-cert force ECDSA via sigalgs"
	if ! check_cert_cn "kamailio-test-ecdsa" -sigalgs ECDSA+SHA256; then
		echo "FAIL: dual-cert forced ECDSA should serve ECDSA cert"
		ret=1
	fi
fi

# ============================================================
# Test 4: Dual-cert — SIP OPTIONS over TLS gets response
# ============================================================
if [ "$ret" -eq 0 ]; then
	echo "--- test 4: SIP OPTIONS over TLS"
	if ! check_sip_options; then
		echo "FAIL: SIP OPTIONS over TLS did not get a response"
		ret=1
	fi
fi

kill_pidfile "${KAMPID}" 2>/dev/null
sleep 1

# ============================================================
# Test 5: RSA-only — serves RSA cert
# ============================================================
if [ "$ret" -eq 0 ]; then
	echo "--- test 5: RSA-only serves RSA cert"
	if start_with_tls "$CERT_DIR/tls-rsa.cfg"; then
		if ! check_cert_cn "kamailio-test-rsa"; then
			echo "FAIL: RSA-only should serve RSA cert"
			ret=1
		fi
	else
		echo "FAIL: kamailio did not start (RSA-only)"
		ret=1
	fi
	kill_pidfile "${KAMPID}" 2>/dev/null
	sleep 1
fi

# ============================================================
# Test 6: ECDSA-only — serves ECDSA cert
# ============================================================
if [ "$ret" -eq 0 ]; then
	echo "--- test 6: ECDSA-only serves ECDSA cert"
	if start_with_tls "$CERT_DIR/tls-ecdsa.cfg"; then
		if ! check_cert_cn "kamailio-test-ecdsa"; then
			echo "FAIL: ECDSA-only should serve ECDSA cert"
			ret=1
		fi
	else
		echo "FAIL: kamailio did not start (ECDSA-only)"
		ret=1
	fi
	kill_pidfile "${KAMPID}" 2>/dev/null
fi

# --- cleanup ---
rm -rf "$CERT_DIR"
rm -f /tmp/ttlsxx0002-kamailio.cfg
exit $ret
