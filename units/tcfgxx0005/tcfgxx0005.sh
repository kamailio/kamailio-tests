#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio with the default config"
echo "cmd: ${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} ${KAMPRM} -a no -E -dd"
${KAMBIN} -P "${KAMPID}" -w "${KAMRUN}" -Y "${KAMRUN}" ${KAMPRM} -a no -E -dd
ret=$?
if [ "${ret}" -ne 0 ]; then
	exit "${ret}"
fi

sleep 1

echo "--- register two users and call with sipexer"
sipexer --call-user --ring-time 1000 --call-duration 2000 \
	--fuser alice --local-address 127.0.0.1:5062 \
	--ua2-fuser bob --ua2-local-address 127.0.0.1:5064 \
	--expires 60 --contact-build --set-domains --set-user \
	udp:127.0.0.1:5060

ret=$?
kill_pidfile ${KAMPID}

exit $ret
