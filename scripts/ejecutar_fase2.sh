#!/bin/bash
# ejecutar_fase2_agree.sh - Fase 2: Predictor AGREE
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SPECWORK_DIR="$PROJECT_DIR/specwork"
RESULTS_ROOT="$PROJECT_DIR/results"
CSV_DIR="$RESULTS_ROOT/csv"
LOG_DIR="$CSV_DIR/logs"
SIM_BIN="$PROJECT_DIR/simplesim-3.0_acx2/sim-outorder"

mkdir -p "$SPECWORK_DIR" "$CSV_DIR" "$LOG_DIR"

TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
RUN_LOG="$LOG_DIR/agree_${TIMESTAMP}.log"
exec > >(tee -a "$RUN_LOG") 2>&1

echo ""
echo "================================================================"
echo " EJECUCIÓN FASE 2 (AGREE) - $TIMESTAMP"
echo " Salida raíz : $RESULTS_ROOT"
echo " Log         : $RUN_LOG"
echo "================================================================"
echo ""
echo "================================================================"
echo " FAMILIA: agree"
echo "================================================================"
FASTFWD=100000000
MAX_INST=100000000
MEM_WIDTH=32
MEM_LAT="300 2"
BENCHMARKS=(bzip2 ammp gap swim vpr)

# Pares (Y, X, g) del enunciado: c = i + g
CONFIGS=(
  "4 8 2"
  "8 32 3"
  "16 128 4"
  "32 512 6"
  "64 2048 8"
)

run_bench() {
    local bench="$1" opts="$2" simout="$3" logfile="$4"
    cd "$SPECWORK_DIR/$bench" || return 1
    local common="-fastfwd $FASTFWD -max:inst $MAX_INST -mem:width $MEM_WIDTH -mem:lat $MEM_LAT"
    case "$bench" in
        bzip2) "$SIM_BIN" $common $opts -redir:sim "$simout" \
                  ./bzip2.exe input.source 58 >> "$logfile" 2>&1 ;;
        ammp)  "$SIM_BIN" $common $opts -redir:sim "$simout" \
                  ./ammp.exe < ammp.in >> "$logfile" 2>&1 ;;
        gap)   "$SIM_BIN" $common $opts -redir:sim "$simout" \
          ./gap.exe -l ./all -q -m 192M < ref.in >> "$logfile" 2>&1 ;;
        swim)  "$SIM_BIN" $common $opts -redir:sim "$simout" \
                  ./swim.exe < swim.in >> "$logfile" 2>&1 ;;
        vpr)   "$SIM_BIN" $common $opts -redir:sim "$simout" \
                  ./vpr.exe net.in arch.in place.in -nodisp \
                  -place_only -init_t 5 -exit_t 0.005 \
                  -alpha_t 0.9412 -inner_num 2 >> "$logfile" 2>&1 ;;
        *) return 1 ;;
    esac
}

getm() {
    local file="$1" key="$2"
    local v
    v=$(grep -m1 "^$key " "$file" 2>/dev/null | awk '{print $2}')
    if [ -z "$v" ]; then echo ""; else echo "$v" | tr '.' ','; fi
}

HEADER="benchmark;IPC;CPI;sim_cycle;sim_num_insn;sim_total_insn;sim_exec_BW;ifq_occupancy;ruu_occupancy;lsq_occupancy;bpred_dir_rate;bpred_addr_rate;bpred_misses;ras_rate;il1_miss_rate;dl1_miss_rate;ul2_miss_rate;itlb_miss_rate;dtlb_miss_rate"

AGREE_DIR="$RESULTS_ROOT/agree/run_$TIMESTAMP"
mkdir -p "$AGREE_DIR"
RESUME="$AGREE_DIR/_resumen.csv"
printf '\xEF\xBB\xBF' > "$RESUME"
echo "$HEADER" >> "$RESUME"

TOTAL_OK=0; TOTAL_FAIL=0

for cfg in "${CONFIGS[@]}"; do
    read -r Y X g <<< "$cfg"
    CFG_NAME="Agree_Y${Y}_X${X}_g${g}"
    CFG_DIR="$AGREE_DIR/$CFG_NAME"
    mkdir -p "$CFG_DIR"
    CFG_RESUME="$CFG_DIR/_resumen.csv"
    printf '\xEF\xBB\xBF' > "$CFG_RESUME"
    echo "$HEADER" >> "$CFG_RESUME"
    echo ""; echo "--- agree/$CFG_NAME (AGREE) ---"

    for BENCH in "${BENCHMARKS[@]}"; do
        STATS="$CFG_DIR/${BENCH}.stats"
        LOG="$CFG_DIR/${BENCH}.log"
        { echo "=== $BENCH | $CFG_NAME | $TIMESTAMP ===";
          echo "Opciones: -bpred agree -bpred:agree $Y $X $g 0"; } > "$LOG"

        echo "  [$BENCH] simulando..."
        OPTS="-bpred agree -bpred:agree $Y $X $g 0"

        if run_bench "$BENCH" "$OPTS" "$STATS" "$LOG" \
           && grep -q 'sim_IPC' "$STATS" 2>/dev/null; then
            IPC=$(getm "$STATS" "sim_IPC")
            CPI=$(getm "$STATS" "sim_CPI")
            CYC=$(getm "$STATS" "sim_cycle")
            NINS=$(getm "$STATS" "sim_num_insn")
            TINS=$(getm "$STATS" "sim_total_insn")
            BW=$(getm "$STATS" "sim_exec_BW")
            IFQO=$(getm "$STATS" "ifq_occupancy")
            RUUO=$(getm "$STATS" "ruu_occupancy")
            LSQO=$(getm "$STATS" "lsq_occupancy")
            RAS=$(getm "$STATS" "bpred_agree.ras_rate.PP")
            IL1M=$(getm "$STATS" "il1.miss_rate")
            DL1M=$(getm "$STATS" "dl1.miss_rate")
            UL2M=$(getm "$STATS" "ul2.miss_rate")
            ITLBM=$(getm "$STATS" "itlb.miss_rate")
            DTLBM=$(getm "$STATS" "dtlb.miss_rate")
            BPRD=$(getm "$STATS" "bpred_agree.bpred_dir_rate")
            BPRA=$(getm "$STATS" "bpred_agree.bpred_addr_rate")
            BPRM=$(grep -m1 'bpred_agree.misses ' "$STATS" | awk '{print $2}')

            ROW="$BENCH;$IPC;$CPI;$CYC;$NINS;$TINS;$BW;$IFQO;$RUUO;$LSQO;$BPRD;$BPRA;$BPRM;$RAS;$IL1M;$DL1M;$UL2M;$ITLBM;$DTLBM"
            echo "$ROW" >> "$CFG_RESUME"
            echo "$ROW" >> "$RESUME"
            echo "  [$BENCH] OK  IPC=$IPC  dir_rate=$BPRD"
            TOTAL_OK=$((TOTAL_OK+1))
        else
            echo "  [$BENCH] FALLO"
            echo "FAIL $BENCH $CFG_NAME" >> "$AGREE_DIR/FAILURES.txt"
            TOTAL_FAIL=$((TOTAL_FAIL+1))
        fi
        rm -f "$STATS"
    done
done

cat > "$AGREE_DIR/run_info.txt" <<EOF
timestamp=$TIMESTAMP
familia=agree
fastfwd=$FASTFWD
max_inst=$MAX_INST
mem_width=$MEM_WIDTH
mem_lat=$MEM_LAT
benchmarks=${BENCHMARKS[*]}
configs=${CONFIGS[*]}
EOF

# === Generar CSV agregado con formato de Fase 1 ===
AGREE_CSV="$AGREE_DIR/Resultados_AGREE.csv"
printf '\xEF\xBB\xBF' > "$AGREE_CSV"
echo "Configuracion;Tipo_Predictor;ammp_IPC;ammp_%Acierto;bzip2_IPC;bzip2_%Acierto;gap_IPC;gap_%Acierto;swim_IPC;swim_%Acierto;vpr_IPC;vpr_%Acierto;Media_IPC;Media_%Acierto" >> "$AGREE_CSV"

for cfg in "${CONFIGS[@]}"; do
    read -r Y X g <<< "$cfg"
    CFG_NAME="Agree_Y${Y}_X${X}_g${g}"
    CFG_RESUME="$AGREE_DIR/$CFG_NAME/_resumen.csv"
    [ ! -f "$CFG_RESUME" ] && continue

    row="$CFG_NAME;AGREE"
    ipc_sum=0; ipc_n=0
    acc_sum=0; acc_n=0
    for BENCH in ammp bzip2 gap swim vpr; do
        line=$(awk -F';' -v b="$BENCH" '$1==b {print; exit}' "$CFG_RESUME")
        ipc_raw=$(echo "$line" | cut -d';' -f2)
        acc_raw=$(echo "$line" | cut -d';' -f11)
        row="$row;$ipc_raw;$acc_raw"
        if [ -n "$ipc_raw" ]; then
            v=$(echo "$ipc_raw" | tr ',' '.')
            ipc_sum=$(awk -v a="$ipc_sum" -v b="$v" 'BEGIN{printf "%.10f", a+b}')
            ipc_n=$((ipc_n+1))
        fi
        if [ -n "$acc_raw" ]; then
            v=$(echo "$acc_raw" | tr ',' '.')
            acc_sum=$(awk -v a="$acc_sum" -v b="$v" 'BEGIN{printf "%.10f", a+b}')
            acc_n=$((acc_n+1))
        fi
    done
    m_ipc=$(awk -v s="$ipc_sum" -v n="$ipc_n" 'BEGIN{printf "%.4f", s/n}' | tr '.' ',')
    m_acc=$(awk -v s="$acc_sum" -v n="$acc_n" 'BEGIN{printf "%.4f", s/n}' | tr '.' ',')
    row="$row;$m_ipc;$m_acc"
    echo "$row" >> "$AGREE_CSV"
done

echo "CSV agregado AGREE: $AGREE_CSV"

echo ""
echo "================================================================"
echo " COMPLETADO"
echo " OK:   $TOTAL_OK"
echo " FAIL: $TOTAL_FAIL"
echo " CSV:  $RESUME"
echo "================================================================"