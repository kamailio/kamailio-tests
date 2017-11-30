#!/bin/bash

. ../../etc/config
. ../../libs/utils

# run default config check
${KAMBIN} -c
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi

# start with default config
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no
ret=$?
sleep 1
kill_pidfile ${KAMPID}
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi

# start with default config and -A WITH_DEBUG
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no -A WITH_DEBUG
ret=$?
sleep 1
kill_pidfile ${KAMPID}
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi

exit $ret
