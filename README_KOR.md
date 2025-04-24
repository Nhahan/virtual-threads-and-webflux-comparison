> *[ENGLISH_README](README.md)*

# 가상 스레드(Virtual Threads)와 웹플럭스(WebFlux) 성능 비교

이 프로젝트는 Java 21+ 가상 스레드와 Spring WebFlux의 성능을 비교하기 위한 테스트 환경을 제공합니다.

## 개요

이 테스트 환경은 다음 구성 요소로 이루어져 있습니다:

- **가상 스레드 게이트웨이**: Java 21+ 가상 스레드를 사용하는 Spring Cloud Gateway
- **웹플럭스 게이트웨이**: 전통적인 Spring WebFlux 기반의 Spring Cloud Gateway
- **백엔드 서비스**: 각 게이트웨이를 위한 별도의 Spring Boot (Kotlin) 백엔드 서비스

모든 구성 요소는 Docker 컨테이너로 실행되며, k6를 사용한 부하 테스트로 성능을 측정합니다.

## 시작하기

### 요구 사항

![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white) 

### 테스트 실행 방법

```bash
./run_tests.sh
```

## 테스트 결과 해석

테스트가 완료되면 `results` 디렉토리에 결과가 생성됩니다:

## 비교

| 지표 | 가상 스레드 | 웹플럭스 | 비교 |
|------|------------|---------|------|
| 초당 요청 수 (http_reqs rate) | 777.48 요청/초 | 849.02 요청/초 | 웹플럭스 약 9% 높음 (더 나은 처리량) |
| 평균 응답 시간 (http_req_duration avg) | 986.75 ms | 903.57 ms | 웹플럭스 약 83ms 빠름 (더 나은 지연 시간) |
| 중앙값 응답 시간 (http_req_duration med) | 964.18 ms | 882.92 ms | 웹플럭스 약 81ms 빠름 |
| p(95) 응답 시간 (http_req_duration p95) | 1808.11 ms | 1635.26 ms | 웹플럭스 약 173ms 빠름 |
| 평균 대기 시간 (http_req_waiting avg) | 934.81 ms | 855.28 ms | 웹플럭스 약 79ms 짧음 |
| p(95) 대기 시간 (http_req_waiting p95) | 1758.40 ms | 1596.66 ms | 웹플럭스 약 162ms 짧음 |
| 성공한 검사 수 (50초 동안) | 77,862 | 85,020 | 웹플럭스가 약 7,158건 더 많은 검사 완료, 더 높은 처리량 반영 |
| 평균 반복 시간 (iteration_duration avg) | 1067.98 ms | 981.38 ms | 웹플럭스 더 짧음 |
| 데이터 수신 속도 (data_received rate) | 약 194 KB/초 | 약 212 KB/초 | 웹플럭스 약간 높음 |

아래 차트는 k6 테스트 결과를 기반으로 가상 스레드와 웹플럭스 구현 간의 주요 시간 기반 성능 지표(응답 시간, 대기 시간(밀리초))의 시각적 비교를 보여줍니다:

![image](https://github.com/user-attachments/assets/9493effe-a934-4031-a31c-188794d90cfb)

[성능 비교 차트 보기 (시간 단위: ms)](https://image-charts.com/chart?cht=bvg&chs=700x400&chd=t:986.75,1808.11,934.81,1758.40|903.57,1635.26,855.28,1596.66&chds=0,1900&chxt=x,y&chxl=0:|Avg+Resp|P95+Resp|Avg+Wait|P95+Wait&chco=4D89F9,00AEEF&chdl=Virtual+Threads|WebFlux&chdlp=b&chtt=Performance+Comparison+(Time+in+ms)&chma=0,0,0,20&chbh=a)

*참고: 이 차트는 시간 기반 지표(밀리초)에 중점을 둡니다. 초당 요청 수와 같은 처리량 지표는 스케일 차이로 인해 포함되지 않았습니다.*

## 최종 분석

제공된 k6 테스트 결과 표에 따르면, 50초 테스트 기간 동안 WebFlux 기반 구현이 가상 스레드 기반 구현보다 전반적으로 우수한 성능을 보여주었습니다. 더 높은 요청 처리량(`http_reqs rate`에서 확인 가능하며 약 7,158건 더 많은 성공한 검사 완료)과 더 낮은 평균 및 p(95) 응답 시간(지연 시간)을 달성했습니다. 
