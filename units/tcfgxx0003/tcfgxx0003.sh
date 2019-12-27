#!/bin/bash

. ../../etc/config
. ../../libs/utils

LOG=/tmp/kamailio-tcfgxx0003.log

function check_out() {
    if ! grep -q 'different number of preprocessor directives' ${LOG} ; then
        echo "'different number of preprocessor directives' not found on check"
        exit 1
    fi
    echo > ${LOG}
}

echo "--- run config check"
${KAMBIN} -c -f ./kamailio-tcfgxx0003.cfg >/dev/null 2>&1
ret=$?
if [ "$ret" -eq 0 ] ; then
    echo "kamailio didn't fail"
    exit 1
fi
${KAMBIN} -c -f ./kamailio-tcfgxx0003.cfg 2>&1 | tee ${LOG}
check_out

echo
echo "--- start kamailio -f ./kamailio-tcfgxx0003.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no -ddd -E \
    -f ./kamailio-tcfgxx0003.cfg >/dev/null 2>&1
ret=$?
if [ "$ret" -eq 0 ] ; then
    sleep 1
    kill_pidfile ${KAMPID}
    echo "kamailio didn't fail"
    exit 1
fi
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -a no -ddd -E \
    -f ./kamailio-tcfgxx0003.cfg 2>&1 | tee ${LOG}
check_out

exit 0
