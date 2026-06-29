#!/bin/bash

. ../../etc/config
. ../../libs/utils

# Send a single SIP MESSAGE as one UDP datagram. sipsak in the test image
# segfaults with this kind of request, and bash's /dev/udp fragments the
# message line-by-line, so use python3 (always present in the image) which
# emits the whole request in exactly one datagram.
send_message() {
	python3 - <<'PYEOF'
import socket
msg = (
 "MESSAGE sip:bob@127.0.0.1 SIP/2.0\r\n"
 "Via: SIP/2.0/UDP 127.0.0.1:9999;branch=z9hG4bKtauthx0003\r\n"
 "Max-Forwards: 70\r\n"
 "From: <sip:alice@127.0.0.1>;tag=t1\r\n"
 "To: <sip:bob@127.0.0.1>\r\n"
 "Call-ID: tauthx0003@127.0.0.1\r\n"
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

ALGS="hmac-sha256 hmac-sha384 hmac-sha512"

for alg in ${ALGS} ; do
	echo "--- start kamailio -f ./kamailio-tauthx0003.cfg (AUTHX_ALG=${alg})"
	rm -f /tmp/kamailio-tauthx0003.log
	rm -f ${KAMPID}
	AUTHX_ALG=${alg} ${KAMBIN} -P ${KAMPID} -w . -Y ${KAMRUN} -f ./kamailio-tauthx0003.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tauthx0003.log &
	sleep 1
	send_message
	sleep 1
	kill_pidfile ${KAMPID}
	sleep 1
	echo
	echo "--- grep output for ${alg}"
	echo
	grep "auth xkeys ${alg} ok" /tmp/kamailio-tauthx0003.log
	ret=$?
	if [ ! "$ret" -eq 0 ] ; then
		echo "--- test failed for ${alg}"
		exit 1
	fi
done

exit 0
