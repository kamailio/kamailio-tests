#!/bin/bash
# geoip2.reload with replaced, missing and corrupt database files

# Copyright (C) 2026 Kamailio project contributors
#
# This file is part of Kamailio, a free SIP server.
#
# Kamailio is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version
#
# Kamailio is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# shellcheck disable=SC1091
. ../../etc/config
. ../../libs/utils

UNIT=tgeoip0003
WORKDIR="/tmp/${UNIT}"
CFG="kamailio-${UNIT}.cfg"
KLOG="${WORKDIR}/kamailio.log"
DB="${WORKDIR}/geo.mmdb"
KAMCMD=("${KAMCTL}" kamcmd -s "unixs:${KAMRUN}/kamailio_ctl")
REQUESTS=6
ret=0

fail() {
	echo "FAIL: $*"
	ret=1
}

end_test() {
	[ -f "${KAMPID}" ] && kill_pidfile "${KAMPID}" 2>/dev/null
	sleep 1
	if [ "${ret}" -ne 0 ] && [ -f "${KLOG}" ]; then
		echo "--- last kamailio log lines"
		tail -20 "${KLOG}"
	fi
	rm -rf "${WORKDIR}"
	exit "${ret}"
}

# city - print "CODE city" for 192.0.2.1 from one request
city() {
	sipsak -H 127.0.0.1 -s sip:127.0.0.1:5060 -v --headers "X-IP: 192.0.2.1\n" 2>&1 \
		| awk '/^SIP\/2.0 [0-9]/{ code=$2 }
			/^X-Geo:/{ n=split($0, kv, ";"); for(i=1; i<=n; i++)
				if(kv[i] ~ /^city=/){ sub(/^city=/, "", kv[i]); c=kv[i] } }
			END { print code " " c }'
}

# expect_all DESC "CODE city" - every one of REQUESTS replies must match
expect_all() {
	local i got
	for i in $(seq 1 "${REQUESTS}"); do
		got=$(city)
		if [ "${got}" != "$2" ]; then
			fail "$1: request ${i} got '${got}', expected '$2'"
			return
		fi
	done
}

alive() {
	if ! kill -0 "$(cat "${KAMPID}" 2>/dev/null)" 2>/dev/null \
			|| grep -q -E "exited by a signal|terminating due to SIGCHLD" "${KLOG}"; then
		fail "kamailio stopped or a child died after: $1"
		end_test
	fi
}

reload() {
	if ! "${KAMCMD[@]}" geoip2.reload > /dev/null; then
		fail "geoip2.reload RPC failed ($1)"
	fi
}

# install FILE - replace the database file the way the docs ask: move
install() {
	mv "$1" "${DB}.tmp" && mv "${DB}.tmp" "${DB}"
}

for tool in python3 sipsak; do
	if ! (which "${tool}" > /dev/null 2>&1); then
		echo "${tool} not found, not run"
		exit 0
	fi
done

rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
if ! python3 ../../libs/mkmmdb.py "${DB}" \
		|| ! python3 ../../libs/mkmmdb.py "${WORKDIR}/v1.mmdb" \
		|| ! python3 ../../libs/mkmmdb.py "${WORKDIR}/v2.mmdb" --variant reload; then
	echo "cannot generate the test databases, not run"
	rm -rf "${WORKDIR}"
	exit 0
fi

sed "s|__MMDB__|${DB}|g" "${CFG}" > "${WORKDIR}/kamailio.cfg"
if ! ${KAMBIN} -P "${KAMPID}" -w "${KAMRUN}" -Y "${KAMRUN}" -a no \
		-f "${WORKDIR}/kamailio.cfg" > "${KLOG}" 2>&1; then
	fail "kamailio did not start"
	end_test
fi
sleep 1

echo "--- test 1: database from startup"
expect_all "startup" "200 Bucharest"

echo "--- test 2: replaced file is not used before geoip2.reload"
cp "${WORKDIR}/v2.mmdb" "${WORKDIR}/next.mmdb"
install "${WORKDIR}/next.mmdb"
expect_all "file replaced, no reload" "200 Bucharest"

echo "--- test 3: geoip2.reload switches all workers"
reload "new file"
expect_all "after reload" "200 Cluj-Napoca"

echo "--- test 4: geoip2.reload with an unchanged file"
reload "unchanged file"
expect_all "after reload of the same file" "200 Cluj-Napoca"

echo "--- test 5: missing file"
rm -f "${DB}"
reload "missing file"
expect_all "missing file" "404 "
alive "reload with a missing file"

echo "--- test 6: corrupt file"
head -c 4096 /dev/urandom > "${WORKDIR}/bad.mmdb"
install "${WORKDIR}/bad.mmdb"
reload "corrupt file"
expect_all "corrupt file" "404 "
alive "reload with a corrupt file"

echo "--- test 7: valid file back"
cp "${WORKDIR}/v1.mmdb" "${WORKDIR}/next.mmdb"
install "${WORKDIR}/next.mmdb"
reload "valid file back"
expect_all "valid file back" "200 Bucharest"
alive "recovery"

end_test
