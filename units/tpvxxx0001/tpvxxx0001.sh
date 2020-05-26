#!/bin/bash

. ../../etc/config
. ../../libs/utils

LOG=/tmp/kamailio-tpvxxx0001.log

echo "--- start kamailio -f ./kamailio-tpvxxx0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} \
	-f ./kamailio-tpvxxx0001.cfg -a no -ddd -E 2>&1 | tee ${LOG} &
sleep 1
sipsak -M -s sip:test1test@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
for i in 0 1; do
	if ! grep -q "test${i}: OK" ${LOG}; then
		echo "test${i} failed"
		exit 1
	fi
done
exit 0
