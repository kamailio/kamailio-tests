#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- run: ${KAMCTL} add alice@127.0.0.1 ..."
${KAMCTL} add alice@127.0.0.1 alice123
${KAMCTL} db show subscriber
echo "--- start kamailio -f ./kamailio-tauthx0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tauthx0001.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tauthx0001.log &
ret=$?
sleep 1
sipsak -u alice -a alice123 -H 127.0.0.1 -c sip:alice@127.0.0.1 -s sip:bob@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
grep "user alice is authenticated" /tmp/kamailio-tauthx0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
echo "--- start kamailio -f ./kamailio-tauthx0001.cfg -A WITH_MULTIDOMAIN"
rm -f /tmp/kamailio-tauthx0001.log
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tauthx0001.cfg -A WITH_MULTIDOMAIN -a no -ddd -E 2>&1 | tee /tmp/kamailio-tauthx0001.log &
ret=$?
sleep 1
sipsak -u alice -a alice123 -H 127.0.0.1 -c sip:alice@127.0.0.1 -s sip:bob@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
grep "user alice is authenticated" /tmp/kamailio-tauthx0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0