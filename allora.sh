#!/bin/bash

# 색상 설정
BOLD="\033[1m"
UNDERLINE="\033[4m"
DARK_YELLOW="\033[0;33m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

# 시스템 업데이트 및 필수 패키지 설치
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}0. 시스템 업데이트 및 필수 패키지 설치 중...${RESET}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git jq make gcc build-essential

# Go 설치
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Go 설치 중...${RESET}"
wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
export PATH=$PATH:/usr/local/go/bin

# 도커 설치 확인
echo -e "${BOLD}${CYAN}Docker 설치 확인 중...${NC}"
if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}Docker가 이미 설치되어 있습니다.${NC}"
else
    echo -e "${RED}Docker가 설치되어 있지 않습니다. Docker를 설치하는 중입니다...${NC}"
    sudo apt update && sudo apt install -y curl net-tools
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    echo -e "${GREEN}Docker가 성공적으로 설치되었습니다.${NC}"
fi

# Docker Compose 설치
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Docker Compose 설치 중...${RESET}"
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Allorad 설치
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}1. Allorad 설치 중...${RESET}"
curl -sSL https://raw.githubusercontent.com/allora-network/allora-chain/main/install.sh | bash -s -- v0.0.8

# PATH에 ~/.local/bin 추가
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc
export PATH=$PATH:~/.local/bin

# Allorad 버전 확인
echo -e "${BOLD}${DARK_YELLOW}Allorad 버전 확인 중...${RESET}"
allorad version

# Allora-chain 클론 및 설치
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}2. Allora-chain 클론 및 설치 중...${RESET}"
if [ -d "allora-chain" ]; then
    cd allora-chain
    git pull
else
    git clone -b $(curl -s https://api.github.com/repos/allora-network/allora-chain/releases/latest | grep tag_name | cut -d '"' -f 4) https://github.com/allora-network/allora-chain.git
    cd allora-chain
fi
make install

# PATH에 GOPATH/bin 추가
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc
export PATH=$PATH:$(go env GOPATH)/bin

# 로컬 네트워크 초기화 및 시작
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}3. 로컬 네트워크 초기화 및 시작 중...${RESET}"
make init
allorad start

# Docker 컨테이너 빌드 및 시작
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}4. Docker 컨테이너 빌드 및 시작 중...${RESET}"
docker compose pull
docker compose up -d
sleep 10  # 컨테이너가 완전히 시작될 때까지 대기

# 노드 상태 확인
echo -e "${BOLD}${DARK_YELLOW}5. 노드 상태 확인 중...${RESET}"
curl -so- http://localhost:26657/status | jq .
curl -so- http://localhost:26657/status | jq .result.sync_info.catching_up

# 노드 호출 및 상태 확인 안내
echo -e "${BOLD}${CYAN}노드 호출 및 상태 확인 방법:${RESET}"
echo -e "1. 노드 상태 확인: ${GREEN}curl -so- http://localhost:26657/status | jq .${RESET}"
echo -e "2. 노드 동기화 상태 확인: ${GREEN}curl -so- http://localhost:26657/status | jq .result.sync_info.catching_up${RESET}"
echo -e "   - 출력이 'false'가 될 때까지 기다리세요. 이는 노드가 완전히 동기화되었음을 의미합니다."
echo -e "${BOLD}${CYAN}노드가 실행 중일 때 위 명령어를 사용하여 언제든지 상태를 확인할 수 있습니다.${RESET}"

# 검증자 설정 및 스테이킹
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}6. 검증자 설정 및 스테이킹 중...${RESET}"
docker compose exec -T validator0 bash -c "
# 스테이크 정보 파일 생성
cat > stake-validator.json << EOF
{
    \"pubkey\": \$(allorad --home=\$APP_HOME comet show-validator),
    \"amount\": \"1000000uallo\",
    \"moniker\": \"validator0\",
    \"commission-rate\": \"0.1\",
    \"commission-max-rate\": \"0.2\",
    \"commission-max-change-rate\": \"0.01\",
    \"min-self-delegation\": \"1\"
}
EOF

# 검증자 스테이킹
echo '검증자 스테이킹 중...'
allorad tx staking create-validator ./stake-validator.json \
    --chain-id=testnet \
    --home=\"\$APP_HOME\" \
    --keyring-backend=test \
    --from=validator0

# 검증자 설정 확인
echo '검증자 설정 확인 중...'
VAL_PUBKEY=\$(allorad --home=\$APP_HOME comet show-validator | jq -r .key)
allorad --home=\$APP_HOME q staking validators -o=json | \
    jq '.validators[] | select(.consensus_pubkey.value==\"'\$VAL_PUBKEY'\")'

# 검증자 투표력 확인
echo '검증자 투표력 확인 중...'
allorad --home=\$APP_HOME status | jq -r '.validator_info.voting_power'
"

echo -e "${GREEN}Faucet 주소: https://faucet.testnet.allora.network/${NC}"
echo -e "${YELLOW}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
