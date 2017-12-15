#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio -f ./kamailio-tgeoip0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tgeoip0001.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tgeoip0001.log &
ret=$?
sleep 1
sipsak -s sip:alice@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
grep "ip address is registered in US" /tmp/kamailio-tgeoip0001.log
ret=$?
rm -f /tmp/kamailio-tgeoip0001.log
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0
