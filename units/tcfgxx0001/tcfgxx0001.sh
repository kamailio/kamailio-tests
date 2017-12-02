#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- run default config check"
${KAMBIN} -c
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi

echo "--- start with default config"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no
ret=$?
sleep 1
kill_pidfile ${KAMPID}
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi

echo "--- start with default config and several -A options (auth, ipauth, usrlodb ..."
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no -A WITH_DEBUG -A WITH_MYSQL -A WITH_IPAUTH -A WITH_USRLOCDB
ret=$?
sleep 1
kill_pidfile ${KAMPID}
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi

exit $ret
