#!/bin/bash
# ==============================================================================
# Script: ml_numa_stall_detector.sh
# Author: Anshika Pundeel
# Description: Advanced NUMA/GPU affinity analyzer for AI/ML workloads. 
#              Detects interconnect bottlenecks when CPU DataLoaders are 
#              misaligned with GPU PCIe locality.
# ==============================================================================

echo "🔥 Initiating AI/ML NUMA & GPU Affinity Audit..."
echo "------------------------------------------------------------------"

# 1. Detect active ML workloads (Python, PyTorch, Ray, etc.)
echo "[1] Scanning for active Machine Learning processes..."
ML_PIDS=$(pgrep -f "python|pytorch|tensorflow|ray" | head -n 5)

if [ -z "$ML_PIDS" ]; then
    echo "No obvious ML workloads detected (python/pytorch/tensorflow). Testing system globally."
    ML_PIDS=$(ps -eo pid,pcpu,cmd --sort=-pcpu | awk 'NR==2{print $1}') # Fallback to top CPU consumer
fi

# 2. Check GPU-to-NUMA Topology (The "AI" Context)
echo -e "\n[2] Analyzing Hardware Topology (GPU-to-NUMA Mapping)..."
if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA GPUs detected. Mapping PCIe affinity:"
    nvidia-smi topo -m | grep -E "GPU|NUMA"
else
    echo "No NVIDIA GPUs detected. Proceeding with CPU/RAM NUMA analysis only."
fi

# 3. Deep Dive into Process NUMA Spanning
echo -e "\n[3] Memory Locality & Cross-Node Spanning Analysis:"
for PID in $ML_PIDS; do
    CMD=$(ps -p $PID -o comm=)
    echo "Analyzing PID: $PID ($CMD)"
    
    # Check if process is thrashing memory across NUMA nodes
    if command -v numastat &> /dev/null; then
        numastat -p $PID | grep -E "Node|Total" 
    else
        echo "numastat not installed. Checking /proc/$PID/numa_maps..."
        awk 'BEGIN { print "Node mapping:" } { for(i=2;i<=NF;i++) if($i~/[Nn][0-9]+=/) print $i }' /proc/$PID/numa_maps | sort | uniq -c
    fi
    
    # Check CPU Thread Affinity (Are they pinned or floating?)
    ALLOWED_CPUS=$(cat /proc/$PID/status | grep Cpus_allowed_list | awk '{print $2}')
    echo " -> Threads allowed on CPUs: $ALLOWED_CPUS"
    
    # Check Context Switch Rate (High voluntary CS = I/O stall, High Involuntary = Thrashing)
    grep -E "voluntary_ctxt_switches" /proc/$PID/status
    echo "---------------------------------"
done

# 4. Kernel Page Faults (Detecting severe memory fragmentation)
echo -e "\n[4] System-wide Minor/Major Page Faults (High major faults kill ML performance):"
sar -B 1 1 2>/dev/null || vmstat -s | grep "pages paged in"

echo "=================================================================="
echo "🎯 DIAGNOSTIC INSIGHTS:"
echo "- If an ML process has memory distributed evenly across Node 0 and Node 1, it is crossing the UPI link."
echo "- Fix: Use 'numactl --cpunodebind=X --membind=X python train.py' to lock the workload to the GPU's NUMA node."
echo "=================================================================="
