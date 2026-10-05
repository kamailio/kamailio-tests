#!/usr/bin/env python3
# HTTPS/1.1 keep-alive server, answering 200 to each request after 300 ms;
# usage: http_server.py <certfile> <keyfile> <statsfile>
import asyncio
import os
import ssl
import sys

stats = {"accepted": 0, "open": 0, "closed": 0, "requests": 0}

async def handle(reader, writer):
    stats["accepted"] += 1
    stats["open"] += 1
    try:
        while await reader.readline():
            while (await reader.readline()) not in (b"\r\n", b"\n", b""):
                pass
            stats["requests"] += 1
            await asyncio.sleep(0.3)
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
            await writer.drain()
    except (ConnectionError, ssl.SSLError):
        pass
    finally:
        stats["open"] -= 1
        stats["closed"] += 1
        writer.close()

async def write_stats():
    while True:
        with open(sys.argv[3] + ".tmp", "w") as f:
            f.write(" ".join(f"{k}={v}" for k, v in stats.items()))
        os.replace(sys.argv[3] + ".tmp", sys.argv[3])
        await asyncio.sleep(0.2)

async def main():
    ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ctx.load_cert_chain(sys.argv[1], sys.argv[2])
    srv = await asyncio.start_server(handle, "127.0.0.1", 8443, ssl=ctx,
                                     backlog=512)
    asyncio.create_task(write_stats())
    async with srv:
        await srv.serve_forever()

if __name__ == '__main__':
    asyncio.run(main())
