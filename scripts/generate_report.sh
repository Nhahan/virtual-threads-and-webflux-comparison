#!/bin/bash
set -e

# Display help message
show_usage() {
  echo "Usage: $0 <vt_summary_file> <wf_summary_file> <output_file>"
  echo "Example: $0 ./results/vt_summary_20250419_202720.txt ./results/wf_summary_20250419_202720.txt ./results/comparison.md"
  exit 1
}

# Validate parameters
if [ "$#" -ne 3 ]; then
  show_usage
fi

VT_SUMMARY_FILE="$1"
WF_SUMMARY_FILE="$2"
COMPARISON_FILE="$3"

# Check if files exist
if [ ! -f "$VT_SUMMARY_FILE" ]; then
  echo "Error: Virtual Threads summary file does not exist: $VT_SUMMARY_FILE"
  exit 1
fi

if [ ! -f "$WF_SUMMARY_FILE" ]; then
  echo "Error: WebFlux summary file does not exist: $WF_SUMMARY_FILE"
  exit 1
fi

# Check results directory
RESULTS_DIR=$(dirname "$COMPARISON_FILE")
mkdir -p "$RESULTS_DIR"

# JSON value extraction function (works in Docker environment)
extract_value() {
  local FILE=$1
  local JSON_PATH=$2
  local DEFAULT=$3
  
  if [ ! -f "$FILE" ]; then
    echo "$DEFAULT"
    return
  fi
  
  # Use Python for JSON parsing (usually pre-installed in most Docker images)
  VALUE=$(python3 -c "
import json, sys
try:
    with open('$FILE', 'r') as f:
        data = json.load(f)
    path = '$JSON_PATH'.split('.')
    result = data
    for key in path:
        if key in result:
            result = result[key]
        else:
            print('$DEFAULT')
            sys.exit(0)
    print(result)
except Exception as e:
    print('$DEFAULT')
" 2>/dev/null || echo "$DEFAULT")
  
  # Use default value if empty
  if [ -z "$VALUE" ]; then
    echo "$DEFAULT"
  else
    # Round to two decimal places if number
    if echo "$VALUE" | grep -q "^[0-9]*\.[0-9]*$"; then
      printf "%.2f" "$VALUE"
    else
      echo "$VALUE"
    fi
  fi
}

# Extract metrics
echo "Extracting metrics from Virtual Threads summary file..."
VT_REQS=$(extract_value "$VT_SUMMARY_FILE" "metrics.http_reqs.rate" "0")
VT_AVG=$(extract_value "$VT_SUMMARY_FILE" "metrics.http_req_duration.avg" "0")
VT_MED=$(extract_value "$VT_SUMMARY_FILE" "metrics.http_req_duration.med" "0")
VT_P95=$(extract_value "$VT_SUMMARY_FILE" "metrics.http_req_duration.p(95)" "0")
VT_MAX=$(extract_value "$VT_SUMMARY_FILE" "metrics.http_req_duration.max" "0")
VT_MIN=$(extract_value "$VT_SUMMARY_FILE" "metrics.http_req_duration.min" "0")
VT_ITER_MAX=$(extract_value "$VT_SUMMARY_FILE" "metrics.iteration_duration.max" "0")
VT_ITER_P95=$(extract_value "$VT_SUMMARY_FILE" "metrics.iteration_duration.p(95)" "0")

echo "Extracting metrics from WebFlux summary file..."
WF_REQS=$(extract_value "$WF_SUMMARY_FILE" "metrics.http_reqs.rate" "0")
WF_AVG=$(extract_value "$WF_SUMMARY_FILE" "metrics.http_req_duration.avg" "0")
WF_MED=$(extract_value "$WF_SUMMARY_FILE" "metrics.http_req_duration.med" "0")
WF_P95=$(extract_value "$WF_SUMMARY_FILE" "metrics.http_req_duration.p(95)" "0")
WF_MAX=$(extract_value "$WF_SUMMARY_FILE" "metrics.http_req_duration.max" "0")
WF_MIN=$(extract_value "$WF_SUMMARY_FILE" "metrics.http_req_duration.min" "0")
WF_ITER_MAX=$(extract_value "$WF_SUMMARY_FILE" "metrics.iteration_duration.max" "0")
WF_ITER_P95=$(extract_value "$WF_SUMMARY_FILE" "metrics.iteration_duration.p(95)" "0")

# Set default values if empty
[ -z "$VT_ITER_MAX" ] && VT_ITER_MAX="0"
[ -z "$VT_ITER_P95" ] && VT_ITER_P95="0"
[ -z "$WF_ITER_MAX" ] && WF_ITER_MAX="0"
[ -z "$WF_ITER_P95" ] && WF_ITER_P95="0"

# Print extracted values for verification
echo "Extracted metrics:"
echo "VT requests/sec: $VT_REQS"
echo "WF requests/sec: $WF_REQS"
echo "VT average: $VT_AVG"
echo "WF average: $WF_AVG"

# Calculate response time range
VT_RANGE=$(echo "$VT_MAX - $VT_MIN" | bc 2>/dev/null || echo "0")
WF_RANGE=$(echo "$WF_MAX - $WF_MIN" | bc 2>/dev/null || echo "0")

# Standardize decimal places
VT_RANGE=$(printf "%.2f" $VT_RANGE)
WF_RANGE=$(printf "%.2f" $WF_RANGE)

# Calculate differences
if [ "$WF_REQS" != "0" ] && [ "$VT_REQS" != "0" ]; then
  DIFF_PCT=$(echo "scale=2; ($VT_REQS - $WF_REQS) * 100 / $WF_REQS" | bc 2>/dev/null || echo "N/A")
  DIFF_PCT=$(printf "%.2f" $DIFF_PCT)
else
  DIFF_PCT="N/A"
fi

# Determine which approach is better for each metric
if (( $(echo "$VT_AVG < $WF_AVG" | bc -l 2>/dev/null || echo "0") )); then
  AVG_BETTER="VT"
else
  AVG_BETTER="WF"
fi

if (( $(echo "$VT_MED < $WF_MED" | bc -l 2>/dev/null || echo "0") )); then
  MED_BETTER="VT"
else
  MED_BETTER="WF"
fi

if (( $(echo "$VT_P95 < $WF_P95" | bc -l 2>/dev/null || echo "0") )); then
  P95_BETTER="VT"
else
  P95_BETTER="WF"
fi

if (( $(echo "$VT_MAX < $WF_MAX" | bc -l 2>/dev/null || echo "0") )); then
  MAX_BETTER="VT"
else
  MAX_BETTER="WF"
fi

if (( $(echo "$VT_RANGE < $WF_RANGE" | bc -l 2>/dev/null || echo "0") )); then
  RANGE_BETTER="VT"
else
  RANGE_BETTER="WF"
fi

if (( $(echo "$VT_ITER_MAX < $WF_ITER_MAX" | bc -l 2>/dev/null || echo "0") )); then
  ITER_MAX_BETTER="VT"
else
  ITER_MAX_BETTER="WF"
fi

if (( $(echo "$VT_ITER_P95 < $WF_ITER_P95" | bc -l 2>/dev/null || echo "0") )); then
  ITER_P95_BETTER="VT"
else
  ITER_P95_BETTER="WF"
fi

# Create markdown comparison table
echo "Creating markdown comparison file: $COMPARISON_FILE"

# Start markdown file
cat > "$COMPARISON_FILE" << EOL
# Performance Comparison of Virtual Threads (VT) and WebFlux (WF) Gateways

Test time: $(date)
Test method: Sequential execution (each gateway uses dedicated backend)

## 1. Request Throughput

| Metric | Virtual Threads (VT) | WebFlux (WF) | Difference (%) |
|--------|----------------|------------|----------|
| Requests/sec | ${VT_REQS} | ${WF_REQS} | ${DIFF_PCT}% |

## 2. Response Time

| Metric | Virtual Threads (VT) | WebFlux (WF) | Better |
|--------|----------------|------------|--------|
| Average response time | ${VT_AVG}ms | ${WF_AVG}ms | ${AVG_BETTER} |
| Median | ${VT_MED}ms | ${WF_MED}ms | ${MED_BETTER} |
| 95% response time | ${VT_P95}ms | ${WF_P95}ms | ${P95_BETTER} |
| Maximum response time | ${VT_MAX}ms | ${WF_MAX}ms | ${MAX_BETTER} |

## 3. Stability and Consistency

| Metric | Virtual Threads (VT) | WebFlux (WF) | Better |
|-----|----------------|------------|--------|
| Response time range | ${VT_RANGE}ms | ${WF_RANGE}ms | ${RANGE_BETTER} |
| Maximum execution time | ${VT_ITER_MAX}ms | ${WF_ITER_MAX}ms | ${ITER_MAX_BETTER} |
| 95% execution time | ${VT_ITER_P95}ms | ${WF_ITER_P95}ms | ${ITER_P95_BETTER} |

## Conclusion

**Note:** Each gateway was tested using a dedicated backend service, ensuring fair conditions without backend resource competition.

### Advantages of Virtual Threads (VT)
EOL

# Add Virtual Threads advantages
if [ "$P95_BETTER" = "VT" ] || [ "$MAX_BETTER" = "VT" ]; then
  echo "- More stable performance under high load (95% response time, maximum response time)" >> "$COMPARISON_FILE"
fi
if [ "$RANGE_BETTER" = "VT" ]; then
  echo "- Greater consistency in response times" >> "$COMPARISON_FILE"
fi
if [ "$ITER_MAX_BETTER" = "VT" ] || [ "$ITER_P95_BETTER" = "VT" ]; then
  echo "- More efficient for long-running tasks" >> "$COMPARISON_FILE"
fi

# Add WebFlux advantages
cat >> "$COMPARISON_FILE" << EOL

### Advantages of WebFlux (WF)
EOL

if [ "$AVG_BETTER" = "WF" ] || [ "$MED_BETTER" = "WF" ]; then
  echo "- Faster response times under normal conditions (average, median)" >> "$COMPARISON_FILE"
fi

# Add overall assessment
cat >> "$COMPARISON_FILE" << EOL

### Overall Assessment
EOL

BETTER_COUNT_VT=0
BETTER_COUNT_WF=0

for METRIC in "$AVG_BETTER" "$MED_BETTER" "$P95_BETTER" "$MAX_BETTER" "$RANGE_BETTER" "$ITER_MAX_BETTER" "$ITER_P95_BETTER"; do
  if [ "$METRIC" = "VT" ]; then
    BETTER_COUNT_VT=$((BETTER_COUNT_VT + 1))
  elif [ "$METRIC" = "WF" ]; then
    BETTER_COUNT_WF=$((BETTER_COUNT_WF + 1))
  fi
done

if [ $BETTER_COUNT_VT -gt $BETTER_COUNT_WF ]; then
  echo "- **Virtual Threads (VT)** performed better in ${BETTER_COUNT_VT} metrics." >> "$COMPARISON_FILE"
  if [ "$P95_BETTER" = "VT" ] || [ "$MAX_BETTER" = "VT" ]; then
    echo "- Virtual Threads are recommended especially when stable performance is needed under high load." >> "$COMPARISON_FILE"
  fi
elif [ $BETTER_COUNT_WF -gt $BETTER_COUNT_VT ]; then
  echo "- **WebFlux (WF)** performed better in ${BETTER_COUNT_WF} metrics." >> "$COMPARISON_FILE"
  if [ "$AVG_BETTER" = "WF" ] || [ "$MED_BETTER" = "WF" ]; then
    echo "- WebFlux is recommended when average response time is important." >> "$COMPARISON_FILE"
  fi
else
  echo "- Both approaches showed similar performance and should be selected based on the use case." >> "$COMPARISON_FILE"
fi

echo "Markdown comparison file has been created: $COMPARISON_FILE"

# Preview file contents
echo "=== Comparison Report Preview ==="
cat "$COMPARISON_FILE" | head -n 20
echo "..."
echo "To view the full report: cat $COMPARISON_FILE"

exit 0 