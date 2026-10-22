#!/usr/bin/env python3
"""Reads `xcrun simctl list devices available -j` on stdin and prints the UDID of the best
6.9-inch-class iPhone (Pro Max / Plus) on the newest iOS runtime, for App Store screenshots."""
import json
import re
import sys

data = json.load(sys.stdin)["devices"]


def runtime_version(key):
    m = re.search(r"iOS-(\d+)-(\d+)", key)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)


best = None
for runtime in sorted((k for k in data if "iOS" in k), key=runtime_version, reverse=True):
    devices = data[runtime]
    for preference in ("Pro Max", "Plus", "Pro", "iPhone"):
        matches = [d for d in devices if d.get("isAvailable", True) and preference in d["name"] and d["name"].startswith("iPhone")]
        if matches:
            # Highest model number first (e.g. iPhone 17 Pro Max over iPhone 16 Pro Max)
            matches.sort(key=lambda d: [int(n) for n in re.findall(r"\d+", d["name"])] or [0], reverse=True)
            best = matches[0]
            break
    if best:
        break

if not best:
    sys.exit("No iPhone simulator available")
print(best["udid"])
print(f"Using {best['name']}", file=sys.stderr)
