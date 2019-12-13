#!/bin/bash

. ../../etc/config
. ../../libs/utils

LOG=/tmp/kamailio-tavpop0001.log

echo "--- start kamailio -f ./kamailio-tavpop0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} \
	-f ./kamailio-tavpop0001.cfg -a no -ddd -E 2>&1 | tee ${LOG} &
sleep 1
sipsak -M -s sip:test1test@127.0.0.1
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
for i in 0 1 2 3 4 5 6 7 8 9; do
	if ! grep -q "test${i}: OK" ${LOG}; then
		echo "test${i} failed"
		exit 1
	fi
done
exit 0
