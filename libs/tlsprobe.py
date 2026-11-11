#!/usr/bin/env python3
#
# tlsprobe.py - small TLS/SIP client used by ttlsxx unit tests
#
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
# Only the Python standard library is used, so it runs in the
# kamailio-tests docker images without extra packages.
#
# Commands (all exit 0 on success, non-zero on failure):
#
#   options    HOST PORT  - TLS handshake, send SIP OPTIONS, wait for replies
#              [--sni NAME] [--cert F --key F] [--ca F]
#              [--frag N --delay MS]  write the request in N-byte TLS records
#              [--pipeline K]         send K OPTIONS in a single write
#              [--expect CODE]        required status code (default 200)
#              [--header NAME]        print value of NAME from the last reply
#   raw        HOST PORT DATA          plain TCP, send DATA (python escapes), close
#   partialhello HOST PORT NBYTES [--sni NAME]
#                                      send the first NBYTES of a real
#                                      ClientHello, then close
#   rawhello   HOST PORT [--sni S] [--sni-len N] [--list-delta D]
#              [--name-delta D]        hand-built ClientHello with an
#                                      arbitrary SNI extension, then close
#   flood      HOST PORT N [--mode M]  N concurrent connections, M one of:
#                                      handshake (complete TLS then close),
#                                      idle (TCP connect, close), half (send
#                                      ClientHello, never read, close)

import argparse
import socket
import ssl
import sys
import threading
import time
import uuid

TIMEOUT = 5.0


def mk_ctx(args):
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    if getattr(args, "ca", None):
        ctx.load_verify_locations(args.ca)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_REQUIRED
    else:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    if getattr(args, "cert", None):
        ctx.load_cert_chain(args.cert, args.key)
    return ctx


def tls_connect(args, host, port):
    raw = socket.create_connection((host, port), timeout=TIMEOUT)
    ctx = mk_ctx(args)
    return ctx.wrap_socket(raw, server_hostname=getattr(args, "sni", None))


def sip_options(host, port, n=1):
    msg = ""
    for i in range(n):
        tag = uuid.uuid4().hex[:10]
        msg += (
            f"OPTIONS sip:{host}:{port} SIP/2.0\r\n"
            f"Via: SIP/2.0/TLS 127.0.0.1:15061;branch=z9hG4bK{tag}{i};rport\r\n"
            "Max-Forwards: 70\r\n"
            f"From: <sip:tester@test.invalid>;tag={tag}\r\n"
            f"To: <sip:{host}:{port}>\r\n"
            f"Call-ID: {tag}-{i}@tlsprobe\r\n"
            f"CSeq: {i + 1} OPTIONS\r\n"
            "Content-Length: 0\r\n\r\n"
        )
    return msg.encode()


def read_replies(s, want):
    buf = b""
    replies = []
    deadline = time.time() + TIMEOUT
    while len(replies) < want and time.time() < deadline:
        try:
            chunk = s.recv(65535)
        except socket.timeout:
            break
        if not chunk:
            break
        buf += chunk
        while b"\r\n\r\n" in buf:
            head, buf = buf.split(b"\r\n\r\n", 1)
            replies.append(head.decode(errors="replace"))
    return replies


def header_value(reply, name):
    for line in reply.split("\r\n")[1:]:
        k, _, v = line.partition(":")
        if k.strip().lower() == name.lower():
            return v.strip()
    return None


def cmd_options(args):
    try:
        s = tls_connect(args, args.host, args.port)
    except (ssl.SSLError, OSError) as e:
        print(f"handshake failed: {e}")
        return 2
    data = sip_options(args.host, args.port, args.pipeline)
    try:
        if args.frag:
            for i in range(0, len(data), args.frag):
                s.sendall(data[i:i + args.frag])
                time.sleep(args.delay / 1000.0)
        else:
            s.sendall(data)
        replies = read_replies(s, args.pipeline)
    except (ssl.SSLError, OSError) as e:
        print(f"connection failed: {e}")
        return 3
    finally:
        s.close()
    if len(replies) != args.pipeline:
        print(f"got {len(replies)} replies, expected {args.pipeline}")
        return 4
    for r in replies:
        status = r.split("\r\n", 1)[0]
        if not status.startswith(f"SIP/2.0 {args.expect} "):
            print(f"unexpected status: {status}")
            return 5
    if args.header:
        print(header_value(replies[-1], args.header) or "")
    return 0


def cmd_raw(args):
    data = args.data.encode().decode("unicode_escape").encode("latin-1")
    try:
        s = socket.create_connection((args.host, args.port), timeout=TIMEOUT)
        s.sendall(data)
        time.sleep(0.2)
        s.close()
    except OSError as e:
        print(f"raw send failed: {e}")
    return 0


def client_hello(sni=None):
    """Produce the bytes of a genuine ClientHello using memory BIOs."""
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    inc, out = ssl.MemoryBIO(), ssl.MemoryBIO()
    obj = ctx.wrap_bio(inc, out, server_hostname=sni)
    try:
        obj.do_handshake()
    except ssl.SSLWantReadError:
        pass
    return out.read()


def crafted_hello(sni, sni_list_delta=0, sni_name_delta=0):
    """Hand-built TLS 1.2 ClientHello, so the SNI extension can carry values
    a normal client library refuses to send (over-long, embedded NUL,
    inconsistent inner length fields)."""
    import os
    import struct

    def ext(etype, body):
        return struct.pack("!HH", etype, len(body)) + body

    name = struct.pack("!BH", 0, len(sni) + sni_name_delta) + sni
    sni_body = struct.pack("!H", len(name) + sni_list_delta) + name
    exts = (ext(0x0000, sni_body)
            + ext(0x000a, b"\x00\x04\x00\x17\x00\x1d")     # groups
            + ext(0x000b, b"\x01\x00")                      # point formats
            + ext(0x000d, b"\x00\x06\x04\x01\x08\x04\x04\x03"))  # sigalgs
    suites = b"\xc0\x2f\xc0\x30\xc0\x2b\x00\x9c"
    body = (b"\x03\x03" + os.urandom(32) + b"\x00"
            + struct.pack("!H", len(suites)) + suites + b"\x01\x00"
            + struct.pack("!H", len(exts)) + exts)
    hs = b"\x01" + struct.pack("!I", len(body))[1:] + body
    return b"\x16\x03\x01" + struct.pack("!H", len(hs)) + hs


def cmd_rawhello(args):
    sni = args.sni.encode().decode("unicode_escape").encode("latin-1")
    if args.sni_len:
        sni = (sni * (args.sni_len // max(len(sni), 1) + 1))[:args.sni_len]
    hello = crafted_hello(sni, args.list_delta, args.name_delta)
    try:
        s = socket.create_connection((args.host, args.port), timeout=TIMEOUT)
        s.sendall(hello)
        try:
            s.recv(4096)
        except OSError:
            pass
        s.close()
    except OSError as e:
        print(f"send failed: {e}")
    return 0


def cmd_partialhello(args):
    hello = client_hello(args.sni)
    n = min(args.nbytes, len(hello))
    try:
        s = socket.create_connection((args.host, args.port), timeout=TIMEOUT)
        s.sendall(hello[:n])
        time.sleep(0.2)
        s.close()
    except OSError as e:
        print(f"send failed: {e}")
    return 0


def cmd_flood(args):
    errors = []

    def one():
        try:
            if args.mode == "handshake":
                s = tls_connect(args, args.host, args.port)
                s.close()
            elif args.mode == "idle":
                s = socket.create_connection((args.host, args.port), timeout=TIMEOUT)
                s.close()
            else:
                s = socket.create_connection((args.host, args.port), timeout=TIMEOUT)
                s.sendall(client_hello())
                s.close()
        except (ssl.SSLError, OSError) as e:
            errors.append(str(e))

    threads = [threading.Thread(target=one) for _ in range(args.n)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    if args.mode == "handshake" and errors:
        print(f"{len(errors)} of {args.n} handshakes failed: {errors[0]}")
        return 1
    return 0


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    o = sub.add_parser("options")
    o.add_argument("host")
    o.add_argument("port", type=int)
    o.add_argument("--sni")
    o.add_argument("--cert")
    o.add_argument("--key")
    o.add_argument("--ca")
    o.add_argument("--frag", type=int, default=0)
    o.add_argument("--delay", type=int, default=50)
    o.add_argument("--pipeline", type=int, default=1)
    o.add_argument("--expect", default="200")
    o.add_argument("--header")

    r = sub.add_parser("raw")
    r.add_argument("host")
    r.add_argument("port", type=int)
    r.add_argument("data")

    h = sub.add_parser("partialhello")
    h.add_argument("host")
    h.add_argument("port", type=int)
    h.add_argument("nbytes", type=int)
    h.add_argument("--sni")

    w = sub.add_parser("rawhello")
    w.add_argument("host")
    w.add_argument("port", type=int)
    w.add_argument("--sni", default="a")
    w.add_argument("--sni-len", type=int, default=0)
    w.add_argument("--list-delta", type=int, default=0)
    w.add_argument("--name-delta", type=int, default=0)

    f = sub.add_parser("flood")
    f.add_argument("host")
    f.add_argument("port", type=int)
    f.add_argument("n", type=int)
    f.add_argument("--mode", default="handshake",
                   choices=["handshake", "idle", "half"])

    args = p.parse_args()
    return {
        "options": cmd_options,
        "raw": cmd_raw,
        "partialhello": cmd_partialhello,
        "rawhello": cmd_rawhello,
        "flood": cmd_flood,
    }[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
