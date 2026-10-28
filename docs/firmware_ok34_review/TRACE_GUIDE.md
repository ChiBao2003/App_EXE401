# OK GPIO34 diagnostics

Project: `C:\EXE401_WEDAPP_PROJECT_REPORT\260911-122138-esp32doit-devkit-v1`

Mapping remains MODE36 / SELECT35 / OK34. Firmware identifier: `OK34_TRACE_V1`.

The 5 ms GPIO task samples and debounces all three active-low buttons. It queues diagnostic records without waiting for UART output. The main task prints those records. Diagnostic queue overflow is reported and cannot fill the separate key queue. Timestamps refer to sampling time; use key IDs to correlate enqueue and dequeue when log output is delayed.

| Log | Meaning |
| --- | --- |
| `GPIO34 RAW ... level=0 PRESSED` | The sampler observed GPIO34 low. Raw bounce may generate several lines. |
| `GPIO34 STABLE ... PRESSED event=OK` | GPIO34 stayed low for 25 ms and produced an OK event. |
| `KEY ENQUEUE ... gpio=34 event=OK` | The event was accepted into the key queue. |
| `KEY QUEUE_FULL` | The key queue rejected this event. |
| `KEY DEQUEUE ... event=OK` | Production `readKeyEvent()` received the event; `age` measures queue delay. |
| `INPUT ... source=GPIO` | `handleButtons()` is forwarding the physical event. |
| `NAV RECEIVED` | Dispatcher state before acting, including screen, focus and notification flags. |
| `NAV ACTIVATE` | `activateFocusedControl()` was reached for the shown focus. |
| `NAV DONE` | State after the action. |
| `NAV ALERT_DISMISSED` | The press only dismissed an active alert, as requested. |
| `GPIO34 STABLE ... RELEASED event=NONE` | Debounced release; it does not generate an additional action. |

If GPIO34 is already low when the sampler starts, the initial `STABLE ... PRESSED event=NONE` is the intentional held-at-boot suppression. A stable release must occur before the next press can emit OK. That log alone does not establish why the pin is low.

## Hardware procedure

With this firmware running and the serial capture open at 115200:

1. Release all three buttons. `INPUTS` prints actual pin levels and the build/source path; the capture script requests it every five seconds.
2. MODE to the task selection screen, then SELECT until Coding is focused.
3. Press and release OK GPIO34. Expected: `NAV ACTIVATE` on `TASK_SELECT`, `controlFocus=0(Coding)`, then `NAV DONE` on `POMODORO_CONTROLS`, `controlFocus=2(START/PAUSE)`, `task=Coding running=0`.
4. Press and release OK again. Expected: activation on START/PAUSE and then `task=Coding running=1`.
5. Hold OK and release it to verify that a contact produces one action, with no action on release.

These are expected observations, not a claim that the physical procedure has passed. See captured serial logs and RESULTS.md for actual observations.

## Host checks

`test/extract_navigation.ps1` extracts the production sampler, diagnostic functions, `readKeyEvent()` and navigation/action functions. The host test simulates only GPIO reads, UART, queue primitives and peripherals. It tests bounce, hold/release, Coding confirmation/start, queue copying and overflow, alongside the existing navigation checks. Host results do not prove electrical behavior or RTOS timing on the board.
