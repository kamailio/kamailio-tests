#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio -f ./kamailio-tsiput0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tsiput0001.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tsiput0001.log &
ret=$?
sleep 1
sipsak -s sip:alice@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo

grep "ruri user alice is not tel number" /tmp/kamailio-tsiput0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "\+24242424 is tel number" /tmp/kamailio-tsiput0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "uri user alice is not numeric" /tmp/kamailio-tsiput0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "\+24242424 is not numeric" /tmp/kamailio-tsiput0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "ruri user alice is alpha-numeric" /tmp/kamailio-tsiput0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "\+24242424 is not alpha-numeric" /tmp/kamailio-tsiput0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "ruri user alice is extended alpha-numeric" /tmp/kamailio-tsiput0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "\+24242424 is extended alpha-numeric" /tmp/kamailio-tsiput0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi

exit 0
