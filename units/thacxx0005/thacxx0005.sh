#!/bin/bash

. ../../etc/config
. ../../libs/utils

python3 http_server.py &

echo "--- start kamailio -f ./kamailio-thacxx0005.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-thacxx0005.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-thacxx0005.log &
#${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-thacxx0005.cfg -a no -dd -E 2>&1 | tee /tmp/kamailio-thacxx0005.log &
ret=$?

sleep 5

echo "-------------- starting sipp UAS -------------------------"
sipp -sf uas.xml -p 5080 -bg


sleep 1

echo "-------------- starting sipp UAC -------------------------"
sipp -sf uac.xml -m 10 127.0.0.1:5060

tail /tmp/kamailio-thacxx0005.log

echo
grep "HTTP_REPLY2" /tmp/kamailio-thacxx0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0

