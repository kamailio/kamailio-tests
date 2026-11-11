#!/bin/bash
# geoip2 lookups, containers and distance on a generated test database

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

UNIT=tgeoip0002
WORKDIR="/tmp/${UNIT}"
CFG="kamailio-${UNIT}.cfg"
KLOG="${WORKDIR}/kamailio.log"
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

# geo HEADERS - send OPTIONS with HEADERS, print "CODE|X-Geo value"
geo() {
	sipsak -H 127.0.0.1 -s sip:127.0.0.1:5060 -v --headers "$1" 2>&1 \
		| awk '/^SIP\/2.0 [0-9]/{ code=$2 }
			/^X-Geo:/{ sub(/^X-Geo: */, ""); sub(/\r$/, ""); geo=$0 }
			END { print code "|" geo }'
}

# expect DESC HEADERS EXPECTED
expect() {
	local got
	got=$(geo "$2")
	if [ "${got}" != "$3" ]; then
		fail "$1"
		echo "  expected: $3"
		echo "  got:      ${got}"
	fi
}

for tool in python3 sipsak; do
	if ! (which "${tool}" > /dev/null 2>&1); then
		echo "${tool} not found, not run"
		exit 0
	fi
done

rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
if ! python3 ../../libs/mkmmdb.py "${WORKDIR}/test.mmdb"; then
	echo "cannot generate the test database, not run"
	rm -rf "${WORKDIR}"
	exit 0
fi

sed "s|__MMDB__|${WORKDIR}/test.mmdb|g" "${CFG}" > "${WORKDIR}/kamailio.cfg"
if ! ${KAMBIN} -P "${KAMPID}" -w "${KAMRUN}" -Y "${KAMRUN}" -a no \
		-f "${WORKDIR}/kamailio.cfg" > "${KLOG}" 2>&1; then
	fail "kamailio did not start"
	end_test
fi
sleep 1

echo "--- test 1: full IPv4 record"
expect "192.0.2.77 all keys" 'X-IP: 192.0.2.77\n' \
	'200|cc=RO;contc=EU;city=Bucharest;regc=B;zip=010011;tz=Europe/Bucharest;lat=44.426800;lon=26.102500;metro=<null>'
expect "198.51.100.10 all keys, metro code" 'X-IP: 198.51.100.10\n' \
	'200|cc=US;contc=NA;city=San Francisco;regc=CA;zip=94107;tz=America/Los_Angeles;lat=37.774900;lon=-122.419400;metro=807'

echo "--- test 2: IPv6 record"
expect "2001:db8:1::5 all keys" 'X-IP: 2001:db8:1::5\n' \
	'200|cc=DE;contc=EU;city=Berlin;regc=BE;zip=10115;tz=Europe/Berlin;lat=52.520000;lon=13.405000;metro=<null>'

expect "2001:db8:1::5 nmask" 'X-Op: nmask\nX-IP: 2001:db8:1::5\n' '200|nmask=48'

echo "--- test 3: cc from registered_country, missing keys"
expect "198.51.100.200 registered_country only" 'X-IP: 198.51.100.200\n' \
	'200|cc=JP;contc=AS;city=<null>;regc=<null>;zip=<null>;tz=<null>;lat=<null>;lon=<null>;metro=<null>'

echo "--- test 4: region name"
expect "192.0.2.1 regn" 'X-Op: regn\nX-IP: 192.0.2.1\n' '200|regn=Bucuresti'
expect "198.51.100.1 regn" 'X-Op: regn\nX-IP: 198.51.100.1\n' '200|regn=California'
expect "198.51.100.200 regn missing" 'X-Op: regn\nX-IP: 198.51.100.200\n' '200|regn=<null>'

echo "--- test 5: no match"
expect "address without entry" 'X-IP: 203.0.113.9\n' '404|'
expect "IPv6 address without entry" 'X-IP: 2001:db8:2::1\n' '404|'
expect "private address" 'X-IP: 10.1.1.1\n' '404|'
expect "invalid string" 'X-IP: not-an-ip\n' '404|'
expect "empty string" 'X-IP: \n' '404|'
expect "local sender \$si" 'X-Op: si\n' '404|'

echo "--- test 6: containers"
expect "two containers in one request" \
	'X-Op: two\nX-IP: 192.0.2.1\nX-IP2: 2001:db8:1::1\n' '200|src=RO;dst=DE'
expect "container reused for a shorter address" \
	'X-Op: repeat\nX-IP: 192.0.2.1\nX-IP2: 2001:db8:1:ffff:ffff:ffff:ffff:ffff\n' \
	'200|cc=RO;contc=EU;city=Bucharest;regc=B;zip=010011;tz=Europe/Bucharest;lat=44.426800;lon=26.102500;metro=<null>'

echo "--- test 7: geoip2_distance"
# Berlin (52.52, 13.405) to the Bucharest record: 804 miles (haversine)
expect "distance to a record" \
	'X-Op: dist\nX-IP: 192.0.2.1\nX-Lat: 52.52\nX-Lon: 13.405\n' '200|dist=804'
expect "distance, no entry" \
	'X-Op: dist\nX-IP: 203.0.113.1\nX-Lat: 1\nX-Lon: 1\n' '200|dist=-2'
expect "distance, entry without location" \
	'X-Op: dist\nX-IP: 198.51.100.200\nX-Lat: 1\nX-Lon: 1\n' '200|dist=-2'

echo "--- test 8: server still running"
if ! kill -0 "$(cat "${KAMPID}" 2>/dev/null)" 2>/dev/null \
		|| grep -q -E "exited by a signal|terminating due to SIGCHLD" "${KLOG}"; then
	fail "kamailio stopped or a child died"
fi
# the only expected error is the one for the record without location
if grep "ERROR" "${KLOG}" | grep -v -q "no location/latitude for: 198.51.100.200"; then
	fail "unexpected errors in the kamailio log"
	grep "ERROR" "${KLOG}" | head -5
fi

end_test
