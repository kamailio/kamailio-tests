#!/bin/bash

. ../../etc/config
. ../../libs/utils

LOG=/tmp/kamailio-tregxx0001.log

function run() {
	sed -e "s/#mask#/${mask}/g" ./kamailio-tregxx0001-inc > ./kamailio-tregxx0001-inc.cfg
	echo "--- start kamailio -f ./kamailio-tregxx0001.cfg with mask $mask"
	${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} \
		-f ./kamailio-tregxx0001.cfg -a no -ddd -E 2>&1 | tee ${LOG} &
	sleep 1
	sipsak -U -s sip:test@127.0.0.1 -C sip:test@127.2.2.1:5066
	sipsak -M -s sip:test@127.0.0.1
	sleep 1
	kill_pidfile ${KAMPID}
	sleep 1
}

function check() {
	local val=${1}
	local mask=${2}
	if ! grep -q "check\\[REGISTER\\]: ${val} exists" ${LOG} ; then
		echo "[${mask}] ${val} not found in REGISTER"
		exit 1
	fi
	if ! grep -q "check\\[MESSAGE\\]: ${val} exists" ${LOG}; then
		echo "[${mask}] ${val} not found in REGISTER"
		exit 1

	fi
}

function check_not() {
	val=${1}
	if grep -q "check\\[REGISTER\\]: ${val} exists" ${LOG} ; then
		echo "[${mask}] ${val} found in REGISTER"
		exit 1
	fi
	if grep -q "check\\[MESSAGE\\]: ${val} exists" ${LOG}; then
		echo "[${mask}] ${val} found in REGISTER"
		exit 1

	fi
}

echo
echo "--- grep output"
echo

mask=0
run
check ruid
check contact
check expires

mask=1
run
check_not ruid
check contact
check expires

mask=2
run
check ruid
check_not contact
check expires

mask=3
run
check_not ruid
check_not contact
check expires

mask=4
run
check ruid
check contact
check_not expires

mask=5
run
check_not ruid
check contact
check_not expires

mask=6
run
check ruid
check_not contact
check_not expires

mask=7
run
check_not ruid
check_not contact
check_not expires

exit 0
