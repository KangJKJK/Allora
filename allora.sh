#!/bin/bash

# 색상 설정
BOLD="\033[1m"
UNDERLINE="\033[4m"
DARK_YELLOW="\033[0;33m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

# 함수: 명령어 실행 및 결과 확인, 오류 발생 시 사용자에게 계속 진행할지 묻기
execute_with_prompt() {
    local message="$1"
    local command="$2"
    echo -e "${DARK_YELLOW}${message}${RESET}"
    echo "Executing: $command"
    
    # 명령어 실행 및 오류 내용 캡처
    output=$(bash -c "$command" 2>&1)
    exit_code=$?

    # 출력 결과를 화면에 표시
    echo "$output"

    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Error: Command failed: $command${RESET}" >&2
        echo -e "${RED}Detailed Error Message:${RESET}"
        echo "$output" | sed 's/^/  /'  # 상세 오류 메시지를 들여쓰기하여 출력
        echo

        # 사용자에게 계속 진행할지 묻기
        read -p "오류가 발생했습니다. 계속 진행하시겠습니까? (Y/N): " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${RED}스크립트를 종료합니다.${RESET}"
            exit 1
        fi
    else
        echo -e "${GREEN}Success: Command completed successfully.${RESET}"
    fi
}

echo -e "${BOLD}${DARK_YELLOW}시스템 의존성 업데이트 중...${RESET}"
execute_with_prompt "sudo apt update -y && sudo apt upgrade -y"

echo -e "${BOLD}${DARK_YELLOW}필요한 패키지 설치 중...${RESET}"

# 필수 패키지 설치 (ca-certificates, curl, gnupg, ufw, jq)
execute_with_prompt "sudo apt install -y ca-certificates curl gnupg ufw jq"

echo -e "${BOLD}${DARK_YELLOW}Docker 설치 중...${RESET}"

# Docker GPG 키 및 저장소 설정
execute_with_prompt 'sudo install -m 0755 -d /etc/apt/keyrings'
execute_with_prompt 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
execute_with_prompt 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'

# Docker 설치
execute_with_prompt 'sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io'

echo -e "${BOLD}${DARK_YELLOW}Docker 서비스 활성화 중...${RESET}"

# Docker 서비스 활성화 및 시작
execute_with_prompt 'sudo systemctl enable docker'
execute_with_prompt 'sudo systemctl start docker'

sleep 2
echo -e "${BOLD}${DARK_YELLOW}Docker 버전 확인 중...${RESET}"
execute_with_prompt 'docker version'

echo -e "${BOLD}${DARK_YELLOW}Docker Compose 설치 중...${RESET}"

# Docker Compose의 최신 버전 정보를 가져와서 설치
VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
execute_with_prompt 'sudo curl -L "https://github.com/docker/compose/releases/download/'"$VER"'/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose'
execute_with_prompt 'sudo chmod +x /usr/local/bin/docker-compose'

echo -e "${BOLD}${DARK_YELLOW}Docker Compose 버전 확인 중...${RESET}"
execute_with_prompt 'docker-compose --version'

# Docker 그룹이 없으면 생성하고 현재 사용자를 그룹에 추가
if ! grep -q '^docker:' /etc/group; then
    execute_with_prompt 'sudo groupadd docker'
    echo
fi

execute_with_prompt 'sudo usermod -aG docker $USER'

echo -e "${BOLD}${DARK_YELLOW}UFW 방화벽 설정 중...${RESET}"

# UFW 설치 및 포트 개방
execute_with_prompt "UFW 설치 중..." "sudo apt-get install -y ufw"
read -p "UFW를 설치한 후 계속하려면 Enter를 누르세요..."
execute_with_prompt "UFW 활성화 중..." "sudo ufw enable"
execute_with_prompt "필요한 포트 개방 중..." \
    "sudo ufw allow ssh && \
     sudo ufw allow 22 && \
     sudo ufw allow 4001 && \
     sudo ufw allow 4000/tcp && \
     sudo ufw allow 8001 && \
     sudo ufw allow 8001/tcp && \
     sudo ufw allow status"

sleep 2

echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Worker 노드 설치 중...${RESET}"
# Worker 노드 설치
execute_with_prompt 'git clone https://github.com/allora-network/basic-coin-prediction-node'

# `cd` 명령어로 디렉토리 변경 후 작업 수행
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}디렉토리 변경 중...${RESET}"
cd basic-coin-prediction-node || { echo "디렉토리 변경 실패"; exit 1; }

# WALLET_SEED_PHRASE 입력 받기
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}WALLET_SEED_PHRASE 입력 받기...${RESET}"
read -p "WALLET_SEED_PHRASE을 입력하세요: " WALLET_SEED_PHRASE

# config.json 파일 생성
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}config.json 파일 생성 중...${RESET}"
cat <<EOF > config.json
{
  "wallet": {
    "addressKeyName": "test",
    "addressRestoreMnemonic": "$WALLET_SEED_PHRASE",
    "alloraHomeDir": "",
    "gas": "1000000",
    "gasAdjustment": 1.0,
    "nodeRpc": "https://sentries-rpc.testnet-1.testnet.allora.network/",
    "maxRetries": 1,
    "delay": 1,
    "submitTx": true
  },
  "worker": [
    {
      "topicId": 1,
      "inferenceEntrypointName": "api-worker-reputer",
      "loopSeconds": 5,
      "parameters": {
        "InferenceEndpoint": "http://localhost:8001/inference/{Token}",
        "Token": "ETH"
      }
    },
    {
      "topicId": 1,
      "inferenceEntrypointName": "api-worker-reputer",
      "loopSeconds": 5,
      "parameters": {
        "InferenceEndpoint": "http://localhost:8001/inference/{Token}",
        "Token": "ETH"
      }
    }
  ]
}
EOF

echo -e "${BOLD}${DARK_YELLOW}config.json 파일이 성공적으로 생성되었습니다!${RESET}"
echo

# 추가 디렉토리 및 권한 설정
execute_with_prompt 'mkdir worker-data'
execute_with_prompt 'chmod +x init.config'
sleep 2
execute_with_prompt './init.config'

echo
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Docker 컨테이너 빌드 및 시작 중...${RESET}"

# Docker 컨테이너 빌드 및 시작
execute_with_prompt 'docker compose build'
execute_with_prompt 'docker-compose up -d'
echo
sleep 2
echo -e "${BOLD}${DARK_YELLOW}실행 중인 Docker 컨테이너 확인 중...${RESET}"
execute_with_prompt 'docker ps'
echo
execute_with_prompt 'docker logs -f worker'
echo

echo -e "${YELLOW}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요${RESET}"
echo -e "${BOLD}${RED}다음 링크에서 지갑에 Faucet을 요청하세요: https://faucet.testnet-1.testnet.allora.network/${RESET}"
echo -e "${BOLD}${UNDERLINE}${CYAN}스크립트 작성자: https://t.me/kjkresearch${RESET}"
