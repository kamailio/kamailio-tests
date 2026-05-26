#!/bin/bash

. ../../etc/config
. ../../libs/utils

# enable defines for optional modules that are present in the build
MODS_DIR=/usr/local/lib/kamailio/modules
OPT_DEFINES=""
[ -f "${MODS_DIR}/rtp_media_server.so" ] && OPT_DEFINES="${OPT_DEFINES} -A WITH_RTP_MEDIA_SERVER"

echo "--- start kamailio -f ./kamailio-allmods.cfg ${OPT_DEFINES}"
${KAMBIN} -f ./kamailio-allmods.cfg -dd -E ${OPT_DEFINES} 2>&1 | tee /tmp/kamailio-allmods.log
echo
echo "--- grep output"
echo
grep -e "undefined symbol" -e "could not find module" /tmp/kamailio-allmods.log
ret=$?
if [ ! "$ret" -eq 1 ] ; then
    exit 1
fi
echo "--- start kamailio -f ./kamailio-allmods.cfg -A WITH_IMS -A WITH_RTPPROXY ${OPT_DEFINES}"
${KAMBIN} -f ./kamailio-allmods.cfg -dd -E -A WITH_IMS -A WITH_RTPPROXY ${OPT_DEFINES} 2>&1 | tee /tmp/kamailio-allmods.log
echo
echo "--- grep output"
echo
grep -e "undefined symbol" -e "could not find module" /tmp/kamailio-allmods.log
ret=$?
if [ ! "$ret" -eq 1 ] ; then
    exit 1
fi
exit 0
