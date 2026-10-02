# http_async_client - Close Connections Retired By libcurl #

Summary: http_async_client - close pooled TLS connections retired by libcurl

libcurl may report sockets through CURLMOPT_SOCKETFUNCTION for its own internal
easy handle, e.g., while it does the graceful TLS shutdown of a connection that
left its pool. If http_async_client does not watch them, the shutdown is never
driven with libcurl >= 8.18: each retired connection stays open in the Http Async
Worker (CLOSE_WAIT once the server closes it), with its TLS state. See kamailio
GH #4977 and PR #4979.

Following tests are done:

  * run kamailio with kamailio-thacxx0007.cfg against a local HTTPS server
  (http_server.py, with a throwaway CA and certificate generated with openssl)
  * in each round, send a burst of 40 concurrent queries, then 40 one at a time,
  so that libcurl retires the surplus idle connections from its pool
  * after each round, count the sockets of the Http Async Worker towards the
  server that are in CLOSE_WAIT, from /proc/PID/fd and /proc/net/tcp*
  * fail if more than 10 are left after 4 rounds, if any query failed, or if
  the server saw fewer than 10 connections closed

libcurl requirement:

  * >= 8.18 is needed to detect the issue; with older versions libcurl closes
  the connections by itself, the test passes and prints a note about it (e.g.,
  Debian 13 has 8.14)
  * 8.21.x is not run: it never reports those sockets to the application, so
  they are left open whatever the module does (curl GH #22282, fixed in 8.22.0)
