#!/bin/bash

. ../../etc/config
. ../../libs/utils

LOG=/tmp/kamailio-tregexxx0001.log

cp regex_groups_1 /tmp/regex_groups
echo "--- start kamailio -f ./kamailio-tregexxx0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} \
	-f ./kamailio-tregexxx0001.cfg -a no -ddd -E 2>&1 | tee ${LOG} &
ret=$?
sleep 1
sipsak -s sip:test@127.0.0.1 -B "HOLA caracola"

echo "--- regex reload ---"
cp regex_groups_2 /tmp/regex_group
${KAMCTL} kamcmd regex.reload
sleep 1
sipsak -s sip:test@127.0.0.1 -B "ADIOS caracola"
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo

if ! grep -q '\^HOLA matches' ${LOG} ; then
    exit 1
fi
if ! grep -q '\^HOLA group 0 matches' ${LOG} ; then
    exit 1
fi

if ! grep -q '\^ADIOS matches' ${LOG} ; then
    exit 1
fi
if ! grep -q '\^ADIOS group 0 matches' ${LOG} ; then
    exit 1
fi
exit 0

