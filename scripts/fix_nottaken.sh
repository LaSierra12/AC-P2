#!/bin/bash
# fix_nottaken.sh - Corrige col 11 de nottaken/_resumen.csv
# FAQ: %nottaken = 1 - %taken   (siempre, son complementarios)
set -uo pipefail

RESULTS_ROOT="$HOME/Documents/AC-P2/results"
TIMESTAMP="${1:-$(cat "$RESULTS_ROOT/csv/last_timestamp.txt")}"

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

    t_dot=$(echo "$taken_rate" | tr ',' '.')
    corrected=$(awk -v t="$t_dot" 'BEGIN{printf "%.4f", 1 - t}' | tr '.' ',')

    new_line=$(echo "$line" | awk -F';' -v c="$corrected" 'BEGIN{OFS=";"} {$11=c; print}')
    echo "$new_line" >> "$TMP"
    echo "  [$bench] $nottaken_rate -> $corrected   (taken=$taken_rate)"
done < "$NT"
mv "$TMP" "$NT"
echo "Hecho. Ahora: ./compare.sh $TIMESTAMP"