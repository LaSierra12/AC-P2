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
                  ./bzip2.exe input.source 1 >> "$logfile" 2>&1 ;;
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
    echo ""; echo "--- $CFG_NAME ---"

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

echo ""; echo "=== COMPLETADO: OK=$TOTAL_OK FAIL=$TOTAL_FAIL ==="
echo "CSV: $RESUME"