#!/bin/bash

BOLD="\033[1m"
UNDERLINE="\033[4m"
DARK_YELLOW="\033[0;33m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
RESET="\033[0m"

execute_with_prompt() {
    echo -e "${BOLD}Executing: $1${RESET}"
    if eval "$1"; then
        echo "Command executed successfully."
    else
        echo -e "${BOLD}${DARK_YELLOW}Error executing command: $1${RESET}"
        exit 1
    fi
}

# 1. 화면 관리 도구 'screen' 설치 및 세션 시작
echo -e "${BOLD}${DARK_YELLOW}Installing screen and starting session...${RESET}"
execute_with_prompt "sudo apt-get install -y screen"

# 'allora'라는 이름의 화면 세션을 만들고 그 안에서 나머지 스크립트 실행
execute_with_prompt "screen -S allora -dm bash -c 'bash ~/setup_allora_worker.sh'"

# 사용자에게 화면 세션이 시작되었음을 알림
echo -e "${BOLD}${DARK_YELLOW}Screen session 'allora' created and running. Use 'screen -r allora' to attach.${RESET}"

# 나머지 스크립트 (~/setup_allora_worker.sh에 저장될 내용)
cat << 'EOF' > ~/setup_allora_worker.sh
#!/bin/bash

BOLD="\033[1m"
UNDERLINE="\033[4m"
DARK_YELLOW="\033[0;33m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
RESET="\033[0m"

execute_with_prompt() {
    echo -e "${BOLD}Executing: $1${RESET}"
    if eval "$1"; then
        echo "Command executed successfully."
    else
        echo -e "${BOLD}${DARK_YELLOW}Error executing command: $1${RESET}"
        exit 1
    fi
}

echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Requirement for running allora-worker-node${RESET}"
echo
echo -e "${BOLD}${DARK_YELLOW}Operating System : Ubuntu 22.04${RESET}"
echo -e "${BOLD}${DARK_YELLOW}CPU : Min of 1/2 core.${RESET}"
echo -e "${BOLD}${DARK_YELLOW}RAM : 2 to 4 GB.${RESET}"
echo -e "${BOLD}${DARK_YELLOW}Storage : SSD or NVMe with at least 5GB of space.${RESET}"
echo

echo -e "${CYAN}Do you meet all of these requirements? (Y/N):${RESET}"
read -p "" response
echo

# 요구 사항을 충족하지 않으면 스크립트 종료
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${BOLD}${DARK_YELLOW}Error: You do not meet the required specifications. Exiting...${RESET}"
    echo
    exit 1
fi

echo -e "${BOLD}${DARK_YELLOW}Updating system dependencies...${RESET}"
execute_with_prompt "sudo apt update -y && sudo apt upgrade -y"
echo

echo -e "${BOLD}${DARK_YELLOW}Installing required packages...${RESET}"
# 필수 패키지 설치 (ca-certificates, curl, gnupg, ufw, jq)
execute_with_prompt "sudo apt install -y ca-certificates curl gnupg ufw jq"
echo

echo -e "${BOLD}${DARK_YELLOW}Installing Docker...${RESET}"
# Docker GPG 키 및 저장소 설정
execute_with_prompt 'sudo install -m 0755 -d /etc/apt/keyrings'
execute_with_prompt 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
execute_with_prompt 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'

# Docker 설치
execute_with_prompt 'sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io'
echo

# Docker 서비스 활성화 및 시작
echo -e "${BOLD}${DARK_YELLOW}Enabling and starting Docker service...${RESET}"
execute_with_prompt 'sudo systemctl enable docker'
execute_with_prompt 'sudo systemctl start docker'
echo

sleep 2
echo -e "${BOLD}${DARK_YELLOW}Checking Docker version...${RESET}"
execute_with_prompt 'docker version'
echo

echo -e "${BOLD}${DARK_YELLOW}Installing Docker Compose...${RESET}"
# Docker Compose의 최신 버전 정보를 가져와서 설치
VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
echo
execute_with_prompt 'sudo curl -L "https://github.com/docker/compose/releases/download/'"$VER"'/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose'
echo
execute_with_prompt 'sudo chmod +x /usr/local/bin/docker-compose'
echo

echo -e "${BOLD}${DARK_YELLOW}Checking Docker Compose version...${RESET}"
execute_with_prompt 'docker-compose --version'
echo

# Docker 그룹이 없으면 생성하고 현재 사용자를 그룹에 추가
if ! grep -q '^docker:' /etc/group; then
    execute_with_prompt 'sudo groupadd docker'
    echo
fi

execute_with_prompt 'sudo usermod -aG docker $USER'
echo

echo -e "${BOLD}${DARK_YELLOW}Configuring UFW firewall...${RESET}"
# UFW 방화벽 설정
execute_with_prompt 'sudo ufw enable'
execute_with_prompt 'sudo ufw allow ssh'
execute_with_prompt 'sudo ufw allow 22'
execute_with_prompt 'sudo ufw allow 4001'
execute_with_prompt 'sudo ufw allow 4000/tcp'
execute_with_prompt 'sudo ufw allow 8001'
execute_with_prompt 'sudo ufw allow 8001/tcp'
execute_with_prompt 'sudo ufw status'
echo

echo -e "${GREEN}${BOLD}Request faucet to your wallet from this link:${RESET} https://faucet.testnet-1.testnet.allora.network/"
echo

echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Installing worker node...${RESET}"
# Worker 노드 설치
execute_with_prompt 'git clone https://github.com/allora-network/basic-coin-prediction-node'
execute_with_prompt 'cd basic-coin-prediction-node'
echo
read -p "Enter WALLET_SEED_PHRASE: " WALLET_SEED_PHRASE
echo
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Generating config.json file...${RESET}"
# config.json 파일 생성
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

echo -e "${BOLD}${DARK_YELLOW}config.json file generated successfully!${RESET}"
echo
execute_with_prompt 'mkdir worker-data'
execute_with_prompt 'chmod +x init.config'
sleep 2
execute_with_prompt './init.config'

echo
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Building and starting Docker containers...${RESET}"
# Docker 컨테이너 빌드 및 시작
execute_with_prompt 'docker compose build'
execute_with_prompt 'docker-compose up -d'
echo
sleep 2
echo -e "${BOLD}${DARK_YELLOW}Checking running Docker containers...${RESET}"
execute_with_prompt 'docker ps'
echo
execute_with_prompt 'docker logs -f worker'
echo

echo -e "${YELLOW}모든작업이 완료되었습니다.컨트롤+A+D로 스크린을 종료해주세요${NC}"
# 스크립트 작성자: kangjk