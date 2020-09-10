#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo
echo "--- start with default config and -A WITH_TLS"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no -A WITH_TLS -ddd -E 2>&1 | tee /tmp/kamailio-ttlsxx0001.log &
ret=$?
sleep 1
timeout 3 openssl s_client -connect 127.0.0.1:5061 -showcerts
kill_pidfile ${KAMPID}
if [ ! "$ret" -eq 0 ] ; then
    exit $ret
fi

exit $ret
