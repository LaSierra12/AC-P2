#!/bin/bash
# fix_nottaken.sh - Corrige la col 11 de nottaken/_resumen.csv
# (bug SimpleScalar: nottaken == taken; corregir con 1 - taken)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_ROOT="$PROJECT_DIR/results"

TIMESTAMP="${1:-}"
if [ -z "$TIMESTAMP" ] && [ -f "$RESULTS_ROOT/csv/last_timestamp.txt" ]; then
    TIMESTAMP=$(cat "$RESULTS_ROOT/csv/last_timestamp.txt")
fi
[ -z "$TIMESTAMP" ] && { echo "[ERROR] sin TIMESTAMP"; exit 1; }

NT="$RESULTS_ROOT/estaticos/run_$TIMESTAMP/nottaken/_resumen.csv"
TK="$RESULTS_ROOT/estaticos/run_$TIMESTAMP/taken/_resumen.csv"
[ ! -f "$NT" ] && { echo "[ERROR] falta $NT"; exit 1; }
[ ! -f "$TK" ] && { echo "[ERROR] falta $TK"; exit 1; }

echo "Corrigiendo $NT"
TMP=$(mktemp)
first=1
while IFS= read -r line; do
    if [ "$first" = "1" ]; then echo "$line" >> "$TMP"; first=0; continue; fi
    bench=$(echo "$line" | cut -d';' -f1)
    taken_rate=$(awk -F';' -v b="$bench" '$1==b {print $11}' "$TK")
    nottaken_rate=$(echo "$line" | cut -d';' -f11)
    if [ -n "$taken_rate" ] && [ "$nottaken_rate" = "$taken_rate" ]; then
        t_dot=$(echo "$taken_rate" | tr ',' '.')
        corrected=$(awk -v t="$t_dot" 'BEGIN{printf "%.4f", 1 - t}' | tr '.' ',')
        new_line=$(echo "$line" | awk -F';' -v c="$corrected" 'BEGIN{OFS=";"} {$11=c; print}')
        echo "$new_line" >> "$TMP"
        echo "  [$bench] $nottaken_rate -> $corrected"
    else
        echo "$line" >> "$TMP"
        echo "  [$bench] sin cambio (nottaken=$nottaken_rate, taken=$taken_rate)"
    fi
done < "$NT"
mv "$TMP" "$NT"
echo "Hecho. Ahora: ./compare.sh $TIMESTAMP"