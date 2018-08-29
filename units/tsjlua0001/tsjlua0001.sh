#!/bin/bash

. ../../etc/config
. ../../libs/utils

cp kamailio-tsjlua0001.lua /tmp/
echo "--- start kamailio -f ./kamailio-tsjlua0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tsjlua0001.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tsjlua0001.log &
ret=$?
sleep 1
sipsak -s sip:alice@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
rm /tmp/kamailio-tsjlua0001.lua
echo
echo "--- grep output"
echo
grep "rU\":\"alice" /tmp/kamailio-tsjlua0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0
