#!/bin/bash

. ../../etc/config
. ../../libs/utils

# Independently compute the expected HMAC-SHA256 of the fixed data string keyed
# with the fixed key value, as a lowercase hex string. This must match the token
# produced by auth_xkeys_add() with the "hmac-sha256" algorithm.
EXPECTED=$(printf '%s' 'teststring' | openssl dgst -sha256 -hmac 'secretkey' -r | awk '{print $1}')
echo "--- expected hmac-sha256 token: ${EXPECTED}"

# Send a single SIP MESSAGE as one UDP datagram (see tauthx0003 for why python3
# is used instead of sipsak / bash /dev/udp).
send_message() {
	python3 - <<'PYEOF'
import socket
msg = (
 "MESSAGE sip:bob@127.0.0.1 SIP/2.0\r\n"
 "Via: SIP/2.0/UDP 127.0.0.1:9999;branch=z9hG4bKtauthx0004\r\n"
 "Max-Forwards: 70\r\n"
 "From: <sip:alice@127.0.0.1>;tag=t1\r\n"
 "To: <sip:bob@127.0.0.1>\r\n"
 "Call-ID: tauthx0004@127.0.0.1\r\n"
 "CSeq: 1 MESSAGE\r\n"
 "Content-Type: text/plain\r\n"
 "Content-Length: 11\r\n"
 "\r\n"
 "hello there"
).encode()
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.sendto(msg, ("127.0.0.1", 5060))
PYEOF
}

echo "--- start kamailio -f ./kamailio-tauthx0004.cfg"
rm -f /tmp/kamailio-tauthx0004.log
rm -f ${KAMPID}
${KAMBIN} -P ${KAMPID} -w . -Y ${KAMRUN} -f ./kamailio-tauthx0004.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tauthx0004.log &
sleep 1
send_message
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
grep "xkeys token=${EXPECTED}" /tmp/kamailio-tauthx0004.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
	echo "--- test failed: produced token does not match expected hmac-sha256"
	exit 1
fi
exit 0
