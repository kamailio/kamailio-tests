#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio -f ./kamailio-tasync0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tasync0001.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tasync0001.log
ret=$?
sleep 1
kill_pidfile ${KAMPID}
echo
echo "--- grep output"
echo
grep "request_route: var_loc is 1" /tmp/kamailio-tasync0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "request_route: var_inc is 1" /tmp/kamailio-tasync0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "async_route: var_loc is 1" /tmp/kamailio-tasync0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
grep "async_route: var_inc is 1" /tmp/kamailio-tasync0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0
