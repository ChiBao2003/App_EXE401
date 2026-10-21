"""Capture real ESP32 serial output; never synthesize button events."""
import argparse
import time
from pathlib import Path
import serial

parser = argparse.ArgumentParser()
parser.add_argument('--port', required=True)
parser.add_argument('--seconds', type=float, default=30)
parser.add_argument('--snapshot-interval', type=float, default=0,
                    help='Explicit INPUTS polling interval; zero means startup/end only')
parser.add_argument('--output', required=True)
args = parser.parse_args()
with Path(args.output).open('w', encoding='utf-8') as log:
    def record(text):
        print(text, end='', flush=True)
        log.write(text)
        log.flush()
    try:
        link = serial.Serial(port=None, baudrate=115200, timeout=0.25)
        link.dtr = False
        link.rts = False
        link.port = args.port
        link.open()
        with link:
            record(f'[CAPTURE] Real serial {args.port}, 115200 baud, {args.seconds:g}s\n')
            link.write(b'INPUTS\n')
            next_snapshot = time.monotonic() + args.snapshot_interval
            deadline = time.monotonic() + args.seconds
            while time.monotonic() < deadline:
                if args.snapshot_interval > 0 and time.monotonic() >= next_snapshot:
                    link.write(b'INPUTS\n')
                    next_snapshot = time.monotonic() + args.snapshot_interval
                data = link.read(4096)
                if data:
                    record(data.decode('utf-8', errors='replace'))
            link.write(b'INPUTS\n')
            for _ in range(4):
                data = link.read(4096)
                if data:
                    record(data.decode('utf-8', errors='replace'))
            record('\n[CAPTURE] End\n')
    except serial.SerialException as error:
        record(f'[CAPTURE] ERROR: {error}\n')
        raise SystemExit(1)
