#!/bin/bash

. ../../etc/config
. ../../libs/utils

# Independently compute the expected HMAC-SHA256 of the fixed data string keyed
# with the fixed key value, as a lowercase hex string. This must match the token
# produced by auth_xkeys_add() with the "hmac-sha256" algorithm.
EXPECTED=$(printf '%s' 'teststring' | openssl dgst -sha256 -hmac 'secretkey' -r | awk '{print $1}')
echo "--- expected hmac-sha256 token: ${EXPECTED}"

echo "--- start kamailio -f ./kamailio-tauthx0004.cfg"
rm -f /tmp/kamailio-tauthx0004.log
rm -f ${KAMPID}
${KAMBIN} -P ${KAMPID} -w . -Y ${KAMRUN} -f ./kamailio-tauthx0004.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tauthx0004.log &
sleep 1
sipsak -H 127.0.0.1 -c sip:alice@127.0.0.1 -s sip:bob@127.0.0.1 -B "hello there"
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
