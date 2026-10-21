#!/bin/bash
# ==============================================================================
# compare.sh - Agrega los _resumen.csv en los 3 CSV finales
# Uso: compare.sh [TIMESTAMP]   (por defecto usa last_timestamp.txt)
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_ROOT="$PROJECT_DIR/results"
CSV_DIR="$RESULTS_ROOT/csv"
LOG_DIR="$CSV_DIR/logs"
HIST_DIR="$CSV_DIR/history"

mkdir -p "$CSV_DIR" "$LOG_DIR" "$HIST_DIR"

TIMESTAMP="${1:-}"
if [ -z "$TIMESTAMP" ] && [ -f "$CSV_DIR/last_timestamp.txt" ]; then
    TIMESTAMP=$(cat "$CSV_DIR/last_timestamp.txt")
fi
if [ -z "$TIMESTAMP" ]; then
    echo "[ERROR] No hay TIMESTAMP (ni arg ni last_timestamp.txt)"
    exit 1
fi

LOG="$LOG_DIR/compare_${TIMESTAMP}.log"
exec > >(tee -a "$LOG")
exec 2>&1

echo "================================================================"
echo " COMPARE - TIMESTAMP=$TIMESTAMP"
echo "================================================================"

FAMILIES=(estaticos bimod gshare gag pag)

# (config|tipo|familia) en orden
CONFIGS=()
for F in "${FAMILIES[@]}"; do
    RUN_DIR="$RESULTS_ROOT/$F/run_$TIMESTAMP"
    if [ ! -d "$RUN_DIR" ]; then
        echo "[WARN] no existe $RUN_DIR"
        continue
    fi
    for D in "$RUN_DIR"/*/; do
        CFG=$(basename "$D")
        [ ! -f "$D/_resumen.csv" ] && continue
        # tipo según familia
        case "$F" in
            estaticos) TYPE="Estático" ;;
            bimod)     TYPE="Bimodal" ;;
            gshare)    TYPE="Gshare" ;;
            gag)       TYPE="Gag" ;;
            pag)       TYPE="Pag" ;;
        esac
        CONFIGS+=("$CFG|$TYPE|$F")
    done
done

echo "Configs detectadas: ${#CONFIGS[@]}"

BENCHMARKS=(bzip2 ammp gap swim vpr)

# Columnas de _resumen.csv: 1 benchmark, 2 IPC, 11 dir_rate
# (ver HEADER en ejecutar_fase1.sh)

UNIFIED="$CSV_DIR/Resultados_Completos_Fase1.csv"
IPC_CSV="$CSV_DIR/Resultados_IPC.csv"
ACC_CSV="$CSV_DIR/Resultados_Tasa_Acierto.csv"

printf '\xEF\xBB\xBF' > "$UNIFIED"
printf '\xEF\xBB\xBF' > "$IPC_CSV"
printf '\xEF\xBB\xBF' > "$ACC_CSV"

echo "Configuracion;Tipo_Predictor;ammp_IPC;ammp_%Acierto;bzip2_IPC;bzip2_%Acierto;gap_IPC;gap_%Acierto;swim_IPC;swim_%Acierto;vpr_IPC;vpr_%Acierto;Media_IPC;Media_%Acierto" >> "$UNIFIED"
echo "Configuracion;Tipo_Predictor;ammp;bzip2;gap;swim;vpr;Media_IPC" >> "$IPC_CSV"
echo "Configuracion;Tipo_Predictor;ammp;bzip2;gap;swim;vpr;Media_%Acierto" >> "$ACC_CSV"

# Helper: convierte coma a punto para cálculos
cd2dot() { echo "$1" | tr ',' '.'; }
dot2cd() { echo "$1" | tr '.' ','; }

for ENTRY in "${CONFIGS[@]}"; do
    IFS='|' read -r CFG TYPE FAMILY <<< "$ENTRY"
    RESUME="$RESULTS_ROOT/$FAMILY/run_$TIMESTAMP/$CFG/_resumen.csv"
    [ ! -f "$RESUME" ] && { echo "[WARN] falta $RESUME"; continue; }

    unified_row="$CFG;$TYPE"
    ipc_row="$CFG;$TYPE"
    acc_row="$CFG;$TYPE"

    ipc_sum=0; ipc_n=0
    acc_sum=0; acc_n=0
    missing_flag=0

    # Orden del enunciado: ammp,bzip2,gap,swim,vpr en unified
    # pero en _resumen.csv están en orden bzip2,ammp,gap,swim,vpr
    for BENCH in "${BENCHMARKS[@]}"; do
        line=$(awk -F';' -v b="$BENCH" '$1==b {print; exit}' "$RESUME")
        if [ -z "$line" ]; then
            echo "  [WARN] $CFG/$BENCH: sin fila"
            missing_flag=1
            continue
        fi
        ipc_raw=$(echo "$line" | cut -d';' -f2)
        acc_raw=$(echo "$line" | cut -d';' -f11)

        [ -z "$ipc_raw" ] && missing_flag=1
        [ -z "$acc_raw" ] && missing_flag=1

        ipc_row="$ipc_row;$ipc_raw"
        acc_row="$acc_row;$acc_raw"

        if [ -n "$ipc_raw" ]; then
            v=$(cd2dot "$ipc_raw")
            ipc_sum=$(awk -v a="$ipc_sum" -v b="$v" 'BEGIN{printf "%.10f", a+b}')
            ipc_n=$((ipc_n+1))
        fi
        if [ -n "$acc_raw" ]; then
            v=$(cd2dot "$acc_raw")
            acc_sum=$(awk -v a="$acc_sum" -v b="$v" 'BEGIN{printf "%.10f", a+b}')
            acc_n=$((acc_n+1))
        fi
    done

    # Unified tiene orden ammp,bzip2,gap,swim,vpr
    for BENCH in ammp bzip2 gap swim vpr; do
        line=$(awk -F';' -v b="$BENCH" '$1==b {print; exit}' "$RESUME")
        if [ -n "$line" ]; then
            ipc_raw=$(echo "$line" | cut -d';' -f2)
            acc_raw=$(echo "$line" | cut -d';' -f11)
            unified_row="$unified_row;$ipc_raw;$acc_raw"
        else
            unified_row="$unified_row;;"
        fi
    done

    if [ "$ipc_n" -eq 5 ]; then
        m_ipc=$(awk -v s="$ipc_sum" -v n="$ipc_n" 'BEGIN{printf "%.4f", s/n}')
        m_ipc=$(dot2cd "$m_ipc")
    else
        m_ipc=""; missing_flag=1
    fi
    if [ "$acc_n" -eq 5 ]; then
        m_acc=$(awk -v s="$acc_sum" -v n="$acc_n" 'BEGIN{printf "%.4f", s/n}')
        m_acc=$(dot2cd "$m_acc")
    else
        m_acc=""; missing_flag=1
    fi

    unified_row="$unified_row;$m_ipc;$m_acc"
    ipc_row="$ipc_row;$m_ipc"
    acc_row="$acc_row;$m_acc"

    echo "$unified_row" >> "$UNIFIED"
    echo "$ipc_row" >> "$IPC_CSV"
    echo "$acc_row" >> "$ACC_CSV"

    if [ "$missing_flag" -eq 1 ]; then
        echo "  [AVISO] $CFG: media incompleta (celdas vacías)"
    fi
done

# Copia histórica
mkdir -p "$HIST_DIR/$TIMESTAMP"
cp "$UNIFIED" "$IPC_CSV" "$ACC_CSV" "$HIST_DIR/$TIMESTAMP/"
cat > "$HIST_DIR/$TIMESTAMP/run_info.txt" <<EOF
timestamp=$TIMESTAMP
configs=${#CONFIGS[@]}
generated=$(date '+%Y-%m-%d %H:%M:%S')
EOF

echo ""
echo "================================================================"
echo " CSVs generados en $CSV_DIR"
echo "   - Resultados_Completos_Fase1.csv"
echo "   - Resultados_IPC.csv"
echo "   - Resultados_Tasa_Acierto.csv"
echo " Copia histórica: $HIST_DIR/$TIMESTAMP/"
echo "================================================================"