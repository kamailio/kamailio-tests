#!/bin/bash

. ../../etc/config
. ../../libs/utils

# Compute the valid HMAC-SHA256 of the fixed data string keyed with the fixed
# key value (same value as configured in kamailio-tauthx0005.cfg), as a
# lowercase hex string. This is what auth_xkeys_check() computes internally.
GOOD=$(printf '%s' 'teststring' | openssl dgst -sha256 -hmac 'secretkey' -r | awk '{print $1}')

# Tamper: flip the last hex nibble. The token keeps the correct length (64 hex
# chars) but is no longer the valid MAC, so the rejection exercises the
# constant-time MAC comparison rather than the length pre-check.
last="${GOOD: -1}"
if [ "${last}" = "0" ] ; then
	repl="1"
else
	repl="0"
fi
TAMPERED="${GOOD:0:63}${repl}"

echo "--- valid token:    ${GOOD}"
echo "--- tampered token: ${TAMPERED}"

# Send a single SIP MESSAGE as one UDP datagram (see tauthx0003 for why python3
# is used instead of sipsak / bash /dev/udp). The token and a per-request tag
# are passed through the environment.
send_message() {
	AUTHX_TOKEN="$1" AUTHX_TAG="$2" python3 - <<'PYEOF'
import os, socket
token = os.environ["AUTHX_TOKEN"]
tag = os.environ["AUTHX_TAG"]
msg = (
 "MESSAGE sip:bob@127.0.0.1 SIP/2.0\r\n"
 "Via: SIP/2.0/UDP 127.0.0.1:9999;branch=z9hG4bKtauthx0005" + tag + "\r\n"
 "Max-Forwards: 70\r\n"
 "From: <sip:alice@127.0.0.1>;tag=t1\r\n"
 "To: <sip:bob@127.0.0.1>\r\n"
 "Call-ID: tauthx0005-" + tag + "@127.0.0.1\r\n"
 "CSeq: 1 MESSAGE\r\n"
 "X-AuthXKeys-Token: " + token + "\r\n"
 "Content-Type: text/plain\r\n"
 "Content-Length: 11\r\n"
 "\r\n"
 "hello there"
).encode()
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.sendto(msg, ("127.0.0.1", 5060))
PYEOF
}

echo "--- start kamailio -f ./kamailio-tauthx0005.cfg"
rm -f /tmp/kamailio-tauthx0005.log
rm -f ${KAMPID}
${KAMBIN} -P ${KAMPID} -w . -Y ${KAMRUN} -f ./kamailio-tauthx0005.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tauthx0005.log &
sleep 1
send_message "${GOOD}" "good"
sleep 1
send_message "${TAMPERED}" "bad"
sleep 1
kill_pidfile ${KAMPID}
sleep 1

echo
echo "--- grep output"
echo

# The valid token (positive control) must be accepted exactly once, and the
# tampered token must be rejected exactly once. Requiring both guards against a
# regression that makes auth_xkeys_check() always-pass or always-fail.
pass_count=$(grep -c "AUTHX check result: PASS" /tmp/kamailio-tauthx0005.log)
fail_count=$(grep -c "AUTHX check result: FAIL" /tmp/kamailio-tauthx0005.log)
echo "--- PASS results: ${pass_count}, FAIL results: ${fail_count}"

if [ "${pass_count}" -ne 1 ] || [ "${fail_count}" -ne 1 ] ; then
	echo "--- test failed: expected exactly 1 PASS (valid token) and 1 FAIL (tampered token)"
	exit 1
fi

exit 0
