#!/usr/bin/env python3
#
# mkmmdb.py - write a small MaxMind DB (GeoIP2-City style) for unit tests
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
# The real GeoLite2 databases need a MaxMind license and change over
# time, so geoip2 units build their own database with fixed records.
# Only the Python standard library is used.
#
# Usage: mkmmdb.py OUTFILE [--variant NAME]
#
# The records use documentation-only address ranges (RFC 5737, RFC 3849).
# The 'reload' variant changes the data of 192.0.2.0/24 so a unit can
# check that geoip2.reload picked up a new file.
#
# Format reference: https://maxmind.github.io/MaxMind-DB/

import argparse
import ipaddress
import struct
import sys
import time

RECORD_SIZE = 24


def city_record(city, cc, contc, tz, lat, lon, zip_code=None, regc=None,
                regn=None, metro=None):
    r = {
        "city": {"names": {"en": city}},
        "continent": {"code": contc},
        "country": {"iso_code": cc},
        "location": {"time_zone": tz, "latitude": float(lat),
                     "longitude": float(lon)},
    }
    if zip_code is not None:
        r["postal"] = {"code": zip_code}
    if regc is not None:
        r["subdivisions"] = [{"iso_code": regc, "names": {"en": regn}}]
    if metro is not None:
        r["location"]["metro_code"] = ("uint16", metro)
    return r


def records(variant):
    bucharest = city_record("Bucharest", "RO", "EU", "Europe/Bucharest",
                            44.4268, 26.1025, "010011", "B", "Bucuresti")
    if variant == "reload":
        bucharest = city_record("Cluj-Napoca", "RO", "EU", "Europe/Bucharest",
                                46.7712, 23.6236, "400001", "CJ", "Cluj")
    return [
        ("192.0.2.0/24", bucharest),
        ("198.51.100.0/25", city_record(
            "San Francisco", "US", "NA", "America/Los_Angeles",
            37.7749, -122.4194, "94107", "CA", "California", 807)),
        # no 'country', only 'registered_country': cc must fall back to it
        ("198.51.100.128/25", {"registered_country": {"iso_code": "JP"},
                               "continent": {"code": "AS"}}),
        ("2001:db8:1::/48", city_record(
            "Berlin", "DE", "EU", "Europe/Berlin", 52.52, 13.405, "10115",
            "BE", "Land Berlin")),
        # 203.0.113.0/24 and the rest of 2001:db8::/32 are left empty
    ]


# --- data section encoding -------------------------------------------------

def ctrl(type_num, size):
    if type_num <= 7:
        first = type_num << 5
        ext = b""
    else:
        first = 0
        ext = bytes([type_num - 7])
    if size < 29:
        return bytes([first | size]) + ext
    if size < 29 + 256:
        return bytes([first | 29]) + ext + bytes([size - 29])
    if size < 285 + 65536:
        return bytes([first | 30]) + ext + struct.pack("!H", size - 285)
    return bytes([first | 31]) + ext + struct.pack("!I", size - 65821)[1:]


def uint_bytes(v):
    out = b""
    while v:
        out = bytes([v & 0xff]) + out
        v >>= 8
    return out


def encode(v):
    if isinstance(v, tuple):          # explicitly typed value
        kind, val = v
        if kind == "uint16":
            b = uint_bytes(val)
            return ctrl(5, len(b)) + b
        if kind == "uint32":
            b = uint_bytes(val)
            return ctrl(6, len(b)) + b
        if kind == "uint64":
            b = uint_bytes(val)
            return ctrl(9, len(b)) + b
        raise ValueError(kind)
    if isinstance(v, bool):
        return ctrl(14, int(v))
    if isinstance(v, str):
        b = v.encode()
        return ctrl(2, len(b)) + b
    if isinstance(v, float):
        return ctrl(3, 8) + struct.pack("!d", v)
    if isinstance(v, int):
        b = uint_bytes(v)
        return ctrl(6, len(b)) + b
    if isinstance(v, dict):
        out = ctrl(7, len(v))
        for k, val in v.items():
            out += encode(k) + encode(val)
        return out
    if isinstance(v, list):
        out = ctrl(11, len(v))
        for val in v:
            out += encode(val)
        return out
    raise TypeError(type(v))


# --- search tree -------------------------------------------------------------

class Node:
    __slots__ = ("child", "data", "num")

    def __init__(self):
        self.child = [None, None]
        self.data = [None, None]
        self.num = 0


def bits_of(net):
    """Prefix bits of a network in the IPv6 tree (IPv4 lives at ::/96)."""
    if net.version == 4:
        value = int(net.network_address)
        plen = 96 + net.prefixlen
    else:
        value = int(net.network_address)
        plen = net.prefixlen
    return [(value >> (127 - i)) & 1 for i in range(plen)]


def build(entries):
    root = Node()
    data = b""
    for cidr, rec in entries:
        offset = len(data)
        data += encode(rec)
        node = root
        bits = bits_of(ipaddress.ip_network(cidr))
        for b in bits[:-1]:
            if node.child[b] is None:
                if node.data[b] is not None:
                    raise ValueError(f"{cidr} overlaps an existing network")
                node.child[b] = Node()
            node = node.child[b]
        last = bits[-1]
        if node.child[last] is not None or node.data[last] is not None:
            raise ValueError(f"{cidr} overlaps an existing network")
        node.data[last] = offset

    nodes = []
    queue = [root]
    while queue:
        n = queue.pop(0)
        n.num = len(nodes)
        nodes.append(n)
        queue.extend(c for c in n.child if c is not None)
    count = len(nodes)

    tree = b""
    for n in nodes:
        vals = []
        for i in (0, 1):
            if n.child[i] is not None:
                vals.append(n.child[i].num)
            elif n.data[i] is not None:
                vals.append(count + 16 + n.data[i])
            else:
                vals.append(count)          # no data
        tree += struct.pack("!I", vals[0])[1:] + struct.pack("!I", vals[1])[1:]
    return count, tree, data


def main():
    p = argparse.ArgumentParser()
    p.add_argument("outfile")
    p.add_argument("--variant", default="default",
                   choices=["default", "reload"])
    args = p.parse_args()

    count, tree, data = build(records(args.variant))
    meta = {
        "binary_format_major_version": ("uint16", 2),
        "binary_format_minor_version": ("uint16", 0),
        "build_epoch": ("uint64", int(time.time())),
        "database_type": "Kamailio-Test-City",
        "description": {"en": "kamailio-tests geoip2 test data"},
        "ip_version": ("uint16", 6),
        "languages": ["en"],
        "node_count": ("uint32", count),
        "record_size": ("uint16", RECORD_SIZE),
    }
    with open(args.outfile, "wb") as f:
        f.write(tree)
        f.write(b"\x00" * 16)
        f.write(data)
        f.write(b"\xab\xcd\xefMaxMind.com")
        f.write(encode(meta))
    return 0


if __name__ == "__main__":
    sys.exit(main())
