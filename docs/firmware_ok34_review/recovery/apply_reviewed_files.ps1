param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$sourceRoot = [System.IO.Path]::GetFullPath($manifest.source_root)
$targetRoot = [System.IO.Path]::GetFullPath($manifest.target_root)
if ($targetRoot -ne 'C:\EXE401_WEDAPP_PROJECT_REPORT\260911-122138-esp32doit-devkit-v1') {
  throw 'Unexpected target project'
}
# Check every input before modifying any file. Fail if either copy changed
# after the before/after diff was prepared.
foreach ($entry in $manifest.files) {
  $source = [System.IO.Path]::GetFullPath((Join-Path $sourceRoot $entry.path))
  $target = [System.IO.Path]::GetFullPath((Join-Path $targetRoot $entry.path))
  if (!$source.StartsWith($sourceRoot + '\') -or !$target.StartsWith($targetRoot + '\')) {
    throw 'File escapes the reviewed project roots'
  }
  if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $entry.after_sha256) {
    throw "Source changed after review: $source"
  }
  if ($null -eq $entry.before_sha256) {
    if (Test-Path -LiteralPath $target) { throw "New destination appeared: $target" }
  } elseif (!(Test-Path -LiteralPath $target) -or
            (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $entry.before_sha256) {
    throw "Destination changed after review: $target"
  }
}
if (!$Apply) { Write-Output 'PASS: all reviewed source and destination hashes match'; exit 0 }
foreach ($entry in $manifest.files) {
  $target = Join-Path $targetRoot $entry.path
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
  Copy-Item -LiteralPath (Join-Path $sourceRoot $entry.path) -Destination $target -Force
  if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $entry.after_sha256) {
    throw "Verification failed: $target"
  }
  Write-Output "UPDATED $target"
}
