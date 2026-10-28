# Compile the actual sketch handlers in the host test, with hardware mocked.
# Each selected function ends with a closing brace at column zero.
$projectRoot = Split-Path -Parent $PSScriptRoot
$sketch = [System.IO.File]::ReadAllText((Join-Path $projectRoot 'src/Esp32Pj.ino'))
$functions = @('currentControlScreen', 'currentControlCount', 'syncControlFocus',
  'setControlFocus', 'dismissInputAlert', 'logControlState', 'activateFocusedControl',
  'handleNavigationEvent', 'handleButtons', 'drawNavigationHelp', 'drawControlFocus',
  'handleTouchAt', 'updateBackgroundTimers', 'updateSelectionOutline',
  'resetPomodoro', 'advancePomoPhase', 'resetTimerToSelection',
  'drawTimerSelectGUI', 'drawTimerStartPauseButton', 'drawTimerRunGUI', 'runTimerMode',
  'drawTaskSelectGUI', 'drawPomodoroGUI', 'drawPomodoroStartPauseButton',
  'runPomodoroMode', 'phaseColor', 'phaseLabel')
$blocks = foreach ($name in $functions) {
  $match = [regex]::Match($sketch, '(?ms)^(?:void|bool|int|uint16_t|const char\*) ' + $name + '\([^\r\n]*\)\s*\{.*?^}')
  if (!$match.Success) {
    throw "Missing production function: $name"
  }
  $match.Value
}
$declarations = foreach ($block in $blocks) { $block.Substring(0,$block.IndexOf('{')).Trim() + ';' }
[System.IO.File]::WriteAllText((Join-Path $projectRoot '.pio/navigation_under_test.inc'),
  (($declarations -join "`n") + "`n" + ($blocks -join "`n`n")),
  (New-Object System.Text.UTF8Encoding($false)))

# Exercise the production GPIO sampler, queue send/receive and diagnostic
# functions too. Only digitalRead, UART and FreeRTOS primitives are simulated.
$io = [System.IO.File]::ReadAllText((Join-Path $projectRoot 'src/io_service.cpp'))
$start = $io.IndexOf('namespace {')
$end = $io.IndexOf('void ioTask(')
if ($start -lt 0 -or $end -le $start) { throw 'Missing production IO sampler' }
$ioBlocks = @($io.Substring($start,$end-$start) + "`n}")
foreach ($name in @('readKeyEvent','serviceInputDiagnostics','discardKeyEvents')) {
  $match = [regex]::Match($io, '(?ms)^(?:void|bool) ' + $name + '\([^\r\n]*\)\s*\{.*?^}')
  if (!$match.Success) { throw "Missing production IO function: $name" }
  $ioBlocks += $match.Value
}
$ioBlocks += 'uint8_t rawButtonLevels() { return buttonLevels; }'
[System.IO.File]::WriteAllText((Join-Path $projectRoot '.pio/io_under_test.inc'),
  ($ioBlocks -join "`n`n"),(New-Object System.Text.UTF8Encoding($false)))
