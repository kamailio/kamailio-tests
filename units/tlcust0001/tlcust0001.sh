#!/bin/bash

. ../../etc/config
. ../../libs/utils


echo "--- start nc -ulp 24680 | tee /tmp/kamailio-tlcust0001.netcat &"
nc -ulp 24680 | tee /tmp/kamailio-tlcust0001.netcat &
echo "--- start kamailio -f ./kamailio-tlcust0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tlcust0001.cfg -a no 2>&1 | tee /tmp/kamailio-tlcust0001.log &
ret=$?
sleep 1
echo "--- restart nc -ulp 24680 | tee /tmp/kamailio-tlcust0001.netcat &"
killall nc
nc -ulp 24680 | tee /tmp/kamailio-tlcust0001.netcat &
echo "--- run sipsak -s sip:alice@127.0.0.1"
sipsak -vvv -s sip:alice@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
killall nc
sleep 1
echo
echo "--- grep output"
echo
ls -l /tmp
echo "---"
cat /tmp/kamailio-tlcust0001.netcat
echo "---"
cat /tmp/kamailio-tlcust0001.log
echo "---"
grep "logcustom" /tmp/kamailio-tlcust0001.netcat
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0
