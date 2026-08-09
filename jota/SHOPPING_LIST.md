# Shopping list — parts to buy for the voice-note build

You already have the **3D printer + filament**, so this covers only the
electronics that don't come on the board. The Waveshare board already includes
the **display, microphone, USB-C, LiPo charger, RTC, and the two side
buttons** — those are NOT bought separately.

Prices captured **2026-07-27**. **Everything from AliExpress** (single vendor —
amazon.sa does not carry the Waveshare board, so AliExpress is the only place
that covers the whole list and ships to KSA). Currency: SAR pegged ~3.75 to USD.

| # | Item | Why you need it | Price (USD) | Price (SAR) | Link |
|---|------|-----------------|------------:|------------:|------|
| 1 | **Waveshare ESP32-S3 1.54" e-Paper AIoT Board** (`ESP32-S3-ePaper-1.54`) | The core — MCU, e-paper, mic, SD slot, charger, buttons | ~$27.00 | ~101 | [AliExpress](https://www.aliexpress.com/item/1005010074101353.html) |
| 2 | **503035 LiPo 3.7 V ~500 mAh** — *get the JST PH 1.25 mm connector version* | Powers the device; drops into the floor bay | ~$4.50 | ~17 | [AliExpress](https://www.aliexpress.com/item/32816711041.html) |
| 3 | **microSD card 32 GB** (SanDisk / Samsung) | The archive — holds the full-quality WAV of every note. The phone only ever receives a compressed copy | ~$4.50 | ~17 | [AliExpress microSD](https://www.aliexpress.com/w/wholesale-sandisk-32gb-micro-sd.html) |
| 4 | *(Optional)* **Mini 8 Ω 1 W speaker, JST PH 1.25 mm** | Only if you want audio **playback** (recording works without it) | ~$2.00 | ~8 | [AliExpress 8Ω mini speaker](https://es.aliexpress.com/w/wholesale-8-ohm-mini-speaker.html) |

> **Charging:** the board has a built-in LiPo charger — plug USB-C into the
> device to charge the battery. No separate charger needed.

> **Nothing here is needed for the phone link.** Bluetooth LE is built into the
> ESP32-S3, so there is no radio module to buy — and because the phone does the
> transcription, there is no server to pay for either.

## Totals

- **Core build (items 1–3):** ≈ **$36.00** (~**SAR 135**)
- **With optional speaker (items 1–4):** ≈ **$38.00** (~**SAR 143**)

> Prices exclude shipping. AliExpress board shipping to KSA is typically free–$3;
> factor a few SAR more if not on a free-shipping seller.

## ⚠️ Before you order — check these

1. **Battery connector & polarity.** The board expects a **1.25 mm JST (MX1.25)**
   lead. Buy the LiPo with the **PH 1.25 mm** connector, and **verify +/- polarity
   matches the board silkscreen before plugging in** — vendors wire these
   inconsistently and reversed polarity will kill the board. If unsure, buy a
   bare-lead cell and crimp your own connector.
2. **Battery size.** Confirm the listing's real envelope is within
   **37 × 30.5 × 5.3 mm** (`BATT_L/W/T` in `jota/src/params.py`) — some "503035"
   packs run larger with the protection circuit.
3. **Speaker.** Waveshare lists an onboard audio codec but the speaker output may
   be a header, not a fitted speaker. Confirm on the product page; the case has a
   16 × 5 mm speaker bay + grille if you add one.
4. **Header removal.** The stock 2×6 female expansion header must be desoldered to
   fit the case (see `README.md` assembly step 1) — no purchase, just a soldering
   iron.
5. **You can start without the card.** The firmware currently serves notes
   synthesised in flash, so the device, the BLE link and the phone app can all
   be built and tested before the microSD arrives. The card is only needed once
   notes have to survive a power-off.

## Sources (all AliExpress)
- [Waveshare ESP32-S3-ePaper-1.54 — AliExpress](https://www.aliexpress.com/item/1005010074101353.html) ([official spec ref](https://www.waveshare.com/esp32-s3-epaper-1.54.htm))
- [503035 LiPo 500 mAh — AliExpress](https://www.aliexpress.com/item/32816711041.html)
- [microSD 32 GB — AliExpress](https://www.aliexpress.com/w/wholesale-sandisk-32gb-micro-sd.html)
- [8 Ω mini speaker — AliExpress](https://es.aliexpress.com/w/wholesale-8-ohm-mini-speaker.html)
</content>
</invoke>
