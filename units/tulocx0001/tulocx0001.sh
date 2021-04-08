#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo
echo "--- start with default config"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no
ret=$?
sleep 1
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi
echo
echo "--- start sipsak -vvv -U -I -H 127.0.0.1 -s sip:alice@127.0.0.1"
sipsak -vvv -U -H 127.0.0.1 -s sip:alice@127.0.0.1 2>&1 | tee /tmp/kamailio-tulocx0001.log &
sleep 1
echo
echo "--- grep output"
echo
grep "All usrloc tests completed successful" /tmp/kamailio-tulocx0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
kill_pidfile ${KAMPID}

exit $ret
