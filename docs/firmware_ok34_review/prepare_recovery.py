import difflib
import hashlib
import json
from pathlib import Path

review = Path(__file__).resolve().parent / 'recovery'
review.mkdir(exist_ok=True)
source = review.parents[2] / 'Firmware_ESP32'
target = Path('C:/EXE401_WEDAPP_PROJECT_REPORT/260911-122138-esp32doit-devkit-v1')
entries, diffs = [], []
for name in ['src/Esp32Pj.ino', 'test/navigation_test.cpp']:
    before, after = (target / name).read_bytes(), (source / name).read_bytes()
    backup = review / 'before' / name
    backup.parent.mkdir(parents=True, exist_ok=True)
    if backup.exists():
        assert backup.read_bytes() == before, f'Baseline changed: {name}'
    else:
        backup.write_bytes(before)
    diffs.extend(difflib.unified_diff(before.decode('utf-8').splitlines(True),
                 after.decode('utf-8').splitlines(True), fromfile='a/' + name, tofile='b/' + name))
    entries.append({'path': name, 'before_sha256': hashlib.sha256(before).hexdigest(),
                    'after_sha256': hashlib.sha256(after).hexdigest()})
(review / 'recovery_changes.diff').write_text(''.join(diffs), encoding='utf-8')
(review / 'manifest.json').write_text(json.dumps({'source_root': str(source),
    'target_root': str(target), 'files': entries}, indent=2), encoding='utf-8')
print('Prepared before/after diff and hashes for', target)
