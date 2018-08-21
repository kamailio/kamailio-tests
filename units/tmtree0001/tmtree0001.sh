#!/bin/bash

. ../../etc/config
. ../../libs/utils

echo "--- run: ${KAMCTL} mtree add mtree 1234567890 alice"
${KAMCTL} mtree add mtree 1234567890 alice
echo "--- run: ${KAMCTL} mtree add mtree 2345678901 bob"
${KAMCTL} mtree add mtree 2345678901 bob
${KAMCTL} mtree show mtree
${KAMCTL} mtree dump mtree
echo "--- start kamailio -f ./kamailio-tmtree0001.cfg"
${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} -f ./kamailio-tmtree0001.cfg -a no -ddd -E 2>&1 | tee /tmp/kamailio-tmtree0001.log &
ret=$?
sleep 1
sipsak -s sip:1234567890@127.0.0.1
sleep 1
echo "--- run: ${KAMCTL} mtree add mtree 3456789012 carol"
${KAMCTL} mtree add mtree 3456789012 carol
echo "--- run: ${KAMCTL} mtree show mtree"
${KAMCTL} mtree show mtree
echo "--- run: ${KAMCTL} mtree dump mtree"
${KAMCTL} mtree dump mtree
echo "--- run: ${KAMCTL} mtree reload mtree"
${KAMCTL} mtree reload mtree
echo "--- run: ${KAMCTL} mtree dump mtree"
${KAMCTL} mtree dump mtree
sleep 1
kill_pidfile ${KAMPID}
sleep 1
echo
echo "--- grep output"
echo
grep "tprefix 1234567890 tvalue alice" /tmp/kamailio-tmtree0001.log
ret=$?
if [ ! "$ret" -eq 0 ] ; then
    exit 1
fi
exit 0
