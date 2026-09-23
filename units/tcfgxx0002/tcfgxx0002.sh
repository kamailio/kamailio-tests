#!/bin/bash

. ../../etc/config
. ../../libs/utils

${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} ${KAMPRM} -a no
ret=$?
sleep 1
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi
# sipexer returns the last sip status code
sipexer -sd -to-uri sip:127.0.0.1 sip:127.0.0.1
ret=$?
kill_pidfile ${KAMPID}

if [ ! "$ret" -eq 200 ] ; then
    exit 1
fi
exit 0