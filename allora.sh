#!/bin/bash

# 색상 설정
BOLD="\033[1m"
UNDERLINE="\033[4m"
DARK_YELLOW="\033[0;33m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}${DARK_YELLOW}시스템 의존성 업데이트 중...${RESET}"
sudo apt update -y && sudo apt upgrade -y

echo -e "${BOLD}${DARK_YELLOW}필요한 패키지 설치 중...${RESET}"
sudo apt install ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl git wget make
sudo apt install curl git jq build-essential gcc unzip wget lz4 -y

echo -e "${BOLD}${DARK_YELLOW}Docker 설치 중...${RESET}"

# Docker GPG 키 및 저장소 설정
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker 설치
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io

echo -e "${BOLD}${DARK_YELLOW}Docker 서비스 활성화 중...${RESET}"

# Docker 서비스 활성화 및 시작
sudo systemctl enable docker
sudo systemctl start docker

sleep 2
echo -e "${BOLD}${DARK_YELLOW}Docker 버전 확인 중...${RESET}"
docker version

echo -e "${BOLD}${DARK_YELLOW}Docker Compose 설치 중...${RESET}"

# Docker Compose의 최신 버전 정보를 가져와서 설치
VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
sudo curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo -e "${BOLD}${DARK_YELLOW}Docker Compose 버전 확인 중...${RESET}"
docker-compose --version

# Docker 그룹이 없으면 생성하고 현재 사용자를 그룹에 추가
if ! grep -q '^docker:' /etc/group; then
    sudo groupadd docker
    echo
fi

sudo usermod -aG docker $USER

echo -e "${BOLD}${DARK_YELLOW}UFW 방화벽 설정 중...${RESET}"


echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Worker 노드 설치 중...${RESET}"
# Worker 노드 설치
git clone https://github.com/allora-network/basic-coin-prediction-node

# cd 명령어로 디렉토리 변경 후 작업 수행
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

#!/bin/bash

# 색상 설정
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m"  # No Color

# 포트가 사용 중인지 확인하는 함수
check_port() {
    if lsof -i :$1 > /dev/null; then
        return 1  # 포트 사용 중
    else
        return 0  # 포트 사용 가능
    fi
}
-----------------------------------------------------------------------------------------------------------------
# 기본 포트 및 최대 포트 설정
starting_ports=(4000 8000)
max_port=65535

# 포트 확인 및 변경
for starting_port in "${starting_ports[@]}"; do
    desired_port=$starting_port
    while [ $desired_port -le $max_port ]; do
        if check_port $desired_port; then
            echo -e "${GREEN}사용 가능한 포트를 찾았습니다: $desired_port${NC}"
            break 2
        fi
        desired_port=$((desired_port + 1))
    done
done

# 포트가 사용 중인 경우 처리
if [ $desired_port -gt $max_port ]; then
    echo -e "${RED}사용 가능한 포트를 찾을 수 없습니다.${NC}"
    exit 1
fi

# config.json 파일에서 포트 변경
sed -i "s/\"llamaedge_port\": \".*\"/\"llamaedge_port\": \"$desired_port\"/" $gaianet_base_dir/config.json

# UFW에서 포트 개방
echo -e "${YELLOW}UFW에서 포트 $desired_port를 개방합니다...${NC}"
ufw allow $desired_port/tcp
-----------------------------------------------------------------------------------------------------------------

# 추가 디렉토리 및 권한 설정
mkdir worker-data
chmod +x init.config
sleep 2
./init.config

echo
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Docker 컨테이너 빌드 및 시작 중...${RESET}"

# Docker 컨테이너 빌드 및 시작
docker compose build
docker-compose up -d
echo
sleep 2
echo -e "${BOLD}${DARK_YELLOW}실행 중인 Docker 컨테이너 확인 중...${RESET}"
docker ps
echo
docker logs -f worker
echo

echo -e "${YELLOW}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요${RESET}"
echo -e "${BOLD}${RED}다음 링크에서 지갑에 Faucet을 요청하세요: https://faucet.testnet.allora.network/${RESET}"
echo -e "${BOLD}${UNDERLINE}${CYAN}스크립트 작성자: https://t.me/kjkresearch${RESET}"
