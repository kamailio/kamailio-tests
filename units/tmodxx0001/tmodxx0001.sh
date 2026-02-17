#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio -f ./kamailio-allmods.cfg"
${KAMBIN} -f ./kamailio-allmods.cfg -dd -E 2>&1 | tee /tmp/kamailio-allmods.log
echo
echo "--- grep output"
echo
grep -e "undefined symbol" -e "could not find module" /tmp/kamailio-allmods.log
ret=$?
if [ ! "$ret" -eq 1 ] ; then
    exit 1
fi
echo "--- start kamailio -f ./kamailio-allmods.cfg -A WITH_IMS -A WITH_RTPPROXY"
${KAMBIN} -f ./kamailio-allmods.cfg -dd -E  -A WITH_IMS -A WITH_RTPPROXY 2>&1 | tee /tmp/kamailio-allmods.log
echo
echo "--- grep output"
echo
grep -e "undefined symbol" -e "could not find module" /tmp/kamailio-allmods.log
ret=$?
if [ ! "$ret" -eq 1 ] ; then
    exit 1
fi
exit 0
