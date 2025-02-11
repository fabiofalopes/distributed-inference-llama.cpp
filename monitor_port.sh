#!/bin/bash
#
# Model Load Time Monitor
# 
# Purpose: Automatically measures server startup time when loading ML models
# Usage: ./monitor_port.sh [model_launch_command]
# 
# Features:
# - Monitors HTTP status until server becomes responsive
# - Calculates and displays total loading time
# - Optional timeout protection
# - Can automatically launch model process
# - Cleanup of background processes

# Configuration
TIMEOUT=3600  # Maximum wait time in seconds (1 hour default)
PORT=8080     # Monitoring port
IP=127.0.0.1

# Function to check HTTP status
check_http_status() {
    local start_time=$(date +%s)
    local current_time
    local elapsed_time

    while true; do
        # Use curl with timeout to check HTTP status
        status=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "http://$IP:$PORT")
        
        # Consider any 2XX/3XX response as successful
        if [[ "$status" =~ ^[23][0-9][0-9]$ ]]; then
            current_time=$(date +%s)
            elapsed_time=$((current_time - start_time))
            echo -e "\nServer is up! Response code: $status"
            echo "Total loading time: $elapsed_time seconds"
            return 0
        else
            current_time=$(date +%s)
            elapsed_time=$((current_time - start_time))
            echo -ne "\rWaiting for server (currently $status)... ($elapsed_time seconds)"
        fi
        
        # Add timeout check
        if [ $elapsed_time -ge $TIMEOUT ]; then
            echo -e "\nTimeout reached ($TIMEOUT seconds). Server not responding."
            exit 1
        fi
        sleep 1
    done
}

# Main execution
if [ $# -gt 0 ]; then
    # If model command provided, run it in background
    echo "Launching model: $@"
    $@ &
    MODEL_PID=$!
    trap "kill $MODEL_PID 2> /dev/null" EXIT  # Cleanup on exit
fi

check_http_status

# Optional: Bring model process to foreground if launched by script
if [ -n "$MODEL_PID" ]; then
    wait $MODEL_PID
fi
