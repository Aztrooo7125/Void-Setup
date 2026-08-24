#!/bin/bash

# 1. Validate input argument
if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Usage: sudo $0 <runs_per_interface>"
    exit 1
fi

RUNS=$1

# Clear previous metrics files
> wifi_metrics.txt
> eth_metrics.txt

# 2. Auto-detect interfaces using nmcli
echo "=== Detecting Network Interfaces ==="
ETH_IF=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="ethernet" {print $1}' | head -n 1)
WLAN_IF=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi" {print $1}' | head -n 1)

if [ -z "$ETH_IF" ]; then
    echo "Error: No Ethernet interface detected."
    exit 1
fi

if [ -z "$WLAN_IF" ]; then
    echo "Error: No Wi-Fi interface detected."
    exit 1
fi

echo "Detected Ethernet: $ETH_IF"
echo "Detected Wi-Fi: $WLAN_IF"
echo "-----------------------------------"

# 3. Function to manage network interfaces
set_network() {
    local mode=$1
    if [ "$mode" == "wlan" ]; then
        echo "=== Switching to Wi-Fi ($WLAN_IF) ==="
        nmcli device disconnect "$ETH_IF" 2>/dev/null
        nmcli radio wifi on
        sleep 10 # Allow extra time for DHCP and Wi-Fi handshake
    elif [ "$mode" == "ethernet" ]; then
        echo "=== Switching to Ethernet ($ETH_IF) ==="
        nmcli radio wifi off
        nmcli device connect "$ETH_IF" 2>/dev/null
        sleep 10 # Allow time for Ethernet negotiation
    fi
}

# Function to run speed tests and parse results
run_tests() {
    local mode=$1
    local file=$2
    for (( i=1; i<=RUNS; i++ ))
    do
        echo "Running $mode test $i of $RUNS..."
        # Use --simple for easier parsing
        speedtest-cli --simple > temporary_run.log

        # Extract purely the numbers
        DL=$(awk '/Download:/ {print $2}' temporary_run.log)
        UL=$(awk '/Upload:/ {print $2}' temporary_run.log)

        # Save to file if values were successfully captured
        if [ -n "$DL" ] && [ -n "$UL" ]; then
            echo "$DL $UL" >> "$file"
        else
            echo "Test failed or timed out. Skipping data point..."
        fi
    done
}

# 4. Execution Loop
# Phase 1: Test Wi-Fi
set_network "wlan"
run_tests "Wi-Fi" "wifi_metrics.txt"

echo ""

# Phase 2: Test Ethernet
set_network "ethernet"
run_tests "Ethernet" "eth_metrics.txt"

# Clean up temporary log
rm -f temporary_run.log

# 5. Calculate final average and compare
echo ""
echo "======================================"
echo "======= Final Speed Comparison ======="
echo "======================================"

calculate_average() {
    local file=$1
    local interface=$2
    awk -v iface="$interface" '
    {dl_sum+=$1; ul_sum+=$2; count++}
    END {
        if (count > 0)
            printf "%-10s -> Avg Download: %6.2f Mbit/s | Avg Upload: %6.2f Mbit/s \n", iface, dl_sum/count, ul_sum/count;
        else
            printf "%-10s -> No valid data recorded.\n", iface;
    }' "$file"
}

calculate_average "eth_metrics.txt" "Ethernet"
calculate_average "wifi_metrics.txt" "Wi-Fi"
echo "======================================"

# 6. Restore normal state
echo "=== Restoring standard network state ==="
nmcli radio wifi on
nmcli device connect "$ETH_IF" 2>/dev/null
