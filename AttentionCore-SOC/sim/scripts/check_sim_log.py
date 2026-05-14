#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path

# Match actual UVM messages (with @ timestamp), not summary lines like "UVM_FATAL :    0"
DEFAULT_FATAL_PATTERNS = [
    r"UVM_FATAL\s*@",
    r"\bFatal:\b",
    r"segmentation fault",
    r"License checkout failed",
]

DEFAULT_ERROR_PATTERNS = [
    r"UVM_ERROR\s*@",
    r"\bError:\b",
    r"Bit-True Errors",
    r"\btimeout\b",
]


from typing import List, Tuple

def count_patterns(text: str, patterns: List[str]) -> List[Tuple[str, int]]:
    results = []
    for pattern in patterns:
        count = len(re.findall(pattern, text, flags=re.IGNORECASE))
        if count:
            results.append((pattern, count))
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="Check VCS simulation log for common failure patterns.")
    parser.add_argument("--log", required=True, help="Path to simulation log")
    parser.add_argument("--pass-marker", default="", help="Required pass marker string")
    parser.add_argument("--allow-uvm-error", action="store_true", help="Do not fail on UVM_ERROR")
    args = parser.parse_args()

    log_path = Path(args.log)
    if not log_path.is_file():
        print(f"FAIL: log file not found: {log_path}")
        return 2

    text = log_path.read_text(errors="replace")
    fatal_hits = count_patterns(text, DEFAULT_FATAL_PATTERNS)
    error_patterns = DEFAULT_ERROR_PATTERNS.copy()
    if args.allow_uvm_error:
        error_patterns = [p for p in error_patterns if "UVM_ERROR" not in p]
    error_hits = count_patterns(text, error_patterns)

    failed = False
    if fatal_hits:
        failed = True
        print("FAIL: fatal patterns found")
        for pattern, count in fatal_hits:
            print(f"  {pattern}: {count}")

    if error_hits:
        failed = True
        print("FAIL: error patterns found")
        for pattern, count in error_hits:
            print(f"  {pattern}: {count}")

    if args.pass_marker and args.pass_marker not in text:
        failed = True
        print(f"FAIL: pass marker not found: {args.pass_marker}")

    if failed:
        print(f"Log check failed: {log_path}")
        return 1

    print(f"PASS: log check passed: {log_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
