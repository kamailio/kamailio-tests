#!/bin/bash
# shellcheck disable=SC1091
. ../../etc/config
. ../../libs/utils

LOG=/tmp/kamailio-tregxx0003.log
OUT=/tmp/sipexer-tregxx0003.out
TARGET=udp:127.0.0.1:5060
AOR=(-fuser wildcard -fdomain example.test -tuser wildcard -tdomain example.test)
ONE="<sip:one@127.0.0.1:6091>"
TWO="<sip:two@127.0.0.1:6092>"
PATHOB="<sip:edge.example.test:5097;lr;ob>"
PATHNOOB="<sip:edge.example.test:5097;lr>"

fail() {
	echo "--- failed: ${1}"
	cat ${OUT}
	kill_pidfile "${KAMPID}"
	exit 1
}

# sipexer exits with the SIP reply code, truncated by the shell to 8 bits
check_code() {
	local desc=${1} expected=${2} ret=${3}
	echo "--- ${desc}: expecting ${expected}"
	if [ "${ret}" -ne $((expected % 256)) ]; then
		fail "${desc}"
	fi
}

# REGISTER as forwarded by an outbound edge proxy: second Via and Path
# params: description, expected reply code, Path URI, [Contact, [Expires]]
register() {
	local desc=${1} expected=${2} path=${3} contact=${4} expires=${5}
	local args=(-register -vl 3 -timeout 5000 "${AOR[@]}"
		-xh "Via: SIP/2.0/UDP 127.0.0.2:5097;branch=z9hG4bK-edge"
		-xh "Supported: outbound, path" -xh "Path: ${path}")
	if [ -n "${contact}" ]; then
		# set the template field, -cu would enclose the star in <>
		args+=(-fv "contacturi:${contact}")
	fi
	if [ -n "${expires}" ]; then
		args+=(-ex "${expires}")
	fi
	sipexer "${args[@]}" ${TARGET} >${OUT} 2>&1
	check_code "${desc}" "${expected}" $?
}

# fetch the bindings and check that both contacts are in the reply
both_bindings() {
	register "${1}" 200 "${PATHOB}"
	if ! grep -q "sip:one@127" ${OUT} || ! grep -q "sip:two@127" ${OUT}; then
		fail "${1}"
	fi
}

# OPTIONS gets 200 or 404 from the config, based on registered()
no_bindings() {
	sipexer -timeout 5000 "${AOR[@]}" -ru sip:wildcard@example.test \
		${TARGET} >${OUT} 2>&1
	check_code "${1}" 404 $?
}

echo "--- start kamailio -f ./kamailio-tregxx0003.cfg"
${KAMBIN} -P "${KAMPID}" -w "${KAMRUN}" -Y "${KAMRUN}" \
	-f ./kamailio-tregxx0003.cfg -a no -dd -E 2>&1 | tee ${LOG} &
sleep 1

register "add first binding" 200 "${PATHOB}" "${ONE}" 600
register "add second binding" 200 "${PATHOB}" "${TWO}" 600
both_bindings "both bindings stored"
register "star with Expires 0" 200 "${PATHOB}" "*" 0
no_bindings "no bindings after star"

register "add binding, Path without ob" 200 "${PATHNOOB}" "${ONE}" 600
register "star with Expires 0, Path without ob" 200 "${PATHNOOB}" "*" 0
no_bindings "no bindings after star, Path without ob"

register "add first binding again" 200 "${PATHOB}" "${ONE}" 600
register "add second binding again" 200 "${PATHOB}" "${TWO}" 600
register "star with non-zero Expires" 400 "${PATHOB}" "*" 60
register "star without Expires" 400 "${PATHOB}" "*"
register "star mixed with a contact" 400 "${PATHOB}" \
	"*, <sip:three@127.0.0.1:6093>" 0
both_bindings "both bindings kept after rejected star"

kill_pidfile "${KAMPID}"
sleep 1
exit 0
