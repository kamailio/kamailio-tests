#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- start kamailio -f ./kamailio-allmods.cfg"
${KAMBIN} -f ./kamailio-allmods.cfg -dd -E 2>&1 | tee /tmp/kamailio-allmods.log
echo
echo "--- grep output"
grep "undefined symbol" /tmp/kamailio-allmods.log
ret=$?
if [ "$ret" -eq 1 ] ; then
    exit 0
fi
exit 1
