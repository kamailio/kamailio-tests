#!/bin/bash

. ../../etc/config
. ../../libs/utils


echo "--- start nc -u -l -p 24680 | tee /tmp/kamailio-tlcust0001.netcat &"
rm -f /tmp/kamailio-tlcust0001.netcat
nc -u -l -p 24680 | tee /tmp/kamailio-tlcust0001.netcat &
sleep 1
echo "--- start kamailio -f ./kamailio-tlcust0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tlcust0001.cfg -a no 2>&1 | tee /tmp/kamailio-tlcust0001.log &
ret=$?
sleep 2
echo "--- run sipsak -s sip:alice@127.0.0.1"
sipsak -vvv -s sip:alice@127.0.0.1:5060
sleep 1
kill_pidfile ${KAMPID}
sleep 1
killall nc
sleep 1
echo
echo "--- output files"
echo
ls -l /tmp
echo "--- /tmp/kamailio-tlcust0001.netcat"
cat /tmp/kamailio-tlcust0001.netcat
echo "--- /tmp/kamailio-tlcust0001.log"
cat /tmp/kamailio-tlcust0001.log
echo "---"
echo "--- grep output"
grep "logcustom" /tmp/kamailio-tlcust0001.netcat
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0
