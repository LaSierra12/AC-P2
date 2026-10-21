#!/bin/bash
# ==============================================================================
# ejecutar_fase1.sh - Fase 1: Predictores de salto (Simplescalar)
# Estructura: results/<familia>/run_<ts>/<config>/_resumen.csv
# Al final llama a compare.sh para generar los 3 CSV agregados
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SPECWORK_DIR="$PROJECT_DIR/specwork"
RESULTS_ROOT="$PROJECT_DIR/results"
CSV_DIR="$RESULTS_ROOT/csv"
LOG_DIR="$CSV_DIR/logs"

mkdir -p "$SPECWORK_DIR" "$CSV_DIR" "$LOG_DIR"

TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
echo "$TIMESTAMP" > "$CSV_DIR/last_timestamp.txt"
RUN_LOG="$LOG_DIR/ejecucion_${TIMESTAMP}.log"

exec > >(tee -a "$RUN_LOG")
exec 2>&1

# --- Parámetros del enunciado ---
FASTFWD=100000000
MAX_INST=100000000
MEM_WIDTH=32
MEM_LAT="300 2"

BENCHMARKS=(bzip2 ammp gap swim vpr)

# --- Familias ---
declare -A FAMILY_CONFIGS
FAMILY_ORDER=()

FAMILY_ORDER+=(estaticos)
FAMILY_CONFIGS[estaticos]="taken|taken|-bpred taken
nottaken|nottaken|-bpred nottaken
perfect|perfect|-bpred perfect"

FAMILY_ORDER+=(bimod)
FAMILY_CONFIGS[bimod]="bimod_8|Bimodal|-bpred bimod -bpred:bimod 8
bimod_32|Bimodal|-bpred bimod -bpred:bimod 32
bimod_128|Bimodal|-bpred bimod -bpred:bimod 128
bimod_512|Bimodal|-bpred bimod -bpred:bimod 512
bimod_2048|Bimodal|-bpred bimod -bpred:bimod 2048"

FAMILY_ORDER+=(gshare)
FAMILY_CONFIGS[gshare]="Gshare_8|Gshare|-bpred 2lev -bpred:2lev 1 8 3 1
Gshare_32|Gshare|-bpred 2lev -bpred:2lev 1 32 5 1
Gshare_128|Gshare|-bpred 2lev -bpred:2lev 1 128 7 1
Gshare_512|Gshare|-bpred 2lev -bpred:2lev 1 512 9 1
Gshare_2048|Gshare|-bpred 2lev -bpred:2lev 1 2048 11 1"

FAMILY_ORDER+=(gag)
FAMILY_CONFIGS[gag]="Gag_8|Gag|-bpred 2lev -bpred:2lev 1 8 3 0
Gag_32|Gag|-bpred 2lev -bpred:2lev 1 32 5 0
Gag_128|Gag|-bpred 2lev -bpred:2lev 1 128 7 0
Gag_512|Gag|-bpred 2lev -bpred:2lev 1 512 9 0
Gag_2048|Gag|-bpred 2lev -bpred:2lev 1 2048 11 0"

FAMILY_ORDER+=(pag)
FAMILY_CONFIGS[pag]="Pag_4_4|Pag|-bpred 2lev -bpred:2lev 4 4 2 0
Pag_8_16|Pag|-bpred 2lev -bpred:2lev 8 16 4 0
Pag_16_64|Pag|-bpred 2lev -bpred:2lev 16 64 6 0
Pag_32_256|Pag|-bpred 2lev -bpred:2lev 32 256 8 0
Pag_64_1024|Pag|-bpred 2lev -bpred:2lev 64 1024 10 0
Pag_32_2048|Pag|-bpred 2lev -bpred:2lev 32 2048 11 0"

# --- Helpers ---
prepare_specwork() {
    local b="$1"
    mkdir -p "$SPECWORK_DIR/$b"
    if [ ! -f "$SPECWORK_DIR/$b/$b.exe" ] && [ -f "/lib/specs2000/$b/exe/$b.exe" ]; then
        cp -n "/lib/specs2000/$b/exe/$b.exe" "$SPECWORK_DIR/$b/"
    fi
    if [ -d "/lib/specs2000/$b/data/ref" ]; then
        cp -n /lib/specs2000/$b/data/ref/* "$SPECWORK_DIR/$b/" 2>/dev/null || true
    fi
    if [ "$b" = "gap" ] && [ -d "/lib/specs2000/gap/data/all" ]; then
        mkdir -p "$SPECWORK_DIR/gap/all"
        cp -n /lib/specs2000/gap/data/all/* "$SPECWORK_DIR/gap/all/" 2>/dev/null || true
    fi
}

run_bench() {
    local bench="$1" opts="$2" simout="$3" logfile="$4"
    cd "$SPECWORK_DIR/$bench" || return 1
    local common="-fastfwd $FASTFWD -max:inst $MAX_INST -mem:width $MEM_WIDTH -mem:lat $MEM_LAT"
    case "$bench" in
        bzip2) sim-outorder $common $opts -redir:sim "$simout" \
                  ./bzip2.exe input.source 58 >> "$logfile" 2>&1 ;;
        ammp)  sim-outorder $common $opts -redir:sim "$simout" \
                  ./ammp.exe < ammp.in >> "$logfile" 2>&1 ;;
        gap)   sim-outorder $common $opts -redir:sim "$simout" \
                  ./gap.exe -l ./all -q -m 192M < ref.in >> "$logfile" 2>&1 ;;
        swim)  sim-outorder $common $opts -redir:sim "$simout" \
                  ./swim.exe < swim.in >> "$logfile" 2>&1 ;;
        vpr)   sim-outorder $common $opts -redir:sim "$simout" \
                  ./vpr.exe net.in arch.in "$RESULTS_ROOT/place.out" "$RESULTS_ROOT/dum.out" \
                  -nodisp -place_only -init_t 5 -exit_t 0.005 \
                  -alpha_t 0.9412 -inner_num 2 >> "$logfile" 2>&1 ;;
        *) return 1 ;;
    esac
}

# Extrae valor y convierte punto a coma; deja vacío si no hay match
getm() {
    local file="$1" key="$2"
    local v
    v=$(grep -m1 "^$key " "$file" 2>/dev/null | awk '{print $2}')
    if [ -z "$v" ]; then echo ""; else echo "$v" | tr '.' ','; fi
}

HEADER="benchmark;IPC;CPI;sim_cycle;sim_num_insn;sim_total_insn;sim_exec_BW;ifq_occupancy;ruu_occupancy;lsq_occupancy;bpred_dir_rate;bpred_addr_rate;bpred_misses;ras_rate;il1_miss_rate;dl1_miss_rate;ul2_miss_rate;itlb_miss_rate;dtlb_miss_rate"

echo ""
echo "================================================================"
echo " EJECUCIÓN FASE 1 - $TIMESTAMP"
echo " Salida raíz : $RESULTS_ROOT"
echo " Log         : $RUN_LOG"
echo "================================================================"

TOTAL_OK=0
TOTAL_FAIL=0

for FAMILY in "${FAMILY_ORDER[@]}"; do
    FAMILY_DIR="$RESULTS_ROOT/$FAMILY/run_$TIMESTAMP"
    mkdir -p "$FAMILY_DIR"

    echo ""
    echo "================================================================"
    echo " FAMILIA: $FAMILY"
    echo "================================================================"

    while IFS='|' read -r CFG_NAME CFG_TYPE CFG_OPTS; do
        [ -z "$CFG_NAME" ] && continue
        CFG_DIR="$FAMILY_DIR/$CFG_NAME"
        mkdir -p "$CFG_DIR"
        RESUME="$CFG_DIR/_resumen.csv"

        printf '\xEF\xBB\xBF' > "$RESUME"
        echo "$HEADER" >> "$RESUME"

        echo ""
        echo "--- $FAMILY/$CFG_NAME ($CFG_TYPE) ---"

        for BENCH in "${BENCHMARKS[@]}"; do
            prepare_specwork "$BENCH"
            STATS="$CFG_DIR/${BENCH}.stats"
            LOG="$CFG_DIR/${BENCH}.log"

            {
                echo "=== $BENCH | $FAMILY/$CFG_NAME | $TIMESTAMP ==="
                echo "Opciones: $CFG_OPTS"
            } > "$LOG"

            echo "  [$BENCH] simulando..."
            if run_bench "$BENCH" "$CFG_OPTS" "$STATS" "$LOG" \
               && grep -q 'sim_IPC' "$STATS" 2>/dev/null; then
                IPC=$(getm    "$STATS" "sim_IPC")
                CPI=$(getm    "$STATS" "sim_CPI")
                CYC=$(getm    "$STATS" "sim_cycle")
                NINS=$(getm   "$STATS" "sim_num_insn")
                TINS=$(getm   "$STATS" "sim_total_insn")
                BW=$(getm     "$STATS" "sim_exec_BW")
                IFQO=$(getm   "$STATS" "ifq_occupancy")
                RUUO=$(getm   "$STATS" "ruu_occupancy")
                LSQO=$(getm   "$STATS" "lsq_occupancy")
                RAS=$(getm    "$STATS" "bpred_bimod.ras_rate.PP")
                [ -z "$RAS" ] && RAS=$(getm "$STATS" "bpred_2lev.ras_rate.PP")
                IL1M=$(getm   "$STATS" "il1.miss_rate")
                DL1M=$(getm   "$STATS" "dl1.miss_rate")
                UL2M=$(getm   "$STATS" "ul2.miss_rate")
                ITLBM=$(getm  "$STATS" "itlb.miss_rate")
                DTLBM=$(getm  "$STATS" "dtlb.miss_rate")

                if [ "$CFG_NAME" = "perfect" ]; then
                    BPRD="1,0000"
                    BPRA="1,0000"
                else
                    BPRD=$(grep -m1 'bpred_.*\.bpred_dir_rate ' "$STATS" | awk '{print $2}' | tr '.' ',')
                    BPRA=$(grep -m1 'bpred_.*\.bpred_addr_rate ' "$STATS" | awk '{print $2}' | tr '.' ',')
                fi
                BPRM=$(grep -m1 'bpred_.*\.misses ' "$STATS" | awk '{print $2}')

                ROW="$BENCH;$IPC;$CPI;$CYC;$NINS;$TINS;$BW;$IFQO;$RUUO;$LSQO;$BPRD;$BPRA;$BPRM;$RAS;$IL1M;$DL1M;$UL2M;$ITLBM;$DTLBM"
                echo "$ROW" >> "$RESUME"
                echo "  [$BENCH] OK  IPC=$IPC  dir_rate=$BPRD"
                TOTAL_OK=$((TOTAL_OK+1))
            else
                echo "  [$BENCH] FALLO: sin sim_IPC"
                TOTAL_FAIL=$((TOTAL_FAIL+1))
            fi
            rm -f "$STATS"
        done

        # Corrección nottaken (si aplica)
        if [ "$CFG_NAME" = "nottaken" ] && [ -f "$FAMILY_DIR/taken/_resumen.csv" ]; then
            tmp=$(mktemp)
            while IFS=';' read -r bench rest; do
                if [ "$bench" = "benchmark" ]; then
                    echo "$bench;$rest" >> "$tmp"; continue
                fi
                taken_rate=$(awk -F';' -v b="$bench" '$1==b {print $11}' "$FAMILY_DIR/taken/_resumen.csv")
                nottaken_rate=$(echo "$rest" | awk -F';' '{print $10}')
                if [ -n "$taken_rate" ] && [ "$nottaken_rate" = "$taken_rate" ]; then
                    t_dot=$(echo "$taken_rate" | tr ',' '.')
                    corrected=$(awk -v t="$t_dot" 'BEGIN{printf "%.4f", 1 - t}' | tr '.' ',')
                    # Reemplazar col 11 (dir_rate)
                    new_rest=$(echo "$rest" | awk -F';' -v c="$corrected" 'BEGIN{OFS=";"}{$10=c; print}')
                    echo "$bench;$new_rest" >> "$tmp"
                else
                    echo "$bench;$rest" >> "$tmp"
                fi
            done < "$RESUME"
            mv "$tmp" "$RESUME"
            echo "  [nottaken] corrección aplicada donde procede"
        fi
    done <<< "${FAMILY_CONFIGS[$FAMILY]}"

    cat > "$FAMILY_DIR/run_info.txt" <<EOF
timestamp=$TIMESTAMP
familia=$FAMILY
fastfwd=$FASTFWD
max_inst=$MAX_INST
mem_width=$MEM_WIDTH
mem_lat=$MEM_LAT
benchmarks=${BENCHMARKS[*]}
EOF
done

echo ""
echo "================================================================"
echo " Agregando CSVs con compare.sh..."
echo "================================================================"

if [ -x "$SCRIPT_DIR/compare.sh" ]; then
    "$SCRIPT_DIR/compare.sh" "$TIMESTAMP"
else
    echo "[AVISO] compare.sh no encontrado o no ejecutable"
fi

echo ""
echo "================================================================"
echo " COMPLETADO"
echo " OK:   $TOTAL_OK"
echo " FAIL: $TOTAL_FAIL"
echo " Log:  $RUN_LOG"
echo "================================================================"