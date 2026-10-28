# Verification of the actual PlatformIO project

Date: 2026-10-17

Updated and compiled project:
`C:\EXE401_WEDAPP_PROJECT_REPORT\260911-122138-esp32doit-devkit-v1`

The earlier edits were in `App_EXE401\Firmware_ESP32`. The project above still contained the old Next/Back/BackLong handlers. Its original five source files were backed up under `before/src` before applying the changes. `navigation_changes.diff` compares those originals with the files now installed in that project; it is not a comparison against an unrelated backup. The workspace firmware copy has the same nine reviewed source/test file hashes.

## Changes

| Source file | Added | Removed |
| --- | ---: | ---: |
| src/Esp32Pj.ino | 367 | 274 |
| src/io_service.h | 3 | 1 |
| src/io_service.cpp | 19 | 16 |
| src/io_logic.h | 29 | 22 |
| src/input_latch.h | 8 | 0 |

Added tests: `test/input_latch_test.cpp`, `test/navigation_test.cpp`, `test/extract_navigation.ps1`, `test/run_input_tests.cmd`.

MODE36 cycles Clock/Pomodoro/Timer/Bluetooth regardless of the active sub-screen. SELECT35 cycles focus. OK34 activates the focused control through the same action dispatcher used by touch. The first input during an alarm or notification only dismisses it and silences the buzzer. Button presses use a 25 ms stable-level debounce; holds and releases do not generate additional actions. Counters update independently of the screen renderer. Focus outlines update without clearing the entire screen on each SELECT.

## Verification

Build command:

```powershell
& C:/Users/Admin/.platformio/penv/Scripts/platformio.exe run -d C:/EXE401_WEDAPP_PROJECT_REPORT/260911-122138-esp32doit-devkit-v1
```

Result: SUCCESS, exit code 0, 30.07 seconds. RAM: 45,056 / 327,680 bytes (13.8%). Flash: 1,351,945 / 2,097,152 bytes (64.5%). See `compile.log`. The ESP32-A2DP library emits its AudioTools include/install warning; it does not prevent this build.

Test command:

```powershell
cmd /c C:\EXE401_WEDAPP_PROJECT_REPORT\260911-122138-esp32doit-devkit-v1\test\run_input_tests.cmd
```

Result: exit code 0. All input/debounce/hold/release/buzzer tests passed. Navigation checks: 70, failures: 0. The navigation harness extracts production functions from this project's Esp32Pj.ino and runs them with simulated peripherals. Coverage includes screen cycling, focused actions, touch equivalence, background counters, pause fractions, phase transitions, millis rollover and notification dismissal. See `tests.log`.

After compilation, all nine installed source/test file hashes matched `manifest.json`. No `KeyEvent::Next`, `KeyEvent::Back` or `KeyEvent::BackLong` remained in active source files. The generated binary contains both `NAV_MODE36_SELECT35_OK34` and `260911-122138-esp32doit-devkit-v1/src/Esp32Pj.ino`, confirming its source project.

Esp32Pj.ino SHA-256 before:
`1233649fc21cd1bc33d937267a5553721ae36827025bbc09ae15900931c09ab4`

Esp32Pj.ino SHA-256 after:
`75e2ba0302cf70e5439f3918d7f7bebc1327502db019f0dbd67dc3ed4f56aefa`

Generated firmware.bin SHA-256:
`5b31a48d9183515e3a9b38e887d955ffe3c7c6f239d615653e54d56587cb5db9`

## Hardware limits

No upload or physical-board test was performed in this change. Actual GPIO bounce, touch calibration, visible focus/flicker, buzzer sound, BLE/audio playback and RTC/NVS behavior still require verification on the connected ESP32. The compile and host tests do not establish those hardware results.
