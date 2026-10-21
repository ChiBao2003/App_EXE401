# Verified hardware pin correction (2026-10-17)

Active project: `C:\EXE401_WEDAPP_PROJECT_REPORT\260911-122138-esp32doit-devkit-v1`.
User-provided working hardware test is the wiring reference; older summary pin assignments are superseded.

| Signal | Before | Verified |
| --- | --- | --- |
| LCD D4 | GPIO17 | GPIO16 |
| LCD D5 | GPIO16 | GPIO17 |
| Audio BCLK | GPIO19 | GPIO5 |
| Audio DIN / ESP DOUT | GPIO5 | GPIO19 |

LCD D0..D7: 12,13,26,25,16,17,27,14.
LCD RD/WR/RS/CS/RST: 2,4,15,33,32.
Audio LRC: 18. RTC SDA/SCL: 21/22. Buzzer: 23.
Buttons: MODE=34, ACTION1=35, ACTION2=36 (same physical pins as OK/BACK/NEXT in hardware test; application functions differ).

LCD driver is fixed to ILI9341 (0x9341), landscape rotation 1. Old lcd_idx NVS values and MODE-at-boot no longer change it. Legacy Serial/BLE driver commands report the fixed driver without changing it.

The project uses MCUFRIEND GPIO writes, not LovyanGFX I2S parallel output; the LCD does not allocate an I2S peripheral. The I2S0/I2S1 split in the LovyanGFX hardware test is therefore not required here.

Changes are in src/Esp32Pj.ino and the ESP32 section of lib/MCUFRIEND_kbv/utility/mcufriend_shield.h. Local library files are retained across dependency reinstalls. PSRAM remains disabled. Existing LCD bus delay and touch isolation repairs are retained.

Pre-change source/header backups have suffix `.before_verified_pin_fix`.
Physical display confirmation is needed after upload.

## Button and touch correction

The display is now confirmed visible by the owner. Remaining input problems were addressed in the active firmware:
- Debounce buttons for 45 ms; rearm only after 120 ms of stable release. Ignore buttons held at boot until released.
- Independent button state replaces the shared 300 ms level-triggered repeat logic.
- Touch requires a new contact after 150 ms release, 80 ms press qualification, and three spatially consistent samples. It no longer repeats while held.
- Preserve physical button assignments: GPIO34 MODE, GPIO35 confirm/start/pause, GPIO36 choose next item in a picker or reset during a run.
- Add selected-item borders and picker hints. GPIO35 now confirms task and timer choices.
- Serial INPUTS prints raw pin levels (released=1). TOUCH OFF / TOUCH ON toggles touch and saves that choice, allowing diagnosis of uncalibrated touch without losing button control.
- Logs distinguish physical button, touch and BLE mode requests.

Input latch C++ tests passed for boot hold, long hold, bounce, release/repress, independent buttons, and millis rollover. Firmware build passed (flash 1,349,961 bytes; RAM 45,008 bytes). Upload attempt failed because Windows could not configure COM7 (device error 433). This input revision is not yet confirmed flashed or tested on hardware.

## IO service revision (supersedes prior button mapping)

Verified hardware-test semantics: NEXT=GPIO36, OK=GPIO34, BACK=GPIO35. NEXT advances highlighted picker items, or changes mode outside a picker. OK confirms a picker choice, starts/pauses a run, changes the clock theme, or plays Bluetooth audio. BACK resets a run/returns from a picker; holding BACK for 1 second returns to Clock. Any button dismisses an active notification/alarm.

`io_service.cpp` samples buttons every 5 ms in a separate FreeRTOS task and queues accepted events. It owns GPIO23 LEDC PWM, initialized once at 8-bit resolution, 50 percent duty for the passive buzzer described by the working test. Beep timing runs in the same independent task and continues while the main task draws. Frequency changes do not reattach PWM; silence uses duty zero. Notification beeps no longer replace an active alarm sequence. Serial parsing is bounded and nonblocking.

Serial diagnostics at 115200: `INPUTS`, `BEEP` (three 100 ms pulses at 2 kHz), `STOP`, `TOUCH OFF`, `TOUCH ON`. Startup prints actual input levels and PWM initialization status. Released buttons should read 1; GPIO34/35/36 still require the external pull-up resistors in the hardware design.

C++ tests passed for debounce, held-at-boot, independent buttons, BACK short/long with no extra short event, beep count/timing, stopping mid-beep, late tick catch-up and millis rollover. Hardware upload and physical verification are recorded separately below.

Final IO revision build passed (1,351,893 bytes flash; 45,016 bytes static RAM). Upload at 460800 encountered serial corruption; upload at 115200 completed successfully with flash hash verification. Active platformio.ini now uses 115200 upload speed. Physical confirmation of the buttons and audible buzzer remains pending.

On-device boot verification succeeded: ILI9341 ID read 0x9341; IO task running; LEDC GPIO23 initialized OK; BLE startup completed; INPUTS and BEEP commands acknowledged. Both startup and idle GPIO samples showed NEXT36=1, OK34=0, BACK35=1. Under the supplied active-low wiring, OK34 remains logically held, so no new OK press is emitted until a stable release. Physical press/release sampling and audible confirmation are required to distinguish a held/shorted input from different hardware polarity. Logs: ESP32_IO_BOOT_LOG.txt and ESP32_BUTTON_SAMPLE_LOG.txt.
