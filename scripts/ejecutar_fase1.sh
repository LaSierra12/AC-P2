#!/bin/bash
set -e

# ==============================================================================
# SCRIPT DE AUTOMATIZACIÓN - FASE 1: PREDICTORES DE SALTO (TRABAJO 2)
# ==============================================================================

BASE_DIR="$HOME/Documents/AC-P2"
RAW_DIR="$BASE_DIR/results/raw"
CSV_DIR="$BASE_DIR/csv"
SPEC_DIR="/lib/specs2000"

mkdir -p "$RAW_DIR" "$CSV_DIR" "$BASE_DIR/scripts"

# Parámetros generales de simulación exigidos en la práctica
FASTFWD=100000000
MAX_INST=100000000
MEM_WIDTH=32
MEM_LAT="300 2"

# Array con las 24 configuraciones de la Fase 1
CONFIGS=(
    "nottaken|Estático|-bpred nottaken"
    "taken|Estático|-bpred taken"
    "perfect|Estático|-bpred perfect"
    "bimod_8|Bimodal|-bpred bimod -bpred:bimod 8"
    "bimod_32|Bimodal|-bpred bimod -bpred:bimod 32"
    "bimod_128|Bimodal|-bpred bimod -bpred:bimod 128"
    "bimod_512|Bimodal|-bpred bimod -bpred:bimod 512"
    "bimod_2048|Bimodal|-bpred bimod -bpred:bimod 2048"
    "Gshare_8|Gshare|-bpred 2lev -bpred:2lev 1 8 3 1"
    "Gshare_32|Gshare|-bpred 2lev -bpred:2lev 1 32 5 1"
    "Gshare_128|Gshare|-bpred 2lev -bpred:2lev 1 128 7 1"
    "Gshare_512|Gshare|-bpred 2lev -bpred:2lev 1 512 9 1"
    "Gshare_2048|Gshare|-bpred 2lev -bpred:2lev 1 2048 11 1"
    "Gag_8|Gag|-bpred 2lev -bpred:2lev 1 8 3 0"
    "Gag_32|Gag|-bpred 2lev -bpred:2lev 1 32 5 0"
    "Gag_128|Gag|-bpred 2lev -bpred:2lev 1 128 7 0"
    "Gag_512|Gag|-bpred 2lev -bpred:2lev 1 512 9 0"
    "Gag_2048|Gag|-bpred 2lev -bpred:2lev 1 2048 11 0"
    "Pag_4_4|Pag|-bpred 2lev -bpred:2lev 4 4 2 0"
    "Pag_8_16|Pag|-bpred 2lev -bpred:2lev 8 16 4 0"
    "Pag_16_64|Pag|-bpred 2lev -bpred:2lev 16 64 6 0"
    "Pag_32_256|Pag|-bpred 2lev -bpred:2lev 32 256 8 0"
    "Pag_64_1024|Pag|-bpred 2lev -bpred:2lev 64 1024 10 0"
    "Pag_32_2048|Pag|-bpred 2lev -bpred:2lev 32 2048 11 0"
)

BENCHMARKS=("ammp" "bzip2" "gap" "swim" "vpr")

run_benchmark() {
    local bench=$1
    local opts=$2
    local outfile=$3

    case $bench in
        ammp)
            cd "$SPEC_DIR/ammp/data/ref"
            sim-outorder -fastfwd $FASTFWD -max:inst $MAX_INST -mem:width $MEM_WIDTH -mem:lat $MEM_LAT $opts -redir:sim "$outfile" ../../exe/ammp.exe < ammp.in > /dev/null 2>&1
            ;;
        bzip2)
            cd "$SPEC_DIR/bzip2/data/ref"
            sim-outorder -fastfwd $FASTFWD -max:inst $MAX_INST -mem:width $MEM_WIDTH -mem:lat $MEM_LAT $opts -redir:sim "$outfile" ../../exe/bzip2.exe input.source 58 > /dev/null 2>&1
            ;;
        gap)
            cd "$SPEC_DIR/gap/data/ref"
            sim-outorder -fastfwd $FASTFWD -max:inst $MAX_INST -mem:width $MEM_WIDTH -mem:lat $MEM_LAT $opts -redir:sim "$outfile" ../../exe/gap.exe -l ./ -q -m 192M < ref.in > /dev/null 2>&1
            ;;
        swim)
            cd "$SPEC_DIR/swim/data/ref"
            sim-outorder -fastfwd $FASTFWD -max:inst $MAX_INST -mem:width $MEM_WIDTH -mem:lat $MEM_LAT $opts -redir:sim "$outfile" ../../exe/swim.exe < swim.in > /dev/null 2>&1
            ;;
        vpr)
            cd "$SPEC_DIR/vpr/data/ref"
            sim-outorder -fastfwd $FASTFWD -max:inst $MAX_INST -mem:width $MEM_WIDTH -mem:lat $MEM_LAT $opts -redir:sim "$outfile" ../../exe/vpr.exe net.in arch.in place.out dum.out -nodisp -place_only -init_t 5 -exit_t 0.005 -alpha_t 0.9412 -inner_num 2 > /dev/null 2>&1
            ;;
    esac
}

echo "================================================================="
echo " INICIANDO SIMULACIONES DE LA FASE 1 (120 EJECUCIONES EN TOTAL) "
echo "================================================================="

total_configs=${#CONFIGS[@]}
current=0

for cfg in "${CONFIGS[@]}"; do
    IFS='|' read -r cfg_name cfg_type cfg_opts <<< "$cfg"
    current=$((current + 1))
    echo "[$current/$total_configs] Procesando predictor: $cfg_name ($cfg_type)..."
    
    for bench in "${BENCHMARKS[@]}"; do
        outfile="$RAW_DIR/${cfg_name}_${bench}.txt"
        if [ ! -f "$outfile" ]; then
            echo " -> Simulando $bench..."
            run_benchmark "$bench" "$cfg_opts" "$outfile"
        else
            echo " -> $bench ya simulado (omitiendo)."
        fi
    done
done

echo ""
echo "================================================================="
echo " EXTRAYENDO RESULTADOS A ARCHIVOS CSV PARA EXCEL "
echo "================================================================="

UNIFIED_CSV="$CSV_DIR/Resultados_Completos_Fase1.csv"
IPC_CSV="$CSV_DIR/Resultados_IPC.csv"
ACC_CSV="$CSV_DIR/Resultados_Tasa_Acierto.csv"

# Cabeceras para Excel
echo "Configuracion;Tipo_Predictor;ammp_IPC;ammp_%Acierto;bzip2_IPC;bzip2_%Acierto;gap_IPC;gap_%Acierto;swim_IPC;swim_%Acierto;vpr_IPC;vpr_%Acierto;Media_IPC;Media_%Acierto" > "$UNIFIED_CSV"
echo "Configuracion;Tipo_Predictor;ammp;bzip2;gap;swim;vpr;Media_IPC" > "$IPC_CSV"
echo "Configuracion;Tipo_Predictor;ammp;bzip2;gap;swim;vpr;Media_%Acierto" > "$ACC_CSV"

row_num=2

for cfg in "${CONFIGS[@]}"; do
    IFS='|' read -r cfg_name cfg_type cfg_opts <<< "$cfg"
    
    unified_row="$cfg_name;$cfg_type"
    ipc_row="$cfg_name;$cfg_type"
    acc_row="$cfg_name;$cfg_type"
    
    for bench in "${BENCHMARKS[@]}"; do
        raw_file="$RAW_DIR/${cfg_name}_${bench}.txt"
        taken_file="$RAW_DIR/taken_${bench}.txt"
        
        # 1. Extracción de IPC de forma segura ante set -e
        ipc_val=$(grep 'sim_IPC' "$raw_file" 2>/dev/null | awk '{print $2}' || true)
        if [ -z "$ipc_val" ]; then 
            ipc_val="0.0000"
        fi
        ipc_excel=$(echo "$ipc_val" | tr '.' ',')
        
        # 2. Extracción de Tasa de Acierto (bpred_dir_rate)
        if [ "$cfg_name" == "perfect" ]; then
            acc_excel="1,0000"
        elif [ "$cfg_name" == "nottaken" ]; then
            # Corrección por bug de nottaken según FAQs
            taken_rate=$(grep -E 'bpred_.*dir_rate' "$taken_file" 2>/dev/null | awk '{print $2}' || true)
            nottaken_rate=$(grep -E 'bpred_.*dir_rate' "$raw_file" 2>/dev/null | awk '{print $2}' || true)
            acc_val=$(awk -v t="$taken_rate" -v n="$nottaken_rate" 'BEGIN { if (n == "" || n == t) { print (1 - t); } else { print n; } }')
            if [ -z "$acc_val" ]; then
                acc_val="0.0000"
            fi
            acc_excel=$(echo "$acc_val" | tr '.' ',')
        else
            acc_val=$(grep -E 'bpred_.*dir_rate' "$raw_file" 2>/dev/null | awk '{print $2}' || true)
            if [ -z "$acc_val" ]; then 
                acc_val="0.0000"
            fi
            acc_excel=$(echo "$acc_val" | tr '.' ',')
        fi
        
        # Acumular valores en las filas
        ipc_row="$ipc_row;$ipc_excel"
        acc_row="$acc_row;$acc_excel"
        unified_row="$unified_row;$ipc_excel;$acc_excel"
    done
    
    # Añadir fórmulas de Excel para los promedios
    media_ipc_formula="=PROMEDIO(C${row_num};E${row_num};G${row_num};I${row_num};K${row_num})"
    media_acc_formula="=PROMEDIO(D${row_num};F${row_num};H${row_num};J${row_num};L${row_num})"
    
    unified_row="$unified_row;$media_ipc_formula;$media_acc_formula"
    ipc_row="$ipc_row;=PROMEDIO(C${row_num}:G${row_num})"
    acc_row="$acc_row;=PROMEDIO(C${row_num}:G${row_num})"
    
    echo "$unified_row" >> "$UNIFIED_CSV"
    echo "$ipc_row" >> "$IPC_CSV"
    echo "$acc_row" >> "$ACC_CSV"
    
    row_num=$((row_num + 1))
done

echo ""
echo "¡PROCESO COMPLETADO CON ÉXITO!"
echo "Archivos CSV generados en $CSV_DIR:"
echo " 1. $UNIFIED_CSV"
echo " 2. $IPC_CSV"
echo " 3. $ACC_CSV"
