#!/usr/bin/env python3
"""Drive Jota's BLE service straight from a laptop, with no phone involved.

The app has only ever talked to fakes, so when a real sync stalls there is no
way to tell whether the firmware or the Flutter code is at fault. This walks
the exact sequence in firmware/docs/ble-service.md and prints every step, so
the answer is one run away instead of a guess.

    .venv/bin/python jota/tools/ble_probe.py            # status + index only
    .venv/bin/python jota/tools/ble_probe.py --fetch    # pull the audio too

If this completes and the app still stalls, the bug is in the app.
"""

import argparse
import asyncio
import binascii
import json
import sys
import time
import uuid

from bleak import BleakClient, BleakScanner

BASE = "4a6f7461-1e5f-4b2a-9c33-%012d"
AUTH, STATUS, INDEX, FETCH, DATA, ACK, TAGS, CLOCK = (BASE % n for n in range(1, 9))
SVC = BASE % 0

# This laptop stands in for a phone, so it needs an app id like one. Stable
# across runs, so the second run exercises the silent-reconnect path.
APP_ID = str(uuid.uuid5(uuid.NAMESPACE_DNS, "jota-ble-probe"))


def log(step, msg):
    print(f"  {step:<9} {msg}", flush=True)


async def find(timeout):
    print(f"scanning {timeout}s for a Jota…", flush=True)
    d = await BleakScanner.find_device_by_filter(
        lambda dev, ad: SVC in (ad.service_uuids or []),
        timeout=timeout,
    )
    if not d:
        sys.exit("no Jota advertising. Is the board on, and is it advertising?")
    print(f"found {d.name or '?'}  {d.address}\n", flush=True)
    return d


async def status(c):
    raw = await c.read_gatt_char(STATUS)
    s = json.loads(raw.decode(errors="replace"))
    log("status", json.dumps(s))
    return s


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--code", help="six digits from the PAIR screen")
    ap.add_argument("--fetch", action="store_true", help="pull the audio too")
    ap.add_argument("--ack", action="store_true",
                    help="ack what arrives (the device then forgets the note)")
    ap.add_argument("--tags", metavar="A,B,C",
                    help="write this tag list to the device, then read it back")
    ap.add_argument("--forget", action="store_true",
                    help="ask the device to forget this phone, then stop")
    ap.add_argument("--timeout", type=float, default=12.0)
    a = ap.parse_args()

    dev = await find(a.timeout)
    async with BleakClient(dev, timeout=20.0) as c:
        log("connect", "up")

        s = await status(c)

        # ---- auth ---------------------------------------------------------
        # status is readable unauthenticated ON PURPOSE, so a successful read
        # proves nothing. Read status.authed. This is the exact bug that had
        # the app reporting "all caught up" while notes sat on the device.
        if not s.get("authed"):
            body = {"app": APP_ID}
            if a.code:
                body["code"] = a.code
            await c.write_gatt_char(AUTH, json.dumps(body).encode(), response=True)
            log("auth", f"sent {json.dumps(body)}")
            await asyncio.sleep(0.6)
            s = await status(c)
            if not s.get("authed"):
                print("\nNOT AUTHED. If the panel is showing a code, re-run with"
                      "\n  --code <the six digits on the panel>\n")
                return
        log("auth", "authenticated")

        # ---- forget -------------------------------------------------------
        # Only the owner may ask, which is why it rides on `auth`.
        if a.forget:
            await c.write_gatt_char(
                AUTH, json.dumps({"app": APP_ID, "forget": True}).encode(),
                response=True)
            await asyncio.sleep(0.5)
            s = await status(c)
            log("forget", "bond cleared" if not s.get("owned")
                          else "STILL OWNED - the device ignored it")
            return

        # ---- clock --------------------------------------------------------
        # The device has no way to learn the time by itself.
        await c.write_gatt_char(
            CLOCK, json.dumps({"epoch": int(time.time())}).encode(), response=True
        )
        log("clock", "set")

        # ---- tags ---------------------------------------------------------
        # The phone owns the tag list; the device just holds a copy to offer
        # after a recording. Reading it back is the only way to know what is
        # really on there, since the panel shows one at a time.
        raw = await c.read_gatt_char(TAGS)
        log("tags", f"device holds: {raw.decode(errors='replace')}")
        if a.tags:
            want = [t.strip() for t in a.tags.split(",") if t.strip()]
            await c.write_gatt_char(TAGS, json.dumps(want).encode(), response=True)
            await asyncio.sleep(0.4)
            raw = await c.read_gatt_char(TAGS)
            log("tags", f"after write:  {raw.decode(errors='replace')}")

        # ---- index --------------------------------------------------------
        raw = await c.read_gatt_char(INDEX)
        log("index", f"{len(raw)} bytes")
        print(f"           {raw.decode(errors='replace')}")
        notes = json.loads(raw.decode(errors="replace"))
        log("index", f"parsed {len(notes)} note(s)")
        if not notes:
            print("\nThe index is EMPTY. Nothing to fetch — this is the whole"
                  "\nreason a sync can end saying 'all caught up'.\n")
            return

        if not a.fetch:
            print("\nIndex is good. Re-run with --fetch to pull the audio.\n")
            return

        # ---- fetch / data / ack -------------------------------------------
        for n in notes:
            got = bytearray()
            done = asyncio.Event()
            want = n["bytes"]

            def on_data(_, chunk, got=got, want=want, done=done):
                got.extend(chunk)
                if len(got) >= want:
                    done.set()

            await c.start_notify(DATA, on_data)   # BEFORE fetch, always
            t0 = time.perf_counter()
            await c.write_gatt_char(
                FETCH, json.dumps({"id": n["id"], "offset": 0}).encode(),
                response=True,
            )
            log("fetch", f"id={n['id']} want={want} bytes")
            try:
                await asyncio.wait_for(done.wait(), timeout=90)
            except asyncio.TimeoutError:
                log("data", f"TIMED OUT with {len(got)}/{want} bytes")
                await c.stop_notify(DATA)
                return
            dt = time.perf_counter() - t0
            await c.stop_notify(DATA)
            log("data", f"{len(got)} bytes in {dt:.1f}s "
                        f"({len(got)/dt/1024:.1f} KB/s)")

            open(f"/tmp/jota-note-{n['id']}.bin", "wb").write(bytes(got))
            log("bytes", f"first16={got[:16].hex()} last16={got[-16:].hex()} "
                        f"chunks~{len(got)}B saved /tmp/jota-note-{n['id']}.bin")
            crc = f"{binascii.crc32(bytes(got)) & 0xffffffff:08x}"
            ok = crc == n.get("crc", "").lower()
            log("crc", f"{crc} vs {n.get('crc')} — {'MATCH' if ok else 'MISMATCH'}")
            if not ok:
                return
            if a.ack:
                await c.write_gatt_char(
                    ACK, json.dumps({"id": n["id"], "crc": crc}).encode(),
                    response=True,
                )
                log("ack", "sent")

        await status(c)
        print("\nThe firmware side works end to end.\n")


asyncio.run(main())
