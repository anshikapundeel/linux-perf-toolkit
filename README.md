# Linux Performance Toolkit (`linux-perf-toolkit`)

A specialized toolkit of lightweight, zero-dependency shell scripts built for deep, OS-level performance auditing and troubleshooting. 

This repository bridges the gap between Linux kernel diagnostics and modern AI/ML workloads, helping performance engineers and SREs quickly isolate infrastructure bottlenecks.

## 🛠️ Tools Included

### 1. `ml_numa_stall_detector.sh` (AI/ML Hardware Topology Auditor)
**The Problem:** Modern AI model training often suffers from silent hardware bottlenecks. If an ML framework (like PyTorch) spins up CPU DataLoaders on NUMA Node 0, but the GPU is attached to the PCIe bus of NUMA Node 1, data must cross the QPI/UPI interconnect. This causes massive `sy%` CPU spikes, I/O stalls, and starves the expensive GPUs.
**The Solution:** This script dynamically detects active ML workloads, maps memory allocation across NUMA nodes, and cross-references them with NVIDIA GPU topology to detect PCIe/NUMA interconnect bottlenecks.
**Usage:**
`bash
chmod +x ml_numa_stall_detector.sh
./ml_numa_stall_detector.sh
`

*(Upcoming tools: CPU pinning validator, IRQ affinity analyzer, and deep `sy%` diagnostics).*

---
**Author:** Anshika Pundeel  
**Portfolio & Contact:** [anshikapundeel.github.io](https://anshikapundeel.github.io)
