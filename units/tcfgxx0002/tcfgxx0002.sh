#!/bin/bash

. ../../etc/config
. ../../libs/utils

${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no
ret=$?
sleep 1
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi
sipsak -v -s sip:127.0.0.1
ret=$?
kill_pidfile ${KAMPID}

exit $ret
