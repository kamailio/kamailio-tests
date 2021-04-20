#!/bin/bash

. ../../etc/config
. ../../libs/utils

python3 http_server.py &

echo "--- start kamailio -f ./kamailio-thacxx0003.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-thacxx0003.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-thacxx0003.log &
ret=$?
sleep 1
sipsak -s sip:test@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
killall python3
sleep 1
echo
echo "--- grep output"
echo
grep "HTTP DELETE REPLY: 200" /tmp/kamailio-thacxx0003.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0
