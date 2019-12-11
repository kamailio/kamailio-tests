#!/bin/bash

. ../../etc/config
. ../../libs/utils

LOG=/tmp/kamailio-tregxx0001.log

function run() {
	echo "--- start kamailio -f ./kamailio-tregxx0002.cfg"
	${KAMBIN} -P ${KAMPID} -w ${KAMRUN} -Y ${KAMRUN} \
		-f ./kamailio-tregxx0002.cfg -a no -ddd -E 2>&1 | tee ${LOG} &
	sleep 1
	sipsak -U -s sip:test@127.0.0.1 -C sip:test@127.2.2.1:5066
	sipsak -U -s sip:test@127.0.0.1 -C sip:test@127.2.2.2:5066
	sipsak -U -s sip:test@127.0.0.1 -C sip:test@127.2.2.3:5066
	sleep 1
	kill_pidfile ${KAMPID}
	sleep 1
}

function _check_save() {
	local val=${1}
	local index=${2}
	# build_contact() has only those two for now
	if [[ "${val}" =~ ruid|expires ]]; then
		if ! grep -q "check: ${val}${index} exists" ${LOG} ; then
			echo "${val}[${index}] not found"
			exit 1
		fi
	else
		if grep -q "check: ${val}${index} exists" ${LOG} ; then
			echo "${val}[${index}] found"
			exit 1
		fi
	fi
}

function _check_value() {
	local field=${1}
	local val=${2}
	if ! grep -q "val ${field}:${val}" ${LOG} ; then
		echo "${field} val not ${val}"
		grep "val ${field}:" ${LOG}
		exit 1
	fi
}

function check_save() {
	local i
	local field
	for i in 0 1 2; do
		for field in ruid expires; do
			_check_save ${field} ${i}
		done
	done
}

function check_order() {
	local indx=0
	local i
	for i in $(awk '/set: ruid/ { print $6}' ${LOG}| sort -r | xargs); do
		_check_value ruid${indx} ${i}
		(( indx++ ))
	done
}

echo
echo "--- grep output"
echo

run
check_save
check_order

exit 0
