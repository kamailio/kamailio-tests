#!/bin/bash

. ../../etc/config
. ../../libs/utils

kill_kamailio
sleep 1
echo "--- run: VERIFY_ACL=0 VERIFY_USER=0 ${KAMCTL} acl grant alice@127.0.0.1 test"
VERIFY_ACL=0 VERIFY_USER=0 ${KAMCTL} acl grant alice@127.0.0.1 test
echo "--- start kamailio -f ./kamailio-tgroup0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tgroup0001.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tgroup0001.log &
ret=$?
sleep 1
sipsak -s sip:alice@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
grep "user alice is in group test" /tmp/kamailio-tgroup0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
echo "--- start kamailio -f ./kamailio-tgroup0001.cfg -A WITH_MULTIDOMAIN"
rm -f /tmp/kamailio-tgroup0001.log
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tgroup0001.cfg -A WITH_MULTIDOMAIN -a no -ddd -E 2>&1 | tee /tmp/kamailio-tgroup0001.log &
ret=$?
sleep 1
sipsak -s sip:alice@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
grep "user alice is in group test" /tmp/kamailio-tgroup0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0