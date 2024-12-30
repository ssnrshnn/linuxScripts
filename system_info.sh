#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

clear
div() { printf "%$(tput cols)s\n" | tr ' ' '-'; }

# System Information
div
echo -e "${BLUE}SYSTEM${NC}"
echo -e "Hostname: $(hostname) | User: $USER"
echo -e "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo -e "Kernel: $(uname -r) | Arch: $(uname -m)"
echo -e "CPU: $(lscpu | grep "Model name" | cut -d':' -f2 | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1-4)"
echo -e "Uptime: $(uptime -p) | Last Boot: $(who -b | awk '{print $3, $4}')"

# Resources
echo -e "\n${BLUE}RESOURCES${NC}"
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
MEM_USAGE=$(free | awk '/Mem/{printf("%.0f", $3/$2*100)}')

echo -e "CPU: $(if [ ${CPU_USAGE%.*} -gt 80 ]; then echo -e "${RED}$CPU_USAGE%${NC}"; else echo "$CPU_USAGE%"; fi) ($(nproc) cores) | Load:$(uptime | awk -F'load average:' '{print $2}')"
echo -e "RAM: $(if [ $MEM_USAGE -gt 80 ]; then echo -e "${RED}$MEM_USAGE%${NC}"; else echo "$MEM_USAGE%"; fi) | $(free -h | awk '/^Mem:/ {printf "%s total, %s free", $2, $4}')"

# Top Process
echo -e "Top: $(ps aux --sort=-%cpu | head -2 | tail -1 | awk '{printf "%s (CPU: %.1f%%, MEM: %.1f%%)", $11, $3, $4}')"

# Disk Information
echo -e "\n${BLUE}DISK${NC}"
echo "Physical Disks: $(lsblk -d -n | grep -c disk) | Partitions: $(lsblk -n | grep -c part)"

# Show all physical disks
echo "Disk List:"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk

# Show mounted partitions usage (excluding tmpfs and devtmpfs)
echo -e "\nPartition Usage:"
df -h | awk 'NR>1 && $1!="tmpfs" && $1!="devtmpfs" {
    usage=$5
    gsub(/%/,"",usage)
    if(usage > 80) {
        printf "'${RED}'%-12s %4s/%4s (%s)'${NC}'\n", $6, $3, $2, $5
    } else {
        printf "%-12s %4s/%4s (%s)\n", $6, $3, $2, $5
    }
}'

# Show disk I/O (if available)
if command -v iostat >/dev/null 2>&1; then
    echo -e "\nDisk I/O (current):"
    iostat -d -h 1 1 | awk 'NR>3 && NR<6 {printf "%-10s: %6s read, %6s write\n", $1, $3, $4}'
fi

# Network Information
echo -e "\n${BLUE}NETWORK${NC}"
# Get default route interface
DEFAULT_IFACE=$(ip route | awk '/default/ {print $5; exit}')

# Show Network Interfaces
echo "Interfaces:"
ip -4 addr show | awk -v default_iface="$DEFAULT_IFACE" '
    /^[0-9]+:/ {
        iface=$2
        gsub(/:/, "", iface)
    }
    /inet / {
        if (iface == default_iface) {
            printf "* %-8s: %s\n", iface, $2
        } else {
            printf "  %-8s: %s\n", iface, $2
        }
    }'

# Show Network Status
ESTABLISHED=$(netstat -tn | grep -c ESTABLISHED)
LISTENING=$(netstat -tuln | grep -c LISTEN)
echo -e "\nConnections:"
echo "→ $ESTABLISHED active connection(s)"
echo "→ $LISTENING listening port(s)"

# Show most used ports (if netstat available)
if [ $LISTENING -gt 0 ]; then
    echo -e "\nOpen Ports:"
    netstat -tuln | awk 'NR>2 {
        split($4, a, ":")
        if (a[2] != "") {
            printf "→ %-5s (%s)\n", a[2], $1
        }
    }' | head -n 5
fi

# Health
echo -e "\n${BLUE}HEALTH${NC}"
UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l || echo "N/A")
FAILED=$(systemctl --failed 2>/dev/null | grep "failed" | wc -l || echo "N/A")
[ "$UPDATES" != "0" ] && echo "Updates: $UPDATES available"
[ "$FAILED" != "0" ] && echo -e "${RED}Failed Services: $FAILED${NC}"

div 