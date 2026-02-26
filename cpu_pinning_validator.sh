#!/bin/bash
# ==============================================================================
# Script: cpu_pinning_validator.sh
# Author: Anshika Pundeel
# Description: Validates if a high-performance process is suffering from 
#              thread migration (cache-trashing) or if it is properly pinned.
# ==============================================================================

if [ -z "$1" ]; then
    echo "Usage: ./cpu_pinning_validator.sh <PID>"
    echo "Example: ./cpu_pinning_validator.sh 1234"
    exit 1
fi

TARGET_PID=$1

if [ ! -d "/proc/$TARGET_PID" ]; then
    echo "Error: Process $TARGET_PID not found."
    exit 1
fi

CMD_NAME=$(cat /proc/$TARGET_PID/comm)
echo "🔍 Analyzing CPU Affinity & Thread Migration for: $CMD_NAME (PID: $TARGET_PID)"
echo "------------------------------------------------------------------"

# 1. Check Global Affinity (What CPUs is the process allowed to use?)
ALLOWED_CPUS=$(grep "Cpus_allowed_list" /proc/$TARGET_PID/status | awk '{print $2}')
echo "[1] Global CPU Allowed List: $ALLOWED_CPUS"

if [[ "$ALLOWED_CPUS" == *"-"* ]] || [[ "$ALLOWED_CPUS" == *","* ]]; then
    echo " ⚠️ Warning: Process is allowed to float across multiple CPUs. High risk of cache misses."
else
    echo " ✅ Process appears strictly pinned to a single CPU/Core."
fi

# 2. Live Thread Migration Monitor
echo -e "\n[2] Monitoring active threads for CPU migration (Sampling for 3 seconds)..."
echo "TID     INITIAL_CPU   FINAL_CPU   STATUS"
echo "------------------------------------------------"

declare -A INITIAL_CPUS

# Capture initial CPU state for all threads
for TID_DIR in /proc/$TARGET_PID/task/*; do
    TID=$(basename $TID_DIR)
    CURRENT_CPU=$(cat $TID_DIR/stat | awk '{print $39}') # 39th field is the current CPU
    INITIAL_CPUS[$TID]=$CURRENT_CPU
done

# Wait and observe
sleep 3

MIGRATION_COUNT=0

# Capture final CPU state and compare
for TID_DIR in /proc/$TARGET_PID/task/*; do
    if [ ! -d "$TID_DIR" ]; then continue; fi # Skip if thread died
    
    TID=$(basename $TID_DIR)
    FINAL_CPU=$(cat $TID_DIR/stat | awk '{print $39}')
    INIT_CPU=${INITIAL_CPUS[$TID]}
    
    if [ "$INIT_CPU" != "$FINAL_CPU" ]; then
        echo -e "$TID\t $INIT_CPU\t\t $FINAL_CPU\t\t ❌ MIGRATED"
        ((MIGRATION_COUNT++))
    else
        echo -e "$TID\t $INIT_CPU\t\t $FINAL_CPU\t\t ✅ STABLE"
    fi
done

echo "------------------------------------------------------------------"
echo "🎯 DIAGNOSTIC INSIGHTS:"
if [ $MIGRATION_COUNT -gt 0 ]; then
    echo "- Detected $MIGRATION_COUNT threads migrating across cores during the sample window."
    echo "- Impact: Severe L1/L2 cache invalidation. This will spike latency in DBs or ML DataLoaders."
    echo "- Fix: Use 'taskset -c <core_list> <command>' or configure application thread pools to pin workers."
else
    echo "- No thread migration detected. Cache locality is preserved."
fi
echo "=================================================================="
