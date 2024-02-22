#!/usr/bin/env bash

set -e

L1_WS=ws://geth:8546
L2_WS=ws://sequencer:8548
NTHREADS=1
THREAD_FUND_AMT=100
BRIDGE_AMT=$((NTHREADS*THREAD_FUND_AMT+10))
TXS_PER_THREAD=2
SHOULD_FUND=false

if $SHOULD_FUND; then
    # 1. Bridge token to funnel account
    echo == Bridge token to funnel account
    docker-compose run --rm scripts bridge-funds --ethamount ${BRIDGE_AMT} --wait --l1url $L1_WS

    # 2. Fund threads account
    echo == Fund thread accounts
    for ((i=0; i< ${NTHREADS}; i++))
    do
        echo == Fund thread account ${i}
        docker compose run scripts send-l2 --threadId ${i} --ethamount ${THREAD_FUND_AMT} --to threaduser_l2user --l2url $L2_WS
    done
    # Make sure the fund transaction will be wait
    docker compose run scripts send-l2 --threadId 0 --ethamount 0.1 --to threaduser_l2user --l2url $L2_WS --wait --delay 5000
fi

# Get last block height
latestBlock=`docker compose run scripts count-total-txs --l2url $L2_WS | tail -n 1 | tr -d '\r\n' | jq '.latestBlock'`
echo Last Block height is ${latestBlock}

# 3. Send (stress) transactions from n thread-accounts to a random account
startTime=`date +%s`
echo == Send transactions at ${startTime}
docker compose run scripts send-l2 --threads ${NTHREADS} --times ${TXS_PER_THREAD} --ethamount 0.001 --from threaduser_l2user --to user_l2user --l2url $L2_WS
endTime=`date +%s`
echo == Finish sending transactions at ${endTime}

# 4. Get total confirmed transactions after amount of time.
res=`docker compose run scripts count-total-txs --fromblock=${latestBlock} --l2url $L2_WS | tail -n 1 | tr -d '\r\n'`
totalTxs=`echo $res | jq '.totalTxs'`
endBlock=`echo $res | jq '.latestBlock'`

# 5. Return throughput
totalRuntime=$((endTime-startTime))
echo
echo == Result
echo "   - Total run time: ${totalRuntime}"
echo "   - Total confirmed txs: ${totalTxs}, from block (exclusive) ${latestBlock} to block ${endBlock}"
echo "   - TPS: $((totalTxs/totalRuntime))"