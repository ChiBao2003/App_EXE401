# ESP32 TFT synchronization

Hardware: ESP32 DOIT DevKit V1, ILI9341 320×240 RGB565 via MCUFRIEND_kbv,
DS3231, GPIO23 buzzer, MAX98357A I2S audio, buttons GPIO36/34/35.

Hardware labels are separate from source identifiers. Keep the existing
`EinkClockApp`, shared widget APIs and Android package ID compatible; replacing
parts of an identifier with the display text `TFT LCD` breaks Dart compilation.
The app smoke test imports `main.dart` to cover this integration boundary.
Remote Pomodoro commands select START/PAUSE through `setControlFocus(2)`, which
updates the saved screen focus before the physical action handler restores it.

Market and Studio share `lib/core/display/tft_layout.dart`: canonical element
coordinates, RGB565 palette, preview, validation and Floyd–Steinberg conversion.
Templates carry `background` plus 1–12 `elements`. Existing `bg_color` and
Studio object aliases are accepted on import. Studio saves its background,
colors and bitmap data locally and uploads canonical elements to Market.

Bitmap storage is limited to 128 bytes per element. Rows use `(width + 7) / 8`
bytes and MSB-first bits, including row padding. Studio reduces large photos
before encoding; changing bitmap dimensions requires selecting the photo again.
Firmware rejects malformed hexadecimal data and inconsistent dimensions before
passing a buffer to Adafruit_GFX. Bitmap foreground uses the selected RGB565
color and background uses the template background.

Each confirmed request carries a unique root `rid`. Firmware includes it in
the ACK. App commands are serialized; disconnects, negative ACKs, wrong ACK
types and timeouts are errors. Progress advances after ACKs.
The firmware receives commands through a bounded FreeRTOS queue so a new BLE
write cannot overwrite the previous pending command while the LCD is drawing.

| Request | Response |
| --- | --- |
| LAYOUT_BEGIN / LAYOUT_ITEM / LAYOUT_COMMIT | layout_ack (phase, index, ok, rid) |
| SET_MODE / SET_THEME / GET_DISPLAY_STATE | display_state (mode, theme_id, color, custom, layout_count, ok, rid) |
| SYNC_SCHEDULE | schedule_ack (day, count, ok, rid) |
| SCHEDULE_BEGIN / SCHEDULE_ITEM / SCHEDULE_COMMIT | schedule_ack (day, count, ok, rid) |
| SET_POMO / POMO_CONTROL / GET_POMO_STATE | pomo_state (running, remaining, phase, task_type, work_min, break_min, ok, rid) |

Small schedules include both root and `params` fields for compatibility.
Larger schedules are staged one item per request, with at most 16 items/day and
48 ASCII characters/label. Only a validated commit writes `sch_<day>` in NVS.
The RTC scheduler runs independently of the selected screen, checks a complete
date/minute key, skips invalid RTC readings and signals all matching labels.
An empty day can be committed to remove its previous reminders.

The app starts/pauses/resets the physical Pomodoro timer and polls its confirmed
state. It sends the selected task type with configuration and selects mode 1
before starting. Theme colors affect the physical clock text and persist in NVS.

`Backend_EXE401/seed_tft_market.py` upserts the four built-in TFT templates using
the same `MONGO_URI` / `MONGO_DB_NAME` defaults as the backend. It preserves
community templates and other collections. Re-running it is safe.

Automated verification covers row padding, alpha handling, diffusion, invalid
bitmaps, seed bounds, ACK correlation, BLE packet limits, staged schedules,
rejected layout commits, Market install/import, Studio persistence/undo and
physical mode/theme controls. Both PlatformIO projects are compiled separately
to preserve their independent pre-existing behavior.

Physical checks still required: flash the matching firmware, install a template
over BLE, verify a bitmap on the LCD, schedule a reminder one minute ahead,
change theme/color, and start/pause Pomodoro. Build and simulated BLE results do
not establish that the attached LCD, RTC or buzzer has passed these checks.
