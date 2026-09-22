#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio with the default config"
${KAMBIN} -P "${KAMPID}" -w "${KAMRUN}" -Y "${KAMRUN}" -A ACTIVE -a no -E -dd
ret=$?
if [ "${ret}" -ne 0 ]; then
	exit "${ret}"
fi

sleep 1

echo "--- register and call self with sipexer"
sipexer --call-self --ring-time 1000 --call-duration 2000 \
	--fuser alice --expires 60 --contact-build --set-domains --set-user \
	udp:127.0.0.1:5060

ret=$?
kill_pidfile ${KAMPID}

exit $ret