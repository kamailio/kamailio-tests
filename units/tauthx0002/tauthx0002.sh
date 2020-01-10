#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio -f ./kamailio-tauthx0002.cfg"
${KAMBIN} -P ${KAMPID} -w . -Y ${KAMRUN} -f ./kamailio-tauthx0002.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tauthx0002.log &
ret=$?
sleep 1
sipsak -H 127.0.0.1 -c sip:alice@127.0.0.1 -s sip:bob@127.0.0.1 -B "hello there"
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
grep "auth xkeys ok" /tmp/kamailio-tauthx0002.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0
