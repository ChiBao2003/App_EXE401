# OK GPIO34 investigation

Updated project: `C:\EXE401_WEDAPP_PROJECT_REPORT\260911-122138-esp32doit-devkit-v1`.

## Source changes

The mapping remains MODE36 / SELECT35 / OK34. No unproven change to the debounce threshold or OK action was made. Added diagnostic coverage for sampled GPIO34 press/release, debounced level, generated event, queue enqueue/rejection, `readKeyEvent()` dequeue, dispatcher entry, focus activation and resulting screen/session state. Each queued key has an ID and sample timestamp, so enqueue/dequeue delay can be measured. UART printing runs outside the 5 ms sampler, through a separate bounded diagnostic queue.

Files updated: `src/Esp32Pj.ino`, `src/io_service.cpp`, `src/io_service.h`, `src/io_logic.h`, `test/navigation_test.cpp`, `test/extract_navigation.ps1`. `input_latch.h` remains unchanged; it gates touch input, while physical GPIO34 uses `DebouncedButton` through `NavigationButtons`.

The before/after diff against this project's actual previous files is `ok34_changes.diff`. Backups are in `before/`; hashes are in `manifest.json`. All six installed source/test hashes were verified after copying.

## Compilation and host verification

Compile: SUCCESS, exit code 0, 34.84 seconds (`compile.log`). RAM: 45,080 / 327,680 bytes, 13.8%. Flash: 1,353,729 / 2,097,152 bytes, 64.6%. The existing ESP32-A2DP AudioTools warning remains.

Host tests run from the same project: 87 checks, zero failures, plus the input-latch/debounce/buzzer tests (`tests.log`). Production functions are extracted from both `io_service.cpp` and `Esp32Pj.ino`; GPIO, UART and FreeRTOS queue primitives are simulated. Verified SELECT35 focuses Coding, debounced OK34 confirms Coding and focuses START/PAUSE, release/hold adds no action, the next OK34 starts the countdown, and queue diagnostics cannot block key delivery. These results do not prove electrical or RTOS behavior on the board.

## Actual hardware observations

Windows initially enumerated USB-SERIAL CH340 on COM5 with status OK and ConfigManagerErrorCode 0. A real capture at 115200 returned:

```text
[INPUT] MODE36=1 OK34=0 SELECT35=1 touch=1 mode=1
```

That capture then failed with `GetOverlappedResult failed (PermissionError(13, 'Access is denied.', None, 5))`; see `serial_before.log`. The user's physical button state at the time of that single sample has not been confirmed. A low sample alone does not identify the cause of the reported OK failure.

Uploading the new firmware through COM5 connected successfully to an ESP32-D0WD-V3 revision 3.1 and wrote the application up to the displayed 94%. It then lost the connection and failed with:

```text
Lost connection, retrying...
Cannot configure port, something went wrong.
PermissionError(13, 'Access is denied.', None, 5)
```

Upload exit code: 1. See `upload.log`. Subsequent enumeration returned no COM5/CH340 device. The new build has NOT been confirmed running on the ESP32, and the interrupted upload needs to be completed after the board reconnects. No actual GPIO34 press/release/queue/action trace from `OK34_TRACE_V1` has been obtained yet. Therefore the cause of the OK button failure remains unconfirmed.

Requested next hardware step: reconnect the ESP32, close any competing Serial Monitor, complete upload, then capture SELECT -> Coding -> OK -> OK. The expected stages are documented in `TRACE_GUIDE.md`; they are not fabricated observations.
