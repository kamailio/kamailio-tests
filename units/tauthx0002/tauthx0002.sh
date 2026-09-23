#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio -f ./kamailio-tauthx0002.cfg"
${KAMBIN} -P ${KAMPID} -w . -Y ${KAMRUN} -f ./kamailio-tauthx0002.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tauthx0002.log &
ret=$?
sleep 1
sipexer -message -mb "hello there" --from-uri sip:alice@127.0.0.1 --to-uri sip:bob@127.0.0.1 sip:bob@127.0.0.1
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
