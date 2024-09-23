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
    sleep 2
done