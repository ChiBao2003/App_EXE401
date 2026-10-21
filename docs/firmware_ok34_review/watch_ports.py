"""Record actual port enumeration, without opening any serial port."""
import argparse
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from serial.tools import list_ports

parser = argparse.ArgumentParser()
parser.add_argument('--seconds', type=float, default=120)
parser.add_argument('--output', required=True)
args = parser.parse_args()
deadline = time.monotonic() + args.seconds
previous = None
observations = []
while True:
    ports = [{'port': p.device, 'description': p.description, 'vid': p.vid,
              'pid': p.pid, 'serial': p.serial_number, 'location': p.location}
             for p in list_ports.comports()]
    observation = {'time': datetime.now(timezone.utc).isoformat(), 'ports': ports}
    observations.append(observation)
    Path(args.output).write_text(json.dumps(observations, indent=2), encoding='utf-8')
    if ports != previous:
        print(json.dumps(observation), flush=True)
        previous = ports
    if ports:
        print('PORTS_APPEARED: identify device before opening or uploading', flush=True)
        break
    if time.monotonic() >= deadline:
        print(f'NO_PORTS: {len(observations)} enumerations', flush=True)
        break
    time.sleep(2)
