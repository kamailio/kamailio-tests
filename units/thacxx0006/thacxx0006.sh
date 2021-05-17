#!/bin/bash

. ../../etc/config
. ../../libs/utils

python3 http_server.py &

echo "--- start kamailio -f ./kamailio-thacxx0006.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-thacxx0006.cfg -a no -dd -E 2>&1 | tee /tmp/kamailio-thacxx0006.log &
ret=$?

sleep 3

echo "-------------- starting sipp UAS -------------------------"
sipp -sf uas.xml -p 5080 -bg

sleep 1

NCALLS=20
echo "-------------- starting sipp UAC -------------------------"
sipp -sf uac.xml -m ${NCALLS} 127.0.0.1:5060

kill_pidfile ${KAMPID}
sleep 1
killall python3
sleep 1
killall sipp

echo
count="$(grep -c "INVITE_REPLY OK" /tmp/kamailio-thacxx0006.log)"
if [ ! $count -eq $NCALLS ] ; then
    exit 1
fi
exit 0
