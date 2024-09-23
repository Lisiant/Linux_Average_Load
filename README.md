# ⚡️ Average Load 이해 및 테스트

### 📝 개요

평균 부하 테스트는 시스템 성능과 안정성을 평가하기 위해 다양한 부하를 가하여, CPU, 메모리, 디스크 I/O, 네트워크 등의 자원 사용을 분석하는 과정입니다. 이를 통해 시스템의 성능 한계와 병목 현상을 파악하고, 지속적인 부하나 피크 부하 상황에서 시스템이 얼마나 안정적으로 작동하는지 확인하며, 확장성에 대한 평가도 가능해집니다.

Linux 환경에서는 시스템 속도를 파악하기 위해 `uptime` 명령어를 주로 사용합니다.

```bash
$ uptime
12:19:10 up  3:12,  4 users,  load average: 0.14, 0.14, 0.16
```

처음 3개 항목의 의미는 현재 시간, 시스템 가동 시간, 로그인 사용자 수를 나타냅니다.

마지막 세 개의 숫자는 각각 지난 1분, 5분, 15분 동안의 평균 부하(Average Load)를 나타냅니다. 이는 일정 시간 동안 **실행 가능 상태(Runnable)** 또는 **중단 불가 상태(Uninterruptible)** 에 있는 프로세스의 평균 수를 나타냅니다.

여기서 평균 부하에 대해 심층적으로 알아보았습니다.

### 프로세스 상태

- `Runnable` : CPU를 사용 중이거나 CPU를 기다리는 프로세스 
    - R state
      
- `Uninterruptible sleep` : 주로 I/O 작업을 대기하는 프로세스
  
    - 중단될 수 없으며, 보통 Disk I/O를 기다립니다.  
    - D state  

### Average Load와 CPU 개수

Average Load는 활성 프로세스의 평균 수입니다. 따라서 Average Load 값이 클수록 더 많은 프로세스가 활동 중이거나 자원을 기다리고 있는 상태를 의미합니다.

*`Average Load = 2`일 때 의미 - CPU 개수에 따른 분류*

- 2개 : 모든 CPU가 사용 중
- 4개 : 50%의 유휴 CPU 용량 존재
- 1개 : 프로세스의 절반이 CPU 시간을 놓고 경쟁

이상적으로는 CPU 하나 당 한 개의 프로세스가 실행되는 것이 최적의 상태이지만, 많은 프로세스가 동시에 실행되는 경우 이는 충족되기 어렵습니다.

시스템의 CPU 수와 비교하여 Average Load가 더 크다면, CPU는 과부하 상태일 수 있습니다.

### 평가

Average Load 값의 추세를 보아 시스템 상태를 파악할 수 있습니다.

- **1분**, **5분**, **15분**의 Average Load 값이 비슷하면 시스템 부하가 **안정적**.
- **1분 값이 15분 값보다 낮으면** 최근 부하가 감소 중.
- **1분 값이 15분 값보다 높으면** 최근 부하가 증가 중.

### CPU 사용량 vs. Average Load

그렇다면 CPU 사용량과 평균 부하는 같은 의미일까요?

이를 정확히 파악하기 위해서 각각의 정의를 알아보도록 하겠습니다.

- 평균 부하: 단위 시간당 실행 가능하고 중단 불가능한 상태의 프로세스 수를 말합니다.
- CPU 사용량: 단위 시간 동안 CPU가 얼마나 사용되는 지에 대한 통계

위 두가지 개념은 직접 일치하지는 않는 개념입니다.

1. CPU-Bound 프로세스 : 평균 부하를 증가시키고 CPU 사용량도 증가시킴
    
    → 두 가지 지표가 일치
    
2. I/O-Bound 프로세스: 평균 부하를 증가시키지만, CPU 사용량은 높지 않음
3. CPU 스케줄링을 기다리는 프로세스의 수가 많은 경우
    - 평균 부하 증가, CPU 사용량 증가

## 📈 예제를 통한 분석

CPU와 I/O 부하를 유발한 후 시스템의 Average Load를 분석하고, 그 원인을 `mpstat` 및 `pidstat` 명령어로 확인하는 예제를 진행하겠습니다.

### ☁️ 실습 환경

- Linux : Ubuntu 22.04.5
- CPU 6코어, 8GB RAM

### 1. 패키지 설치

- `stress`: 부하를 유발하는 도구
- `sysstat`: 시스템 성능 모니터링 도구 (`mpstat`, `pidstat` 포함)

```bash
sudo apt install stress sysstat
```

### 2. 현재 CPU 상태 확인

`uptime` 명령어로 실행 이전의 CPU 상태를 확인합니다.

```bash
$ uptime
14:09:41 up  4:11,  4 users,  load average: 0.40, 0.20, 0.16
```

### 3. CPU-Bound 작업으로 Average Load 확인

터미널을 3개 준비하여 각각에 터미널에서 명령어를 실행하여 평균 부하를 테스트합니다.

1. **CPU 부하 유발**
    
    첫 번째 터미널에서 `stress` 명령어로 CPU에 부하를 줍니다.
    
    1개의 CPU를 100% 사용하게 설정합니다.
    
    ```bash
    stress --cpu 1 --timeout 600
    stress: info: [7645] dispatching hogs: 1 cpu, 0 io, 0 vm, 0 hdd
    ```
    
2. **uptime의 변경사항을 모니터링하고 변경 시 파일 및 터미널에 출력**
    
    쉘 스크립트를 작성하여 uptime의 변경사항을 모니터링합니다.
    
    - `monitor_load.sh`
    
    ```bash
    #!/bin/bash
    
    # 이전 상태 저장할 파일
    prev_load=""
    
    # 로그를 기록할 파일 지정
    log_file="load_changes.log"
    
    while true; do
        # 현재 Average Load 가져오기
        current_load=$(uptime | awk -F'load average:' '{ print $2 }')
    
        # 이전 상태와 현재 상태 비교
        if [ "$prev_load" != "$current_load" ]; then
            echo "$(date): Average Load changed: $current_load" | tee -a $log_file
            prev_load=$current_load
        fi
    
        # 5초 대기 (주기적 실행)
        sleep 5
    done
    
    ```
    
    실행 권한을 추가하고 실행합니다.
    
    ```bash
    $ chmod u+x ./monitor_load.sh
    $ ./monitor_load.sh
    ```
    
    **결과**
    
    ```bash
    Mon Sep 23 02:31:00 PM KST 2024: Average Load changed:  0.22, 0.26, 0.29
    Mon Sep 23 02:31:02 PM KST 2024: Average Load changed:  0.28, 0.27, 0.29
    Mon Sep 23 02:31:08 PM KST 2024: Average Load changed:  0.34, 0.28, 0.29
    Mon Sep 23 02:31:12 PM KST 2024: Average Load changed:  0.39, 0.29, 0.30
    Mon Sep 23 02:31:18 PM KST 2024: Average Load changed:  0.44, 0.31, 0.30
    Mon Sep 23 02:31:22 PM KST 2024: Average Load changed:  0.49, 0.32, 0.31
    Mon Sep 23 02:31:28 PM KST 2024: Average Load changed:  0.53, 0.33, 0.31
    Mon Sep 23 02:31:32 PM KST 2024: Average Load changed:  0.57, 0.34, 0.31
    Mon Sep 23 02:31:38 PM KST 2024: Average Load changed:  0.60, 0.35, 0.32
    Mon Sep 23 02:31:42 PM KST 2024: Average Load changed:  0.63, 0.36, 0.32
    Mon Sep 23 02:31:48 PM KST 2024: Average Load changed:  0.66, 0.37, 0.33
    Mon Sep 23 02:31:52 PM KST 2024: Average Load changed:  0.77, 0.40, 0.33
    Mon Sep 23 02:31:58 PM KST 2024: Average Load changed:  0.79, 0.41, 0.34
    Mon Sep 23 02:32:02 PM KST 2024: Average Load changed:  0.81, 0.42, 0.34
    Mon Sep 23 02:32:08 PM KST 2024: Average Load changed:  0.82, 0.43, 0.35
    Mon Sep 23 02:32:12 PM KST 2024: Average Load changed:  0.84, 0.44, 0.35
    Mon Sep 23 02:32:18 PM KST 2024: Average Load changed:  0.85, 0.45, 0.35
    Mon Sep 23 02:32:22 PM KST 2024: Average Load changed:  0.86, 0.46, 0.36
    Mon Sep 23 02:32:28 PM KST 2024: Average Load changed:  0.87, 0.47, 0.36
    Mon Sep 23 02:32:32 PM KST 2024: Average Load changed:  0.88, 0.48, 0.37
    Mon Sep 23 02:32:38 PM KST 2024: Average Load changed:  0.89, 0.49, 0.37
    Mon Sep 23 02:32:42 PM KST 2024: Average Load changed:  0.90, 0.50, 0.37
    Mon Sep 23 02:32:48 PM KST 2024: Average Load changed:  0.99, 0.52, 0.38
    Mon Sep 23 02:32:52 PM KST 2024: Average Load changed:  0.99, 0.53, 0.38
    Mon Sep 23 02:32:58 PM KST 2024: Average Load changed:  0.99, 0.54, 0.39
    Mon Sep 23 02:33:02 PM KST 2024: Average Load changed:  0.99, 0.55, 0.39
    ```
    
    전체적인 CPU 사용량이 증가하는 추세로, 확인이 필요하다는 것을 알 수 있습니다.
    
3. **CPU 사용률 분석**
    
    `mpstat` 명령어로 모든 CPU의 성능을 5초 간격으로 터미널에 출력합니다.
    
    1번 CPU의 사용량이 100%으로 고정된 것을 확인할 수 있습니다.
    
    ```bash
    $ mpstat -P ALL 5
    ```
    
    ```bash
    02:31:10 PM  CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest  %gnice   %idle
    02:31:15 PM  all   16.87    0.03    0.10    0.03    0.00    0.17    0.00    0.00    0.00   82.79
    02:31:15 PM    0    0.20    0.00    0.20    0.00    0.00    0.40    0.00    0.00    0.00   99.20
    02:31:15 PM    1  100.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00
    02:31:15 PM    2    0.00    0.00    0.00    0.00    0.00    0.20    0.00    0.00    0.00   99.80
    02:31:15 PM    3    0.20    0.20    0.20    0.00    0.00    0.20    0.00    0.00    0.00   99.20
    02:31:15 PM    4    0.60    0.00    0.20    0.00    0.00    0.00    0.00    0.00    0.00   99.20
    02:31:15 PM    5    0.20    0.00    0.00    0.20    0.00    0.20    0.00    0.00    0.00   99.40
    ```
    
    `pidstat` 명령어로 CPU 부하의 원인을 찾습니다.
    
    ```bash
    Linux 5.15.0-122-generic (servername) 	09/23/2024 	_aarch64_	(6 CPU)
    
    02:32:01 PM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
    02:32:06 PM     0       375    0.00    0.20    0.00    0.00    0.20     0  jbd2/dm-0-8
    02:32:06 PM   114       709    0.60    0.20    0.00    0.00    0.80     1  java
    02:32:06 PM   115       714    0.20    0.00    0.00    0.00    0.20     4  node
    02:32:06 PM   998       740    0.20    0.20    0.00    0.00    0.40     3  java
    02:32:06 PM     0       741    0.20    0.20    0.00    0.00    0.40     5  containerd
    02:32:06 PM   113      1057    0.20    0.20    0.00    0.00    0.40     3  mysqld
    02:32:06 PM  1000      8066  100.00    0.00    0.00    0.00  100.00     1  stress
    02:32:06 PM  1000      8068    0.00    0.20    0.00    0.00    0.20     0  monitor_load.sh
    02:32:06 PM  1000      8237    0.00    0.20    0.00    0.00    0.20     3  pidstat
    ```
    
    ```bash
    $ pidstat -u 5
    ```
    
    - `stress` 프로세스로 인해 CPU 사용량이 증가했다는 것을 알 수 있습니다.

**결론**

CPU-Bound 작업으로 Average Load가 증가하는 것을 알 수 있습니다.

### 4. I/O Bound 작업으로 Average Load 확인

같은 방법으로 I/O Bound 프로세스로 Average Load가 증가되는지 확인해보았습니다.

1. `stress` 명령어로 I/O 프로세스 실행
    
    ```bash
    $ stress --io 1 --timeout 600 
    ```
    
2. 쉘 스크립트 실행
    
    스크립트는 앞서 작성한 `monitor_load.sh` 파일을 그대로 사용하였습니다.
    
    **결과**
    
    ```bash
    Mon Sep 23 02:36:04 PM KST 2024: Average Load changed:  0.33, 0.40, 0.36
    Mon Sep 23 02:36:08 PM KST 2024: Average Load changed:  0.38, 0.41, 0.36
    Mon Sep 23 02:36:14 PM KST 2024: Average Load changed:  0.43, 0.42, 0.36
    Mon Sep 23 02:36:18 PM KST 2024: Average Load changed:  0.48, 0.43, 0.37
    Mon Sep 23 02:36:24 PM KST 2024: Average Load changed:  0.52, 0.44, 0.37
    Mon Sep 23 02:36:28 PM KST 2024: Average Load changed:  0.56, 0.45, 0.37
    Mon Sep 23 02:36:34 PM KST 2024: Average Load changed:  0.59, 0.46, 0.38
    Mon Sep 23 02:36:38 PM KST 2024: Average Load changed:  0.63, 0.47, 0.38
    Mon Sep 23 02:36:44 PM KST 2024: Average Load changed:  0.66, 0.48, 0.38
    Mon Sep 23 02:36:48 PM KST 2024: Average Load changed:  0.68, 0.49, 0.39
    Mon Sep 23 02:36:54 PM KST 2024: Average Load changed:  0.71, 0.49, 0.39
    Mon Sep 23 02:36:58 PM KST 2024: Average Load changed:  0.73, 0.50, 0.39
    Mon Sep 23 02:37:04 PM KST 2024: Average Load changed:  0.75, 0.51, 0.40
    Mon Sep 23 02:37:08 PM KST 2024: Average Load changed:  0.77, 0.52, 0.40
    Mon Sep 23 02:37:14 PM KST 2024: Average Load changed:  0.87, 0.54, 0.41
    Mon Sep 23 02:37:18 PM KST 2024: Average Load changed:  0.88, 0.55, 0.41
    Mon Sep 23 02:37:24 PM KST 2024: Average Load changed:  0.89, 0.56, 0.42
    Mon Sep 23 02:37:28 PM KST 2024: Average Load changed:  0.98, 0.58, 0.43
    Mon Sep 23 02:37:34 PM KST 2024: Average Load changed:  0.98, 0.59, 0.43
    Mon Sep 23 02:37:38 PM KST 2024: Average Load changed:  0.98, 0.60, 0.43
    Mon Sep 23 02:37:44 PM KST 2024: Average Load changed:  0.99, 0.61, 0.44
    Mon Sep 23 02:37:54 PM KST 2024: Average Load changed:  0.99, 0.62, 0.44
    Mon Sep 23 02:37:58 PM KST 2024: Average Load changed:  0.99, 0.63, 0.45
    ```
    
    I/O 작업도 마찬가지로 CPU 부하를 일으킨다는 것을 확인할 수 있었습니다.
    
3. **CPU 사용량 확인**
    
    ```bash
    $ mpstat -P ALL 5
    ```
    <img width="782" alt="1" src="https://github.com/user-attachments/assets/471d6ac4-28ce-4d97-82c8-f5ec8eb79d21">

    `iowait` 을 통해 I/O 작업이 늘어났다는 것을 확인할 수 있었습니다.
    
    **❗특이사항**
    
    `iowait` 가 높은 CPU가 5초마다 계속 바뀐다는 것을 파악하였습니다. 또한, CPU Bound 프로세스와 다르게 여러 코어에 iowait 값이 나타났습니다.
    
    이는 프로세스 스케줄러가 각 코어 간의 작업 부하를 효율적으로 분배하려고 하는 것 때문입니다. I/O 작업이 많은 프로세스가 대기하는 동안 커널은 이러한 프로세스를 다른 코어로 옮길 수 있습니다.
    
    이로 인해 I/O 작업을 수행하는 프로세스가 한 코어에서 다른 코어로 이동하면서 `iowait` 값이 변동하게 됩니다.
    
    또한 멀티 큐 I/O 스케줄링을 사용하여 여러 CPU에서 I/O 요청을 처리할 수 있기 때문에 각 CPU 코어가 동시에 I/O 대기 상태에 들어갈 수 있습니다.
    
    이로 인해 `iowait` 가 특정 코어에서만 높은 것이 아니라 여러 코어에서 번갈아 가며 높아지는 것처럼 보일 수 있습니다.
    

## 🏁 결론

간단한 테스트를 통해 Average Load가 단순한 CPU 사용률 이상의 의미를 가진다는 것을 알 수 있었습니다.

CPU와 I/O 부하가 Average Load에 미치는 영향을 학습하고, 다양한 도구를 활용하여부하의 원인을 분석하는 방법을 익힐 수 있었습니다.
