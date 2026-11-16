#!/usr/bin/env bash
# Confronta il nucleo Swift con la versione web: stesso seme, stesso stato dopo N fotogrammi.
#
# Uso: macos/Tests/compare.sh [fotogrammi]        (predefinito: 600, cioè 20 secondi a 30 fps)
# Richiede swiftc e node. Funziona su macOS e su Linux.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FRAMES="${1:-600}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swiftc -O -o "$WORK/iconvader-test" "$HERE"/../Sources/Core/*.swift "$HERE/main.swift"

status=0
for behavior in Comets Fireworks GameOfLife Hypnosis DNA Jumpers; do
  for size in "1440 900" "1024 768"; do
    for seed in 1 2 3; do
      "$WORK/iconvader-test" "$behavior" "$FRAMES" "$seed" $size > "$WORK/swift.txt"
      node "$HERE/reference.js" "$behavior" "$FRAMES" "$seed" $size > "$WORK/js.txt"
      count=$(wc -l < "$WORK/swift.txt")
      if cmp -s "$WORK/swift.txt" "$WORK/js.txt"; then
        printf '%-11s %-9s seme %s: identico (%s attori)\n' "$behavior" "${size/ /x}" "$seed" "$count"
      else
        printf '%-11s %-9s seme %s: DIVERSO\n' "$behavior" "${size/ /x}" "$seed"
        diff "$WORK/swift.txt" "$WORK/js.txt" | head -6
        status=1
      fi
    done
  done
done
exit $status
