# Dynamic watch faces on ILI9341

The Flutter Market import sheet accepts a JSON file or pasted JSON. Canvas Studio can
turn a gallery image into a resizable sprite or a full-screen background, then upload
the current design over BLE. The five bundled anime faces appear in the quick install
row and in `EXE401_Database/market_templates.json` for database seeding.

The JSON fields are `title`, `background` (an RGB565 integer), optional
`background_bitmap`, and `elements` (at most 12). Supported element types are
`clock`, `calendar`, `text`, `superText`, `geometry` (`rect`, `roundrect`,
`circle`, `ellipse`, `triangle`, `diamond`, `star`, `cross`, `line`, `cube`),
and `bitmap`. A bitmap is 1-bit, MSB-first, with rows padded to whole bytes. A
320×240 background is 9,600 bytes, or 19,200 hexadecimal characters. The LCD
displays RGB565 color for the solid background and per-element foreground, but the
bitmap itself is monochrome and is tinted with its element color. A full-color
320×240 RGB565 image would require 153,600 bytes and is not supported by this
format or the current bitmap transfer path.

Text elements accept `s` from 1 to 20 (6×8 pixel font cells at that scale).
With `"a": true`, `s` is the maximum scale and the font automatically grows or
shrinks to fit W/H. `calendar` reads the tasks stored for the current weekday
and shows their times and labels. `superText` shows the DS3231 RTC chip's
temperature in Celsius, or `--C` if the RTC is unavailable. It does not
represent room temperature. Weekly schedule tasks must first be synced to the
ESP32 from the app's Schedule screen.
The Schedule screen's sync button sends all seven weekdays in one operation.

The app sends image data in 128-byte chunks inside JSON commands under 512 bytes.
Each image chunk and the complete image carry CRC16-CCITT checksums. The ESP32
acknowledges each chunk by request ID and verifies checksums. Bitmap data is
stored in LittleFS on the `spiffs` flash partition; small layout metadata stays
in NVS. The saved face is restored at boot. `LAYOUT_BG_COMMIT` reports
`flash_write_failed` if the filesystem cannot store the staged image.
After installing a firmware build containing this protocol once, face changes
do not require another firmware upload.

Run `python Backend_EXE401/build_anime_watch_faces.py` from the project root to
regenerate the five sample JSON files and their Market entries. Run
`python Backend_EXE401/seed_tft_market.py` with MongoDB available to upsert the
bundled entries into an existing database.
