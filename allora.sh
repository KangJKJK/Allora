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

# Go 설치 확인 및 업그레이드
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Go 설치 확인 중...${RESET}"
if command -v go &> /dev/null; then
    current_version=$(go version | awk '{print $3}' | sed 's/go//')
    echo -e "현재 설치된 Go 버전: ${GREEN}${current_version}${RESET}"
    
    required_version="1.22.2"
    echo -e "필요한 Go 버전: ${CYAN}${required_version}${RESET}"
    
    if [ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1)" != "$required_version" ]; then
        echo -e "${YELLOW}Go 버전 업그레이드가 필요합니다.${RESET}"
        read -p "Go ${required_version}을 설치하시겠습니까? (y/n): " confirm
        if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
            echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Go ${required_version} 설치 중...${RESET}"
            wget https://go.dev/dl/go${required_version}.linux-amd64.tar.gz
            sudo rm -rf /usr/local/go
            sudo tar -C /usr/local -xzf go${required_version}.linux-amd64.tar.gz
            echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
            source ~/.bashrc
            export PATH=$PATH:/usr/local/go/bin
            go version
        else
            echo -e "${RED}Go 업그레이드를 건너뜁니다. 일부 기능이 제대로 작동하지 않을 수 있습니다.${RESET}"
        fi
    else
        echo -e "${GREEN}현재 Go 버전이 요구사항을 충족합니다.${RESET}"
    fi
else
    echo -e "${YELLOW}Go가 설치되어 있지 않습니다.${RESET}"
    read -p "Go 1.22.2를 설치하시겠습니까? (y/n): " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Go 1.22.2 설치 중...${RESET}"
        wget https://go.dev/dl/go1.22.2.linux-amd64.tar.gz
        sudo tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        source ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin
        go version
    else
        echo -e "${RED}Go 설치를 건너뜁니다. 이 스크립트의 일부 기능이 작동하지 않을 수 있습니다.${RESET}"
    fi
fi

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
on

# Allora-chain 클론 및 설치
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}2. Allora-chain 클론 및 설치 중...${RESET}"
if [ -d "allora-chain" ]; then
    echo -e "${YELLOW}allora-chain 디렉토리가 이미 존재합니다. 삭제 후 새로 설치를 진행합니다...${RESET}"
    rm -rf allora-chain
fi

echo -e "${YELLOW}allora-chain을 새로 설치합니다...${RESET}"
git clone https://github.com/allora-network/allora-chain.git
cd allora-chain
git checkout $(curl -s https://api.github.com/repos/allora-network/allora-chain/releases/latest | grep tag_name | cut -d '"' -f 4)

echo -e "${CYAN}allora-chain 빌드를 시작합니다...${RESET}"
go mod tidy
make install
echo -e "${GREEN}allora-chain 빌드가 완료되었습니다.${RESET}"

# PATH에 GOPATH/bin 추가
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc
export PATH=$PATH:$(go env GOPATH)/bin

# 로컬 네트워크 초기화 및 시작
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}3. 로컬 네트워크 초기화 및 시작 중...${RESET}"
make init

# Allorad 노드 시작
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Allorad 노드를 시작합니다...${RESET}"
nohup ~/.local/bin/allorad start > allorad.log 2>&1 &
echo -e "${GREEN}Allorad 노드가 백그라운드에서 시작되었습니다. 로그는 allorad.log 파일에서 확인할 수 있습니다.${RESET}"

# 노드가 제대로 시작되었는지 확인
sleep 10  # 노드가 시작되기를 잠시 기다립니다
if pgrep -x "allorad" > /dev/null
then
    echo -e "${GREEN}Allorad 노드가 성공적으로 실행 중입니다.${RESET}"
else
    echo -e "${RED}Allorad 노드 시작에 실패했습니다. allorad.log 파일을 확인해 주세요.${RESET}"
fi

# Docker 컨테이너 빌드 및 시작
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}4. Docker 컨테이너 빌드 및 시작 중...${RESET}"
docker compose pull
docker compose up -d
sleep 30  # 컨테이너가 완전히 시작될 때까지 대기

# 노드 상태 확인
echo -e "${BOLD}${DARK_YELLOW}5. 노드 상태 확인 중...${RESET}"
curl -so- http://localhost:26657/status | jq .
curl -so- http://localhost:26657/status | jq .result.sync_info.catching_up

# 노드 호출 및 상태 확인 안내
echo -e "${BOLD}${CYAN}노드 호출 및 상태 확인 방법:${RESET}"
echo -e "1. 노드 상태 확인: ${GREEN}curl -so- http://localhost:26657/status | jq .${RESET}"
echo -e "2. 노드 동기화 상태 확인: ${GREEN}curl -so- http://localhost:26657/status | jq .result.sync_info.catching_up${RESET}"
echo -e "   - 출력이 'false'가 될 때까지 기다리세요. 이는 노드가 완전히 동기화되었음을 의미합니다."
echo -e "${BOLD}${CYAN}노드가 실행 중일 때 위 명령어를 사용하여 제든지 상태를 확인할 수 있습니다.${RESET}"

# 자금 계좌 생성 및 faucet 사용
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}5. 자금 계좌 생성 및 faucet 사용${RESET}"
docker compose exec -T validator0 bash -c "
    allorad --home=\$APP_HOME keys add funding_account --keyring-backend=test
    FUNDING_ADDRESS=\$(allorad --home=\$APP_HOME keys show funding_account -a --keyring-backend=test)
    echo \"자금 계좌 주소: \$FUNDING_ADDRESS\"
    echo \"https://faucet.testnet.allora.network/에서 faucet을 사용하여 자금을 받으세요.\"
"

# 검증자 설정 및 스테이킹
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}6. 검증자 설정 및 스테이킹 중...${RESET}"
docker compose exec -T validator0 bash -c "
# 검증자 지갑 주소 출력
echo '검증자 지갑 주소에 스테이킹을 하세요:'
allorad --home=\$APP_HOME keys show validator0 -a --keyring-backend=test

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
    --chain-id=allora-testnet-1 \
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
# 통합 테스트 실행
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}7. 통합 테스트 실행${RESET}"
echo "통합 테스트를 실행하려면 다음 명령을 사용하세요:"
echo "bash test/local_testnet_l1.sh"
echo "INTEGRATION=TRUE go test -timeout 10m ./test/integration/ -v"

# 업그레이드 테스트 실행
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}8. 업그레이드 테스트 실행${RESET}"
echo "업그레이드 테스트를 실행하려면 다음 명령을 사용하세요:"
echo "bash test/local_testnet_upgrade_l1.sh"
echo "UPGRADE=TRUE go test -timeout 10m ./test/integration/ -v"

# 스트레스 테스트 실행
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}9. 스트레스 테스트 실행${RESET}"
echo "스트레스 테스트를 실행하려면 다음 명령을 사용하세요:"
echo "bash test/local_testnet_l1.sh"
echo "STRESS_TEST=true RPC_MODE=\"RandomBasedOnDeterministicSeed\" RPC_URLS=\"http://localhost:26657,http://localhost:26658,http://localhost:26659\" SEED=1 MAX_REPUTERS_PER_TOPIC=2 REPUTERS_PER_ITERATION=2 EPOCH_LENGTH=12 FINAL_REPORT=TRUE MAX_WORKERS_PER_TOPIC=2 WORKERS_PER_ITERATION=1 TOPICS_MAX=2 TOPICS_PER_ITERATION=1 MAX_ITERATIONS=2 go test -v -timeout 0 -test.run TestStressTestSuite ./test/stress"



echo -e "${GREEN}Faucet 주소: https://faucet.testnet.allora.network/${NC}"
echo -e "${YELLOW}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
