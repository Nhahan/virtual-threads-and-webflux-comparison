> *[한국어_README](README_KOR.md)*

# Performance Comparison of Virtual Threads and WebFlux

This project provides a test environment to compare the performance of Java 21+ Virtual Threads and Spring WebFlux.

## Overview

This test environment consists of the following components:

- **Virtual Threads Gateway**: Spring Cloud Gateway using Java 21+ virtual threads
- **WebFlux Gateway**: Traditional Spring Cloud Gateway based on Spring WebFlux
- **Backend Service**: Separate Spring Boot (Kotlin) backend services for each gateway

All components run as Docker containers, and performance is measured using k6 load tests.

## Getting Started

### Requirements

![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white) 

### How to Run Tests

```bash
./run_tests.sh
```

## Interpreting Test Results

After the test completes, the result is created in the `results` directory:

## Comparison

| Metric | Virtual Threads | WebFlux | Comparison |
|--------|----------------|---------|------------|
| Requests per Second (http_reqs rate) | 777.48 reqs/s | 849.02 reqs/s | WebFlux ~9% higher (Better Throughput) |
| Avg Response Time (http_req_duration avg) | 986.75 ms | 903.57 ms | WebFlux ~83ms faster (Better Latency) |
| Median Response Time (http_req_duration med) | 964.18 ms | 882.92 ms | WebFlux ~81ms faster |
| p(95) Response Time (http_req_duration p95) | 1808.11 ms | 1635.26 ms | WebFlux ~173ms faster |
| Avg Waiting Time (http_req_waiting avg) | 934.81 ms | 855.28 ms | WebFlux ~79ms shorter |
| p(95) Waiting Time (http_req_waiting p95) | 1758.40 ms | 1596.66 ms | WebFlux ~162ms shorter |
| Successful Checks (in 50s) | 77,862 | 85,020 | WebFlux completed ~7,158 more successful checks, reflecting higher throughput |
| Avg Iteration Duration (iteration_duration avg) | 1067.98 ms | 981.38 ms | WebFlux shorter |
| Data Received Rate (data_received rate) | ~194 KB/s | ~212 KB/s | WebFlux slightly higher |

See the chart below for a visual comparison of key time-based performance metrics (response time, wait time in milliseconds) between the Virtual Threads and WebFlux implementations based on k6 test results:

![image](https://github.com/user-attachments/assets/9493effe-a934-4031-a31c-188794d90cfb)

[View Performance Comparison Chart (Time in ms)](https://image-charts.com/chart?cht=bvg&chs=700x400&chd=t:986.75,1808.11,934.81,1758.40|903.57,1635.26,855.28,1596.66&chds=0,1900&chxt=x,y&chxl=0:|Avg+Resp|P95+Resp|Avg+Wait|P95+Wait&chco=4D89F9,00AEEF&chdl=Virtual+Threads|WebFlux&chdlp=b&chtt=Performance+Comparison+(Time+in+ms)&chma=0,0,0,20&chbh=a)

*Note: This chart focuses on time-based metrics (milliseconds). Throughput metrics like Requests Per Second are not included due to scale differences.*

## Final Analysis

According to the provided k6 test results table, the WebFlux-based implementation demonstrated superior overall performance compared to the Virtual Threads-based implementation during the 50-second test duration. It achieved higher request throughput (evidenced by `http_reqs rate` and completing approximately 7,158 more successful checks) and lower average and p(95) response times (latency).
