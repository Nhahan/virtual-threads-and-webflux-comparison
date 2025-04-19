#!/bin/bash

# Script for running performance comparison tests between Virtual Threads and WebFlux gateways
# Usage: ./run_tests.sh

# Create results directory
mkdir -p ./results

echo "🚀 Starting gateway performance tests..."

# Clean up previous test containers (keep images)
echo "🧹 Cleaning up previous test containers..."
docker-compose down 2>/dev/null || true

# Always rebuild reporter image (because it includes entrypoint.sh)
echo "🔨 Rebuilding reporter image..."
docker-compose build --no-cache reporter

# Run tests (without rebuilding other images)
echo "🔍 Running tests..."
docker-compose up --exit-code-from reporter

# Check test results
RESULT=$?
if [ $RESULT -eq 0 ]; then
  echo "✅ Tests completed! Results are saved in the ./results directory."
  echo "📊 Result files:"
  ls -l ./results
  
  # Find the most recent summary files
  LATEST_VT_SUMMARY=$(find ./results -name "vt_summary_*.txt" | sort -r | head -n 1)
  LATEST_WF_SUMMARY=$(find ./results -name "wf_summary_*.txt" | sort -r | head -n 1)
  
  if [ -n "$LATEST_VT_SUMMARY" ] && [ -n "$LATEST_WF_SUMMARY" ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    COMPARISON_FILE="./results/comparison_${TIMESTAMP}.md"
    
    echo "📈 Generating performance comparison report..."
    chmod +x ./scripts/generate_report.sh
    ./scripts/generate_report.sh "$LATEST_VT_SUMMARY" "$LATEST_WF_SUMMARY" "$COMPARISON_FILE"
    
    # Check results
    if [ -f "$COMPARISON_FILE" ]; then
      echo "📊 Performance comparison report has been generated: $COMPARISON_FILE"
    else
      echo "❌ Failed to generate performance comparison report."
    fi
  else
    echo "⚠️ Could not find summary files to generate performance comparison report."
  fi
else
  echo "❌ An error occurred during test execution. (Exit code: $RESULT)"
fi

# Clean up test containers after testing (keep images)
echo "🧹 Cleaning up test containers..."
docker-compose down

echo "🏁 Test process completed!" 