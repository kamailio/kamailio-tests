#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo
echo "--- start with default config: ${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no
ret=$?
sleep 1
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi
echo
echo "--- start sipsak -vvv -U -i -l 15098 -H 127.0.0.1 -s sip:alice@127.0.0.1"
sipsak -vvv -U -i -l 15098 -H 127.0.0.1 -s sip:alice@127.0.0.1:5060 2>&1 | tee /tmp/kamailio-tulocx0001.log &
sleep 1
echo
echo "--- grep output"
echo
grep "SIP/2.0 200 OK" /tmp/kamailio-tulocx0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
kill_pidfile ${KAMPID}

exit $ret
