#!/bin/bash

. ../../etc/config
. ../../libs/utils

ALGS="hmac-sha256 hmac-sha384 hmac-sha512"

for alg in ${ALGS} ; do
	echo "--- start kamailio -f ./kamailio-tauthx0003.cfg (AUTHX_ALG=${alg})"
	rm -f /tmp/kamailio-tauthx0003.log
	rm -f ${KAMPID}
	AUTHX_ALG=${alg} ${KAMBIN} -P ${KAMPID} -w . -Y ${KAMRUN} -f ./kamailio-tauthx0003.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tauthx0003.log &
	sleep 1
	sipsak -H 127.0.0.1 -c sip:alice@127.0.0.1 -s sip:bob@127.0.0.1 -B "hello there"
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
