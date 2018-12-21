#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio -f ./kamailio-tuacxx0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tuacxx0001.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tuacxx0001.log &
ret=$?
sleep 1
sipsak -s sip:test@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
grep "info request authenticated" /tmp/kamailio-tuacxx0001.log
ret=$?
rm -f /tmp/kamailio-tuacxx0001.log
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0
