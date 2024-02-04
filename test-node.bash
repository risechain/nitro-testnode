#!/usr/bin/env bash

# docker compose run --rm -v ${PWD}/out/:/out --entrypoint sh scripts -c 'tar -zcvf /out/config.tar.gz /config'

set -e

NITRO_NODE_VERSION=offchainlabs/nitro-node:v2.2.2-8f33fea-dev
BLOCKSCOUT_VERSION=offchainlabs/blockscout:v1.0.0-c8db5b1
# NODE_PATH="/home/celestia/bridge/"
NODE_PATH="/home/celestia/.celestia-light-mocha-4/"
# [Update this]
export L1_WS="wss://distinguished-greatest-mountain.ethereum-sepolia.quiknode.pro/58b6176715dcedd8df2d8064bdd88cee5f8ad16f"
export DA_RPC="http://172.31.25.45:26658"
export DA_TENDERMINT_RPC="http://rpc-mocha.pops.one:26657"
# Address: celestia1z76rfc2ngva7punhpv8sqarlj3jjtdw58x2zr6
export CELESTIA_NODE_AUTH_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJwdWJsaWMiLCJyZWFkIiwid3JpdGUiLCJhZG1pbiJdfQ.nkEgLKyWJzRbk_KBitwLArYMRLhic00LLnYFpTgxlK0
DEFAULT_FUND_AMOUNT=0.2

mydir=`dirname $0`
cd "$mydir"

if [[ $# -gt 0 ]] && [[ $1 == "script" ]]; then
    shift
    docker compose run scripts "$@"
    exit $?
fi

num_volumes=`docker volume ls --filter label=com.docker.compose.project=nitro-testnode -q | wc -l`

if [[ $num_volumes -eq 0 ]]; then
    force_init=true
else
    force_init=false
fi

run=true
force_build=false
validate=false
detach=false
blockscout=false
tokenbridge=true
local_da=false
local_l1=false
l3node=false
consensusclient=false
redundantsequencers=0
dev_build_nitro=false
dev_build_blockscout=false
l3_custom_fee_token=false
l3_token_bridge=false
fund_l1=false
fund_l1_amount=$DEFAULT_FUND_AMOUNT
batchposters=1
devprivkey=2fc338a5ddd5f1fef594cf904225f5cfc77602339a4dd16864b53144a2de38fc
l1chainid=11155111
simple=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --init)
            if ! $force_init; then
                echo == Warning! this will remove all previous data
                read -p "are you sure? [y/n]" -n 1 response
                if [[ $response == "y" ]] || [[ $response == "Y" ]]; then
                    force_init=true
                    echo
                else
                    exit 0
                fi
            fi
            shift
            ;;
        --dev)
            simple=false
            shift
            if [[ $# -eq 0 || $1 == -* ]]; then
                # If no argument after --dev, set both flags to true
                dev_build_nitro=true
                dev_build_blockscout=true
            else
                while [[ $# -gt 0 && $1 != -* ]]; do
                    if [[ $1 == "nitro" ]]; then
                        dev_build_nitro=true
                    elif [[ $1 == "blockscout" ]]; then
                        dev_build_blockscout=true
                    fi
                    shift
                done
            fi
            ;;
        --build)
            force_build=true
            shift
            ;;
        --validate)
            simple=false
            validate=true
            shift
            ;;
        --blockscout)
            blockscout=true
            shift
            ;;
        --tokenbridge)
            tokenbridge=true
            shift
            ;;
        --no-tokenbridge)
            tokenbridge=false
            shift
            ;;
        --local-da)
            NODE_PATH="/home/celestia/bridge/"
            export DA_TENDERMINT_RPC="http://da:26658"
            export DA_RPC="http://da:26658"
            local_da=true
            shift
            ;;
        --local-l1)
            l1chainid=1337
            export L1_WS=ws://geth:8546
            local_l1=true
            shift
            ;;
        --no-run)
            run=false
            shift
            ;;
        --fund)
            fund_l1=true
            shift
            if [[ $# -gt 0 && $1 != -* ]]; then
                # If there is argument after --fund
                while [[ $# -gt 0 && $1 != -* ]]; do
                    fund_l1_amount=$1
                    shift
                done
            fi
            ;;
        --detach)
            detach=true
            shift
            ;;
        --batchposters)
            simple=false
            batchposters=$2
            if ! [[ $batchposters =~ [0-3] ]] ; then
                echo "batchposters must be between 0 and 3 value:$batchposters."
                exit 1
            fi
            shift
            shift
            ;;
        --pos)
            consensusclient=true
            l1chainid=32382
            shift
            ;;
        --l3node)
            l3node=true
            shift
            ;;
        --l3-fee-token)
            if ! $l3node; then
                echo "Error: --l3-fee-token requires --l3node to be provided."
                exit 1
            fi
            l3_custom_fee_token=true
            shift
            ;;
        --l3-token-bridge)
            if ! $l3node; then
                echo "Error: --l3-token-bridge requires --l3node to be provided."
                exit 1
            fi
            l3_token_bridge=true
            shift
            ;;
        --redundantsequencers)
            simple=false
            redundantsequencers=$2
            if ! [[ $redundantsequencers =~ [0-3] ]] ; then
                echo "redundantsequencers must be between 0 and 3 value:$redundantsequencers."
                exit 1
            fi
            shift
            shift
            ;;
        --simple)
            simple=true
            shift
            ;;
        --no-simple)
            simple=false
            shift
            ;;
        *)
            echo Usage: $0 \[OPTIONS..]
            echo        $0 script [SCRIPT-ARGS]
            echo
            echo OPTIONS:
            echo --build           rebuild docker images
            echo --dev             build nitro and blockscout dockers from source instead of pulling them. Disables simple mode
            echo --init            remove all data, rebuild, deploy new rollup
            echo --pos             l1 is a proof-of-stake chain \(using prysm for consensus\)
            echo --validate        heavy computation, validating all blocks in WASM
            echo --l3-fee-token    L3 chain is set up to use custom fee token. Only valid if also '--l3node' is provided
            echo --l3-token-bridge Deploy L2-L3 token bridge. Only valid if also '--l3node' is provided
            echo --batchposters    batch posters [0-3]
            echo --redundantsequencers redundant sequencers [0-3]
            echo --detach          detach from nodes after running them
            echo --blockscout      build or launch blockscout
            echo --simple          run a simple configuration. one node as sequencer/batch-poster/staker \(default unless using --dev\)
            echo --no-tokenbridge  don\'t build or launch tokenbridge
            echo --no-run          does not launch nodes \(useful with build or init\)
            echo --no-simple       run a full configuration with separate sequencer/batch-poster/validator/relayer
            echo
            echo script runs inside a separate docker. For SCRIPT-ARGS, run $0 script --help
            exit 0
    esac
done

if $force_init; then
  force_build=true
fi

if $dev_build_nitro; then
  if [[ "$(docker images -q nitro-node-dev:latest 2> /dev/null)" == "" ]]; then
    force_build=true
  fi
fi

if $dev_build_blockscout; then
  if [[ "$(docker images -q blockscout:latest 2> /dev/null)" == "" ]]; then
    force_build=true
  fi
fi

NODES="sequencer"
INITIAL_SEQ_NODES="sequencer"

if ! $simple; then
    NODES="$NODES redis"
fi
if [ $redundantsequencers -gt 0 ]; then
    NODES="$NODES sequencer_b"
    INITIAL_SEQ_NODES="$INITIAL_SEQ_NODES sequencer_b"
fi
if [ $redundantsequencers -gt 1 ]; then
    NODES="$NODES sequencer_c"
fi
if [ $redundantsequencers -gt 2 ]; then
    NODES="$NODES sequencer_d"
fi

if [ $batchposters -gt 0 ] && ! $simple; then
    NODES="$NODES poster"
fi
if [ $batchposters -gt 1 ]; then
    NODES="$NODES poster_b"
fi
if [ $batchposters -gt 2 ]; then
    NODES="$NODES poster_c"
fi


if $validate; then
    NODES="$NODES validator"
elif ! $simple; then
    NODES="$NODES staker-unsafe"
fi
if $l3node; then
    NODES="$NODES l3node"
fi
if $blockscout; then
    NODES="$NODES blockscout"
fi
if $force_build; then
  echo == Building..
  if $dev_build_nitro; then
    if ! [ -n "${NITRO_SRC+set}" ]; then
        NITRO_SRC=`dirname $PWD`
    fi
    if ! grep ^FROM "${NITRO_SRC}/Dockerfile" | grep nitro-node 2>&1 > /dev/null; then
        echo nitro source not found in "$NITRO_SRC"
        echo execute from a sub-directory of nitro or use NITRO_SRC environment variable
        exit 1
    fi
    docker build "$NITRO_SRC" -t nitro-node-dev --target nitro-node-dev
  fi
  if $dev_build_blockscout; then
    if $blockscout; then
      docker build blockscout -t blockscout -f blockscout/docker/Dockerfile
    fi
  fi
  LOCAL_BUILD_NODES=scripts
  if $tokenbridge || $l3_token_bridge; then
    LOCAL_BUILD_NODES="$LOCAL_BUILD_NODES tokenbridge"
  fi
  docker compose build --no-rm $LOCAL_BUILD_NODES
fi

if $dev_build_nitro; then
  docker tag nitro-node-dev:latest nitro-node-dev-testnode
else
  docker pull $NITRO_NODE_VERSION
  docker tag $NITRO_NODE_VERSION nitro-node-dev-testnode
fi

if $dev_build_blockscout; then
  if $blockscout; then
    docker tag blockscout:latest blockscout-testnode
  fi
else
  if $blockscout; then
    docker pull $BLOCKSCOUT_VERSION
    docker tag $BLOCKSCOUT_VERSION blockscout-testnode
  fi
fi

if $force_build; then
    docker compose build --no-rm $NODES scripts
fi

# Helper method that waits for a given URL to be up. Can't use
# cURL's built-in retry logic because connection reset errors
# are ignored unless you're using a very recent version of cURL
function wait_up {
  echo -n "Waiting for $1 to come up..."
  i=0
  until curl -s -f -o /dev/null "$1"
  do
    echo -n .
    sleep 0.25

    ((i=i+1))
    if [ "$i" -eq 300 ]; then
      echo " Timeout!" >&2
      exit 1
    fi
  done
  echo "Done!"
}

if $force_init; then
    echo == Removing old data..
    docker compose down
    leftoverContainers=`docker container ls -a --filter label=com.docker.compose.project=nitro-testnode -q | xargs echo`
    if [ `echo $leftoverContainers | wc -w` -gt 0 ]; then
        docker rm $leftoverContainers
    fi
    docker volume prune -f --filter label=com.docker.compose.project=nitro-testnode
    leftoverVolumes=`docker volume ls --filter label=com.docker.compose.project=nitro-testnode -q | xargs echo`
    if [ `echo $leftoverVolumes | wc -w` -gt 0 ]; then
        docker volume rm $leftoverVolumes
    fi

    # We use another vm to run celestia testnet node, so just comment these lines bellow
    if $local_da; then
        echo == Bringing up Celestia Devnet
        docker-compose up -d da
        wait_up http://localhost:26659/header/1
        export CELESTIA_NODE_AUTH_TOKEN="$(docker-compose exec da celestia bridge auth admin --node.store ${NODE_PATH})"
    fi

    if $local_l1; then
        echo == Generating l1 keys
        docker compose run scripts write-accounts
        docker compose run --entrypoint sh geth -c "echo passphrase > /datadir/passphrase"
        docker compose run --entrypoint sh geth -c "chown -R 1000:1000 /keystore"
        docker compose run --entrypoint sh geth -c "chown -R 1000:1000 /config"

        if $consensusclient; then
            echo == Writing configs
            docker compose run scripts write-geth-genesis-config

            echo == Writing configs
            docker compose run scripts write-prysm-config

            echo == Initializing go-ethereum genesis configuration
            docker compose run geth init --datadir /datadir/ /config/geth_genesis.json

            echo == Starting geth
            docker compose up --wait geth

            echo == Creating prysm genesis
            docker compose up create_beacon_chain_genesis

            echo == Running prysm
            docker compose up --wait prysm_beacon_chain
            docker compose up --wait prysm_validator
        else
            docker compose up --wait geth
        fi
    fi

    if $fund_l1; then
        echo == Funding validator and sequencer with $fund_l1_amount eth.
        docker-compose run --rm scripts send-l1 --ethamount $fund_l1_amount --to validator --wait --l1url $L1_WS
        docker-compose run --rm scripts send-l1 --ethamount $fund_l1_amount --to sequencer --wait --l1url $L1_WS
        docker-compose run --rm scripts send-l1 --ethamount $fund_l1_amount --to "key_0x$devprivkey" --wait --l1url $L1_WS
    else
        echo == Skip funding validator and sequencer
    fi

    if $local_l1; then
        echo == create l1 traffic
        docker-compose run --rm scripts send-l1 --ethamount 1000 --to user_l1user --wait --l1url $L1_WS
        docker-compose run --rm scripts send-l1 --ethamount 0.0001 --from user_l1user --to user_l1user_b --wait --delay 500 --times 500 --l1url $L1_WS > /dev/null &
    fi

    echo == Writing l2 chain config
    docker compose run scripts write-l2-chain-config

    echo == Deploying L2
    sequenceraddress=`docker-compose run --rm scripts print-address --account sequencer | tail -n 1 | tr -d '\r\n'`

    docker compose run --entrypoint /usr/local/bin/deploy sequencer --l1conn ws://geth:8546 --l1keystore /home/user/l1keystore --sequencerAddress $sequenceraddress --ownerAddress $sequenceraddress --l1DeployAccount $sequenceraddress --l1deployment /config/deployment.json --authorizevalidators 10 --wasmrootpath /home/user/target/machines --l1chainid=$l1chainid --l2chainconfig /config/l2_chain_config.json --l2chainname arb-dev-test --l2chaininfo /config/deployed_chain_info.json
    docker compose run --entrypoint sh sequencer -c "jq [.[]] /config/deployed_chain_info.json > /config/l2_chain_info.json"

    if $simple; then
        echo == Writing configs
        docker compose run scripts write-config --simple --authToken $CELESTIA_NODE_AUTH_TOKEN
    else
        echo == Writing configs
        docker compose run scripts write-config --authToken $CELESTIA_NODE_AUTH_TOKEN

        echo == Initializing redis
        docker compose up --wait redis
        docker compose run scripts redis-init --redundancy $redundantsequencers
    fi

    echo == Funding l2 funnel and dev key
    docker-compose up --wait $INITIAL_SEQ_NODES
    docker-compose run --rm scripts bridge-funds --ethamount 1 --wait --l1url $L1_WS
    docker-compose run --rm scripts bridge-funds --ethamount 3 --wait --from "key_0x$devprivkey" --l1url $L1_WS

    if $tokenbridge; then
        echo == Deploying L1-L2 token bridge
        rollupAddress=`docker compose run --entrypoint sh poster -c "jq -r '.[0].rollup.rollup' /config/deployed_chain_info.json | tail -n 1 | tr -d '\r\n'"`
        docker compose run -e ROLLUP_OWNER=$sequenceraddress -e ROLLUP_ADDRESS=$rollupAddress -e PARENT_KEY=$devprivkey -e PARENT_RPC=http://geth:8545 -e CHILD_KEY=$devprivkey -e CHILD_RPC=http://sequencer:8547 tokenbridge deploy:local:token-bridge
        docker compose run --entrypoint sh tokenbridge -c "cat network.json"
        echo
    fi

    if $l3node; then
        echo == Funding l3 users
        docker compose run scripts send-l2 --ethamount 1000 --to l3owner --wait
        docker compose run scripts send-l2 --ethamount 1000 --to l3sequencer --wait

        echo == Funding l2 deployers
        docker compose run scripts send-l2 --ethamount 100 --to user_token_bridge_deployer --wait
        docker compose run scripts send-l2 --ethamount 100 --to user_fee_token_deployer --wait

        echo == create l2 traffic
        docker compose run scripts send-l2 --ethamount 100 --to user_traffic_generator --wait
        docker compose run scripts send-l2 --ethamount 0.0001 --from user_traffic_generator --to user_fee_token_deployer --wait --delay 500 --times 1000000 > /dev/null &

        echo == Writing l3 chain config
        docker compose run scripts write-l3-chain-config

        if $l3_custom_fee_token; then
            echo == Deploying custom fee token
            nativeTokenAddress=`docker compose run scripts create-erc20 --deployer user_fee_token_deployer --mintTo user_token_bridge_deployer | tail -n 1 | awk '{ print $NF }'`
            EXTRA_L3_DEPLOY_FLAG="--nativeTokenAddress $nativeTokenAddress"
        fi

        echo == Deploying L3
        l3owneraddress=`docker compose run scripts print-address --account l3owner | tail -n 1 | tr -d '\r\n'`
        l3sequenceraddress=`docker compose run scripts print-address --account l3sequencer | tail -n 1 | tr -d '\r\n'`
        docker compose run --entrypoint /usr/local/bin/deploy sequencer --l1conn ws://sequencer:8548 --l1keystore /home/user/l1keystore --sequencerAddress $l3sequenceraddress --ownerAddress $l3owneraddress --l1DeployAccount $l3owneraddress --l1deployment /config/l3deployment.json --authorizevalidators 10 --wasmrootpath /home/user/target/machines --l1chainid=412346 --l2chainconfig /config/l3_chain_config.json --l2chainname orbit-dev-test --l2chaininfo /config/deployed_l3_chain_info.json --maxDataSize 104857 $EXTRA_L3_DEPLOY_FLAG
        docker compose run --entrypoint sh sequencer -c "jq [.[]] /config/deployed_l3_chain_info.json > /config/l3_chain_info.json"

        echo == Funding l3 funnel and dev key
        docker compose up --wait l3node sequencer

        if $l3_token_bridge; then
            echo == Deploying L2-L3 token bridge
            deployer_key=`printf "%s" "user_token_bridge_deployer" | openssl dgst -sha256 | sed 's/^.*= //'`
            rollupAddress=`docker compose run --entrypoint sh poster -c "jq -r '.[0].rollup.rollup' /config/deployed_l3_chain_info.json | tail -n 1 | tr -d '\r\n'"`
            docker compose run -e ROLLUP_OWNER=$l3owneraddress -e ROLLUP_ADDRESS=$rollupAddress -e PARENT_RPC=http://sequencer:8547 -e PARENT_KEY=$deployer_key  -e CHILD_RPC=http://l3node:3347 -e CHILD_KEY=$deployer_key tokenbridge deploy:local:token-bridge
            docker compose run --entrypoint sh tokenbridge -c "cat network.json"
            echo
        fi

        echo == Fund L3 accounts
        if $l3_custom_fee_token; then
            docker compose run scripts bridge-native-token-to-l3 --amount 50000 --from user_token_bridge_deployer --wait
            docker compose run scripts send-l3 --ethamount 500 --from user_token_bridge_deployer --wait
            docker compose run scripts send-l3 --ethamount 500 --from user_token_bridge_deployer --to "key_0x$devprivkey" --wait
        else
            docker compose run scripts bridge-to-l3 --ethamount 50000 --wait
            docker compose run scripts bridge-to-l3 --ethamount 500 --wait --from "key_0x$devprivkey"
        fi

    fi
fi

if $run; then
    UP_FLAG=""
    if $detach; then
        UP_FLAG="--wait"
    fi

    echo == Launching Sequencer
    echo if things go wrong - use --init to create a new chain
    echo

    docker compose up $UP_FLAG $NODES
fi
