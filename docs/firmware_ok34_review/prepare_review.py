import difflib
import hashlib
import json
from pathlib import Path

review = Path(__file__).resolve().parent
source = review.parents[1] / 'Firmware_ESP32'
target = Path('C:/EXE401_WEDAPP_PROJECT_REPORT/260911-122138-esp32doit-devkit-v1')
files = ['src/Esp32Pj.ino', 'src/io_service.cpp', 'src/io_service.h',
         'src/io_logic.h', 'test/navigation_test.cpp', 'test/extract_navigation.ps1']
entries, diffs = [], []
for name in files:
    before, after = (target / name).read_bytes(), (source / name).read_bytes()
    backup = review / 'before' / name
    backup.parent.mkdir(parents=True, exist_ok=True)
    if backup.exists():
        assert backup.read_bytes() == before, f'Baseline changed: {name}'
    else:
        backup.write_bytes(before)
    diff = list(difflib.unified_diff(before.decode('utf-8').splitlines(True),
                                   after.decode('utf-8').splitlines(True),
                                   fromfile='a/' + name, tofile='b/' + name))
    diffs.extend(diff)
    entry = {'path': name, 'before_sha256': hashlib.sha256(before).hexdigest(),
             'after_sha256': hashlib.sha256(after).hexdigest(),
             'added': sum(line.startswith('+') and not line.startswith('+++') for line in diff),
             'removed': sum(line.startswith('-') and not line.startswith('---') for line in diff)}
    entries.append(entry)
    print(f'{name}: +{entry["added"]} -{entry["removed"]}')
(review / 'ok34_changes.diff').write_text(''.join(diffs), encoding='utf-8')
(review / 'manifest.json').write_text(json.dumps({'source_root': str(source),
    'target_root': str(target), 'files': entries}, indent=2), encoding='utf-8')
