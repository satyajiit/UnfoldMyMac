#!/usr/bin/env python3
"""Publish real Mac load averages for Wallpaper > Data & settings > Connect data file."""
import argparse
import datetime
import json
import os
from pathlib import Path
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
args.output.parent.mkdir(parents=True, exist_ok=True)
try:
    while True:
        one, five, fifteen = os.getloadavg()
        sample = {
            'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'numbers': {'tool.value': one, 'tool.load5': five, 'tool.load15': fifteen},
            'text': {'tool.label': 'YOUR MAC / LIVE LOAD', 'tool.status': f'{one:.2f} NOW. {five:.2f} OVER 5 MIN.'},
            'status': 'Live',
        }
        temporary = args.output.with_name(args.output.name + '.tmp')
        temporary.write_text(json.dumps(sample), encoding='utf-8')
        temporary.replace(args.output)
        time.sleep(1)
except KeyboardInterrupt:
    pass
