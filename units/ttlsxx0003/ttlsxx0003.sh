#!/bin/bash
# checks tls_connection_match_domain=yes creates new connection to the same dst ip:port for another tls domain

# Copyright (C) 2026 furmur@pm.me
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

. ../../etc/config
. ../../libs/utils

# . include/common
#  include/require.sh

CFGFILE="kamailio-ttlsxx0003.cfg"
TMPFILE=$(mktemp -t kamailio-test.XXXXXXXXXX)
SIPSAKOPTS="-H localhost -s sip:127.0.0.1:5060 -v"
KAMCMD="${KAMCTL} kamcmd"
KAMCMDOPTS="-s unixs:${KAMRUN}/kamailio_ctl"
TLSKEYFILE=kamailio-selfsigned.key
TLSCERTFILE=kamailio-selfsigned.pem

end_test_no_kamailio() {
	rm -f ${TMPFILE} ${TLSKEYFILE} ${TLSCERTFILE}
	exit ${ret}
}

end_test() {
	kill_pidfile "${KAMPID}" 2>/dev/null
	end_test_no_kamailio
}

assert_tls_connections_count() {
	# run tls.info and extract opened_connections value
	tls_connections_count=$(${KAMCMD} ${KAMCMDOPTS} tls.info | awk '/opened_connections/{ print $2 }')
	ret=$?
	if [ "${ret}" -ne 0 ] ; then
		echo -e "\terror: kamcmd or awk returned ${ret}, aborting"
		end_test
	fi

	if [ ! ${tls_connections_count} -eq "$1" ]; then
		ret=1
		echo -e "\terror: got ${tls_connections_count} tls connections count while expected: $1"
		end_test
	fi
}

ret=0

# check openssl is available
if ! (which openssl > /dev/null 2>&1); then
	echo "openssl not found, not run"
	end_test_no_kamailio
fi

# --- generate self-signed certs ---
openssl req -x509 -newkey rsa:2048 -nodes \
	-keyout ${TLSKEYFILE} -out ${TLSCERTFILE} \
	-days 1 -subj "/CN=kamailio-test-rsa/O=Test" 2>/dev/null

if [ ! -f ${TLSKEYFILE} ]; then
	echo "no ${TLSKEYFILE} generated. not run"
	end_test_no_kamailio
fi

if [ ! -f ${TLSCERTFILE} ]; then
	echo "no ${TLSCERTFILE} generated. not run"
	end_test_no_kamailio
fi

# start kamailio

${KAMBIN} -P "${KAMPID}" -w "${KAMRUN}" -Y "${KAMRUN}" -a no -f "$CFGFILE" > /dev/null
ret=$?

sleep 1
if [ "${ret}" -ne 0 ] ; then
	echo "failed to start kamailio"
	end_test
fi

# send 1st request. should go sipsak --udp--> 127.0.0.1:5060 kamailio 127.0.0.1:random --tls domain with server_id:1--> 127.0.0.1:5061 kamailio
sipsak ${SIPSAKOPTS} --headers "X-TLS-Server-ID: 1\n" > ${TMPFILE}
ret=$?
if [ "${ret}" -ne 0 ] ; then
	echo "1st sipsak returned ${ret}, aborting"
	cat ${TMPFILE}
	end_test
fi

echo "--- test 1: connection is reused for the same TLS-domain"
# send 2nd request. should go sipsak --udp--> 127.0.0.1:5060 kamailio 127.0.0.1:random --tls domain with server_id:1--> 127.0.0.1:5061 kamailio
# this one is to check if first connection was reused
sipsak ${SIPSAKOPTS} --headers "X-TLS-Server-ID: 1\n" > ${TMPFILE}
ret=$?
if [ "${ret}" -ne 0 ] ; then
	echo "2nd sipsak returned ${ret}, aborting"
	cat ${TMPFILE}
	end_test
fi

# assert first tls connection was reused
assert_tls_connections_count 2

echo "--- test 2: new connection is created for the different TLS domain"
# send 3rd request. should go sipsak --udp--> 127.0.0.1:5060 kamailio 127.0.0.1:random --tls domain with server_id:2--> 127.0.0.1:5061 kamailio
sipsak ${SIPSAKOPTS} --headers "X-TLS-Server-ID: 2\n" > ${TMPFILE}
ret=$?
if [ "${ret}" -ne 0 ] ; then
	echo "3rd sipsak returned ${ret}, aborting"
	cat ${TMPFILE}
	end_test
fi

# the test essence here: we expect 4 tls connections. 2 (client + server) for each TLS client domain
assert_tls_connections_count 4

ret=0
end_test
