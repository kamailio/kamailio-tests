#!/bin/bash
# checks http_async_client closes the pooled TLS connections retired by libcurl

# Copyright (C) 2026 Pier-Luc Auger <pier-luc.auger@dialstack.ai>
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

CFGFILE="kamailio-thacxx0007.cfg"
LOGFILE_UNIT=/tmp/kamailio-thacxx0007.log
TMPDIR_UNIT=$(mktemp -d -t kamailio-test.XXXXXXXXXX)
# server port 8443, as hex in /proc/net/tcp
SRVPORTHEX="20FB"
ROUNDS=4
NQUERIES=40
MAXCLOSEWAIT=10
SRVPID=""

end_test_no_kamailio() {
	if [ -n "${SRVPID}" ] ; then
		kill "${SRVPID}" 2>/dev/null
		wait "${SRVPID}" 2>/dev/null
	fi
	rm -rf "${TMPDIR_UNIT}"
	exit "${ret}"
}

end_test() {
	kill_pidfile "${KAMPID}" 2>/dev/null
	sleep 1
	end_test_no_kamailio
}

kamcmd_ctl() {
	"${KAMCTL}" kamcmd -s "unixs:${KAMRUN}/kamailio_ctl" "$@"
}

htable_get() {
	kamcmd_ctl htable.get ctl "$1" 2>/dev/null | awk '/value/{ print $2; exit }'
}

# number of sockets of the http async worker towards the server in state $1
tcp_count() {
	find "/proc/${WPID}/fd" -type l -exec readlink {} + 2>/dev/null \
		| sed -n 's/^socket:\[\([0-9]*\)\]$/\1/p' > "${TMPDIR_UNIT}/inodes"
	awk -v st="$1" -v port=":${SRVPORTHEX}" '
		FILENAME == ARGV[1] { want[$1] = 1; next }
		$4 == st && substr($3, length($3) - 4) == port && ($10 in want) { n++ }
		END { print n + 0 }' "${TMPDIR_UNIT}/inodes" /proc/net/tcp /proc/net/tcp6 2>/dev/null
}

# wait until ok + fail counters reach $1
wait_queries() {
	for _ in $(seq 1 300) ; do
		ok=$(htable_get ok)
		fail=$(htable_get fail)
		if [ $((${ok:-0} + ${fail:-0})) -ge "$1" ] ; then
			return 0
		fi
		sleep 0.1
	done
	return 1
}

print_row() {
	printf "%-6s %5s %5s %6s %10s   %s\n" "$1" "$(htable_get ok)" "$(htable_get fail)" \
		"$(tcp_count 01)" "$(tcp_count 08)" "$(cat "${TMPDIR_UNIT}/stats")"
}

ret=0

# check openssl is available
if ! (which openssl > /dev/null 2>&1); then
	echo "openssl not found, not run"
	end_test_no_kamailio
fi

# --- generate a throwaway CA and a server certificate for localhost ---
cd "${TMPDIR_UNIT}" || exit 1
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=kamailio-test-ca" \
	-keyout ca.key -out ca.crt 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj "/CN=localhost" \
	-keyout srv.key -out srv.csr 2>/dev/null
echo "subjectAltName=DNS:localhost,IP:127.0.0.1" > srv.ext
openssl x509 -req -in srv.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 1 \
	-extfile srv.ext -out srv.crt 2>/dev/null
mkdir ca
cp ca.crt "ca/$(openssl x509 -hash -noout -in ca.crt).0"
cd - > /dev/null || exit 1
if [ ! -f "${TMPDIR_UNIT}/srv.crt" ]; then
	echo "no server certificate generated, not run"
	end_test_no_kamailio
fi

python3 http_server.py "${TMPDIR_UNIT}/srv.crt" "${TMPDIR_UNIT}/srv.key" "${TMPDIR_UNIT}/stats" \
	> "${TMPDIR_UNIT}/http_server.log" 2>&1 &
SRVPID=$!

# the server writes its stats file once it is listening
for _ in $(seq 1 100) ; do
	if [ -s "${TMPDIR_UNIT}/stats" ] ; then
		break
	fi
	if ! kill -0 "${SRVPID}" 2>/dev/null ; then
		echo "https server exited (port 8443 already in use?), aborting"
		cat "${TMPDIR_UNIT}/http_server.log"
		SRVPID=""
		ret=1
		end_test_no_kamailio
	fi
	sleep 0.1
done
if [ ! -s "${TMPDIR_UNIT}/stats" ] ; then
	echo "https server not ready after 10s, aborting"
	cat "${TMPDIR_UNIT}/http_server.log"
	ret=1
	end_test_no_kamailio
fi

echo "--- start kamailio -f ./${CFGFILE}"
# shellcheck disable=SC2086
${KAMBIN} -P "${KAMPID}" -w "${KAMRUN}" -Y "${KAMRUN}" -f "./${CFGFILE}" -a no -E ${KAMPRM} \
	-A "HAC_CA_PATH=\"${TMPDIR_UNIT}/ca\"" > "${LOGFILE_UNIT}" 2>&1
ret=$?
sleep 1
if [ "${ret}" -ne 0 ] ; then
	echo "failed to start kamailio"
	cat "${LOGFILE_UNIT}"
	end_test
fi

WPID=$(kamcmd_ctl core.psx | awk '/PID:/{ p=$2 } /Http Async Worker/{ print p; exit }')
if [ -z "${WPID}" ] ; then
	echo "http async worker not found, aborting"
	ret=1
	end_test
fi

# libcurl version loaded by the worker
CURLLIB=$(awk '/libcurl/{ print $NF; exit }' "/proc/${WPID}/maps")
CURLVER=$(LC_ALL=C tr -c '\040-\176' '\n' < "${CURLLIB}" | grep -o 'libcurl/[0-9][0-9.]*' | head -n 1 | cut -d/ -f2)
echo "--- libcurl ${CURLVER} (${CURLLIB})"
if [ -z "${CURLVER}" ] ; then
	echo "--- warning: libcurl version unknown, assuming >= 8.18"
fi
CURLMAJOR=$(echo "${CURLVER}" | cut -d. -f1)
CURLMINOR=$(echo "${CURLVER}" | cut -d. -f2)
NOTE=""
if [ "${CURLMAJOR}" = "8" ] && [ "${CURLMINOR}" = "21" ] ; then
	echo "libcurl 8.21.x does not report shutdown sockets to the application (curl GH #22282), not run"
	ret=0
	end_test
fi
if [ -n "${CURLMAJOR}" ] && { [ "${CURLMAJOR}" -lt 8 ] || { [ "${CURLMAJOR}" -eq 8 ] && [ "${CURLMINOR}" -lt 18 ]; }; } ; then
	NOTE="libcurl < 8.18 closes retired connections by itself, this test cannot detect the issue"
	echo "--- note: ${NOTE}"
fi

printf "%-6s %5s %5s %6s %10s   %s\n" round ok fail ESTAB CLOSE_WAIT server
print_row start
expected=0
closewait=""
for r in $(seq 1 "${ROUNDS}") ; do
	expected=$((expected + NQUERIES))
	kamcmd_ctl htable.seti ctl burst "${NQUERIES}" > /dev/null
	if ! wait_queries "${expected}" ; then
		echo "burst of round ${r} did not complete, aborting"
		ret=1
		end_test
	fi
	expected=$((expected + NQUERIES))
	kamcmd_ctl htable.seti ctl trickle "${NQUERIES}" > /dev/null
	if ! wait_queries "${expected}" ; then
		echo "queries of round ${r} did not complete, aborting"
		ret=1
		end_test
	fi
	# let the server see the retired connections and close them
	sleep 2
	row=$(print_row "${r}")
	echo "${row}"
	closewait="${closewait} $(echo "${row}" | awk '{ print $5 }')"
done

ok=$(htable_get ok)
fail=$(htable_get fail)
closed=$(sed -n 's/.*closed=\([0-9]*\).*/\1/p' "${TMPDIR_UNIT}/stats")
lastclosewait=${closewait##* }

if [ "${ok}" != "${expected}" ] || [ "${fail}" != "0" ] ; then
	echo "error: ${ok} of ${expected} queries succeeded, ${fail} failed"
	ret=1
	end_test
fi
if [ "${closed:-0}" -le "${MAXCLOSEWAIT}" ] ; then
	echo "error: only ${closed:-0} connections were retired, the test cannot detect the issue"
	ret=1
	end_test
fi
if [ "${lastclosewait}" -gt "${MAXCLOSEWAIT}" ] ; then
	echo "error: ${lastclosewait} sockets in CLOSE_WAIT after ${ROUNDS} rounds (max ${MAXCLOSEWAIT}), per round:${closewait}"
	ret=1
	end_test
fi

echo "--- ok: ${lastclosewait} sockets in CLOSE_WAIT after ${closed} retired connections"
[ -n "${NOTE}" ] && echo "--- note: ${NOTE}"
ret=0
end_test
