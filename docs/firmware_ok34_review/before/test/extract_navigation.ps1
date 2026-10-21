# Compile the actual sketch handlers in the host test, with hardware mocked.
# Each selected function ends with a closing brace at column zero.
$projectRoot = Split-Path -Parent $PSScriptRoot
$sketch = [System.IO.File]::ReadAllText((Join-Path $projectRoot 'src/Esp32Pj.ino'))
$functions = @('currentControlScreen', 'currentControlCount', 'syncControlFocus',
  'setControlFocus', 'dismissInputAlert', 'activateFocusedControl',
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
