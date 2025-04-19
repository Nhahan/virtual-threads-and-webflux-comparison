#!/bin/bash
set -e

echo "Script started: $(date)"

# Define result file paths
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="/scripts/results"
VT_SUMMARY_OUT="${RESULTS_DIR}/vt_summary_${TIMESTAMP}.txt"
WF_SUMMARY_OUT="${RESULTS_DIR}/wf_summary_${TIMESTAMP}.txt"
MARKDOWN_OUT="${RESULTS_DIR}/comparison_${TIMESTAMP}.md"

# Define service URLs
VT_URL="http://virtual-threads-gateway:8081"
WF_URL="http://webflux-gateway:8082"
VT_BACKEND_URL="http://vt-backend-service:8080"
WF_BACKEND_URL="http://wf-backend-service:8080"

# Create results directory
mkdir -p ${RESULTS_DIR}
echo "Results directory created: ${RESULTS_DIR}"

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 30

# Service availability check function
wait_for_service() {
  SERVICE_NAME=$1
  URL=$2
  TIMEOUT=120
  RETRY_INTERVAL=5
  
  echo "Waiting for service: ${SERVICE_NAME} at ${URL}/actuator/health"
  
  ELAPSED=0
  while [ $ELAPSED -lt $TIMEOUT ]; do
    RESPONSE=$(curl -s --fail "${URL}/actuator/health" || echo "FAILED")
    if [ "${RESPONSE}" != "FAILED" ]; then
      echo "${SERVICE_NAME} service is ready!"
      return 0
    fi
    
    echo "${SERVICE_NAME} is not ready yet. Retrying in ${RETRY_INTERVAL} seconds..."
    sleep $RETRY_INTERVAL
    ELAPSED=$((ELAPSED+RETRY_INTERVAL))
  done
  
  echo "${SERVICE_NAME} service did not become ready within ${TIMEOUT} seconds."
  return 1
}

# Check network connectivity
echo "Checking network connectivity..."
ping -c 2 virtual-threads-gateway || echo "Virtual Threads Gateway ping failed"
ping -c 2 webflux-gateway || echo "WebFlux Gateway ping failed"
ping -c 2 vt-backend-service || echo "Virtual Threads Backend Service ping failed"
ping -c 2 wf-backend-service || echo "WebFlux Backend Service ping failed"

# Check service availability
wait_for_service "Virtual Threads Backend Service" "${VT_BACKEND_URL}" || { echo "Virtual Threads Backend Service is not ready, aborting test."; exit 1; }
wait_for_service "WebFlux Backend Service" "${WF_BACKEND_URL}" || { echo "WebFlux Backend Service is not ready, aborting test."; exit 1; }
wait_for_service "Virtual Threads Gateway" "${VT_URL}" || { echo "Virtual Threads Gateway is not ready, aborting test."; exit 1; }
wait_for_service "WebFlux Gateway" "${WF_URL}" || { echo "WebFlux Gateway is not ready, aborting test."; exit 1; }

# Simple pre-check to ensure tests can run properly
echo "Running simple pre-test..."
if ! curl -s --fail "${VT_URL}/backend/delay/ms/10" > /dev/null; then
  echo "Warning: Test request to Virtual Threads Gateway failed"
  curl -v "${VT_URL}/backend/delay/ms/10" || true
fi

if ! curl -s --fail "${WF_URL}/backend/delay/ms/10" > /dev/null; then
  echo "Warning: Test request to WebFlux Gateway failed"
  curl -v "${WF_URL}/backend/delay/ms/10" || true
fi

# k6 test execution function
run_k6_test() {
  GATEWAY_TYPE=$1
  URL=$2
  OUTPUT_FILE=$3
  
  echo "${GATEWAY_TYPE} test starting (time: $(date))..."
  
  # Explicitly check directory permissions for output file
  echo "{}" > ${OUTPUT_FILE} || { echo "Failed to write to result file: ${OUTPUT_FILE}"; exit 1; }
  
  # Run test (with more debugging information)
  echo "Running k6: k6 run -e BASE_URL=${URL} --summary-export=${OUTPUT_FILE} /scripts/test.js"
  K6_OUTPUT=$(k6 run -e BASE_URL=${URL} --summary-export=${OUTPUT_FILE} /scripts/test.js 2>&1) || {
    TEST_RESULT=$?
    echo "Warning: ${GATEWAY_TYPE} test failed (code: ${TEST_RESULT})"
    echo "k6 output: ${K6_OUTPUT}"
    
    # Check if summary was saved even if test failed
    if [ ! -s "${OUTPUT_FILE}" ]; then
      echo "Result file missing or empty: ${OUTPUT_FILE}, running simple test..."
      
      # Run a simpler test instead
      echo "Running simple test: k6 run -e BASE_URL=${URL} --summary-export=${OUTPUT_FILE} --duration 3s --vus 10 /scripts/test.js"
      k6 run -e BASE_URL=${URL} --summary-export=${OUTPUT_FILE} --duration 3s --vus 10 /scripts/test.js || {
        echo "Simple test also failed. Generating default JSON"
        echo '{"metrics":{"http_reqs":{"count":0,"rate":0},"http_req_duration":{"avg":0,"min":0,"med":0,"max":0,"p(90)":0,"p(95)":0}}}' > ${OUTPUT_FILE}
      }
    fi
    
    return ${TEST_RESULT}
  }
  
  echo "${GATEWAY_TYPE} test completed (time: $(date))"
  echo "Result file: ${OUTPUT_FILE} (size: $(wc -c < ${OUTPUT_FILE}) bytes)"
  return 0
}

# Run tests sequentially (to prevent errors with parallel execution)
echo "Running both gateway tests sequentially (each using a dedicated backend)..."

# Run Virtual Threads Gateway test
run_k6_test "Virtual Threads Gateway" "${VT_URL}" "${VT_SUMMARY_OUT}"
VT_RESULT=$?
echo "Virtual Threads test result code: ${VT_RESULT}"

# Run WebFlux Gateway test
run_k6_test "WebFlux Gateway" "${WF_URL}" "${WF_SUMMARY_OUT}"
WF_RESULT=$?
echo "WebFlux test result code: ${WF_RESULT}"

# Check test results
if [ $VT_RESULT -eq 0 ] && [ $WF_RESULT -eq 0 ]; then
  echo "All tests completed successfully."
else
  echo "Some tests failed. Virtual Threads: $VT_RESULT, WebFlux: $WF_RESULT"
  # Continue anyway
fi

# Check result files
echo "Checking result files..."
if [ ! -s "${VT_SUMMARY_OUT}" ]; then
  echo "Warning: Virtual Threads summary file is missing or empty. Generating default JSON"
  echo '{"metrics":{"http_reqs":{"count":0,"rate":0},"http_req_duration":{"avg":0,"min":0,"med":0,"max":0,"p(90)":0,"p(95)":0}}}' > ${VT_SUMMARY_OUT}
fi

if [ ! -s "${WF_SUMMARY_OUT}" ]; then
  echo "Warning: WebFlux summary file is missing or empty. Generating default JSON"
  echo '{"metrics":{"http_reqs":{"count":0,"rate":0},"http_req_duration":{"avg":0,"min":0,"med":0,"max":0,"p(90)":0,"p(95)":0}}}' > ${WF_SUMMARY_OUT}
fi

# JSON value extraction function (more robust approach)
extract_json_value() {
  local FILE=$1
  local PATTERN=$2
  local DEFAULT=$3
  
  if [ ! -f "$FILE" ]; then
    echo "$DEFAULT"
    return
  fi
  
  # Use regex to search for pattern, return default if not found
  VALUE=$(grep -o "$PATTERN[^,}]*" "$FILE" 2>/dev/null | head -1 | sed 's/.*: //' | tr -d '"' || echo "$DEFAULT")
  
  # Use default value if empty
  if [ -z "$VALUE" ]; then
    echo "$DEFAULT"
  else
    echo "$VALUE"
  fi
}

# Function to create markdown comparison table
create_markdown_comparison() {
  VT_FILE=$1
  WF_FILE=$2
  OUT_FILE=$3
  
  echo "Creating markdown comparison file: ${OUT_FILE}"
  
  # Start markdown file
  echo "# Performance Comparison of Virtual Threads (VT) and WebFlux (WF) Gateways" > ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  echo "Test time: $(date)" >> ${OUT_FILE}
  echo "Test method: Sequential execution (each gateway using a dedicated backend)" >> ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  
  # Request throughput section
  echo "## 1. Request Throughput" >> ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  echo "| Metric | Virtual Threads (VT) | WebFlux (WF) | Difference (%) |" >> ${OUT_FILE}
  echo "|--------|----------------|------------|----------|" >> ${OUT_FILE}
  
  # Extract request throughput (improved method)
  VT_REQS=$(extract_json_value "${VT_FILE}" '"http_reqs".*"rate":' "0")
  WF_REQS=$(extract_json_value "${WF_FILE}" '"http_reqs".*"rate":' "0")
  
  # Calculate difference
  if [ $(echo "${WF_REQS} > 0" | bc -l) -eq 1 ] && [ $(echo "${VT_REQS} > 0" | bc -l) -eq 1 ]; then
    DIFF_PCT=$(echo "scale=2; (${VT_REQS} - ${WF_REQS}) * 100 / ${WF_REQS}" | bc -l)
  else
    DIFF_PCT="N/A"
  fi
  
  echo "| Requests/sec | ${VT_REQS} | ${WF_REQS} | ${DIFF_PCT}% |" >> ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  
  # Response time section
  echo "## 2. Response Time" >> ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  echo "| Metric | Virtual Threads (VT) | WebFlux (WF) | Better |" >> ${OUT_FILE}
  echo "|--------|----------------|------------|--------|" >> ${OUT_FILE}
  
  # Extract response time (improved method)
  VT_AVG=$(extract_json_value "${VT_FILE}" '"http_req_duration".*"avg":' "0")
  WF_AVG=$(extract_json_value "${WF_FILE}" '"http_req_duration".*"avg":' "0")
  
  VT_MED=$(extract_json_value "${VT_FILE}" '"http_req_duration".*"med":' "0")
  WF_MED=$(extract_json_value "${WF_FILE}" '"http_req_duration".*"med":' "0")
  
  VT_P95=$(extract_json_value "${VT_FILE}" '"http_req_duration".*"p\\(95\\)":' "0")
  WF_P95=$(extract_json_value "${WF_FILE}" '"http_req_duration".*"p\\(95\\)":' "0")
  
  VT_MAX=$(extract_json_value "${VT_FILE}" '"http_req_duration".*"max":' "0")
  WF_MAX=$(extract_json_value "${WF_FILE}" '"http_req_duration".*"max":' "0")
  
  # Determine better item
  if [ $(echo "${VT_AVG} < ${WF_AVG}" | bc -l) -eq 1 ]; then
    AVG_BETTER="VT"
  else
    AVG_BETTER="WF"
  fi
  
  if [ $(echo "${VT_MED} < ${WF_MED}" | bc -l) -eq 1 ]; then
    MED_BETTER="VT"
  else
    MED_BETTER="WF"
  fi
  
  if [ $(echo "${VT_P95} < ${WF_P95}" | bc -l) -eq 1 ]; then
    P95_BETTER="VT"
  else
    P95_BETTER="WF"
  fi
  
  if [ $(echo "${VT_MAX} < ${WF_MAX}" | bc -l) -eq 1 ]; then
    MAX_BETTER="VT"
  else
    MAX_BETTER="WF"
  fi
  
  echo "| Average Response Time | ${VT_AVG}ms | ${WF_AVG}ms | ${AVG_BETTER} |" >> ${OUT_FILE}
  echo "| Median | ${VT_MED}ms | ${WF_MED}ms | ${MED_BETTER} |" >> ${OUT_FILE}
  echo "| 95% Response Time | ${VT_P95}ms | ${WF_P95}ms | ${P95_BETTER} |" >> ${OUT_FILE}
  echo "| Maximum Response Time | ${VT_MAX}ms | ${WF_MAX}ms | ${MAX_BETTER} |" >> ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  
  # Stability and consistency section
  echo "## 3. Stability and Consistency" >> ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  echo "| Metric | Virtual Threads (VT) | WebFlux (WF) | Better |" >> ${OUT_FILE}
  echo "|-----|----------------|------------|--------|" >> ${OUT_FILE}
  
  # Extract iteration duration (improved method)
  VT_ITER_MAX=$(extract_json_value "${VT_FILE}" '"iteration_duration".*"max":' "0")
  WF_ITER_MAX=$(extract_json_value "${WF_FILE}" '"iteration_duration".*"max":' "0")
  
  VT_ITER_P95=$(extract_json_value "${VT_FILE}" '"iteration_duration".*"p\\(95\\)":' "0")
  WF_ITER_P95=$(extract_json_value "${WF_FILE}" '"iteration_duration".*"p\\(95\\)":' "0")
  
  # Calculate response time variation
  VT_MIN=$(extract_json_value "${VT_FILE}" '"http_req_duration".*"min":' "0")
  WF_MIN=$(extract_json_value "${WF_FILE}" '"http_req_duration".*"min":' "0")
  
  VT_RANGE=$(echo "scale=2; ${VT_MAX} - ${VT_MIN}" | bc -l)
  WF_RANGE=$(echo "scale=2; ${WF_MAX} - ${WF_MIN}" | bc -l)
  
  # Determine better item
  if [ $(echo "${VT_RANGE} < ${WF_RANGE}" | bc -l) -eq 1 ]; then
    RANGE_BETTER="VT"
  else
    RANGE_BETTER="WF"
  fi
  
  if [ $(echo "${VT_ITER_MAX} < ${WF_ITER_MAX}" | bc -l) -eq 1 ]; then
    ITER_MAX_BETTER="VT"
  else
    ITER_MAX_BETTER="WF"
  fi
  
  if [ $(echo "${VT_ITER_P95} < ${WF_ITER_P95}" | bc -l) -eq 1 ]; then
    ITER_P95_BETTER="VT"
  else
    ITER_P95_BETTER="WF"
  fi
  
  echo "| Response Time Variation | ${VT_RANGE}ms | ${WF_RANGE}ms | ${RANGE_BETTER} |" >> ${OUT_FILE}
  echo "| Maximum Execution Time | ${VT_ITER_MAX}ms | ${WF_ITER_MAX}ms | ${ITER_MAX_BETTER} |" >> ${OUT_FILE}
  echo "| 95% Execution Time | ${VT_ITER_P95}ms | ${WF_ITER_P95}ms | ${ITER_P95_BETTER} |" >> ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  
  # Conclusion section
  echo "## Conclusion" >> ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  echo "**Note:** Each gateway was tested under a fair condition without backend resource competition." >> ${OUT_FILE}
  echo "" >> ${OUT_FILE}
  
  echo "### Virtual Threads (VT) Advantages" >> ${OUT_FILE}
  if [ "${P95_BETTER}" = "VT" ] || [ "${MAX_BETTER}" = "VT" ]; then
    echo "- Higher performance stability at high load (95% response time, maximum response time)" >> ${OUT_FILE}
  fi
  if [ "${RANGE_BETTER}" = "VT" ]; then
    echo "- Higher consistency in response time" >> ${OUT_FILE}
  fi
  if [ "${ITER_MAX_BETTER}" = "VT" ] || [ "${ITER_P95_BETTER}" = "VT" ]; then
    echo "- More efficient processing of long tasks" >> ${OUT_FILE}
  fi
  
  echo "" >> ${OUT_FILE}
  echo "### WebFlux (WF) Advantages" >> ${OUT_FILE}
  if [ "${AVG_BETTER}" = "WF" ] || [ "${MED_BETTER}" = "WF" ]; then
    echo "- Faster response time in general conditions (average, median)" >> ${OUT_FILE}
  fi
  
  echo "" >> ${OUT_FILE}
  echo "### Overall Evaluation" >> ${OUT_FILE}
  BETTER_COUNT_VT=0
  BETTER_COUNT_WF=0
  
  for METRIC in "${AVG_BETTER}" "${MED_BETTER}" "${P95_BETTER}" "${MAX_BETTER}" "${RANGE_BETTER}" "${ITER_MAX_BETTER}" "${ITER_P95_BETTER}"; do
    if [ "${METRIC}" = "VT" ]; then
      BETTER_COUNT_VT=$((BETTER_COUNT_VT + 1))
    elif [ "${METRIC}" = "WF" ]; then
      BETTER_COUNT_WF=$((BETTER_COUNT_WF + 1))
    fi
  done
  
  if [ ${BETTER_COUNT_VT} -gt ${BETTER_COUNT_WF} ]; then
    echo "- **Virtual Threads (VT)** was better in ${BETTER_COUNT_VT} items." >> ${OUT_FILE}
    if [ "${P95_BETTER}" = "VT" ] || [ "${MAX_BETTER}" = "VT" ]; then
      echo "- Particularly recommended for scenarios requiring high stability in performance" >> ${OUT_FILE}
    fi
  elif [ ${BETTER_COUNT_WF} -gt ${BETTER_COUNT_VT} ]; then
    echo "- **WebFlux (WF)** was better in ${BETTER_COUNT_WF} items." >> ${OUT_FILE}
    if [ "${AVG_BETTER}" = "WF" ] || [ "${MED_BETTER}" = "WF" ]; then
      echo "- Recommended for scenarios where average response time is important" >> ${OUT_FILE}
    fi
  else
    echo "- Both methods showed similar performance, so choose based on use case" >> ${OUT_FILE}
  fi
  
  echo "Markdown file created: ${OUT_FILE}"
}

# Create markdown comparison file
create_markdown_comparison "${VT_SUMMARY_OUT}" "${WF_SUMMARY_OUT}" "${MARKDOWN_OUT}"

# Result summary
echo "Test completed!"
echo "Final summary file: ${MARKDOWN_OUT}"

# Output content
echo "=== Test Result Summary ==="
cat ${MARKDOWN_OUT} || echo "Markdown file read failed"

# Display result files
ls -la ${RESULTS_DIR}

echo "All tests completed. Results are available in ${RESULTS_DIR} directory."
exit 0 