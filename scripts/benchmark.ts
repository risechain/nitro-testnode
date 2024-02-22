import { ethers } from "ethers";
import { sendTransaction } from "./ethcommands";
import { runThread } from "./stress";

export const fundL2ThreadAccounts = {
  command: "fund-l2thread-accounts",
  describe: "fund multiple l2 thread accounts",
  builder: {
    from: {
      string: true,
      describe: "account (see general help)",
      default: "funnel",
    },
    to: {
      string: true,
      describe: "address (see general help)",
      default: "funnel",
    },
    nThreads: {
      number: true,
      describe: "n threads",
      default: 1,
    },
    ethamount: {
      string: true,
      describe: "amount to transfer (in eth)",
      default: "10",
    },
    wait: {
      boolean: true,
      describe: "wait for transaction to complete",
      default: false,
    },
  },
  handler: async (argv: any) => {
    if (!argv.nThreads) {
      throw new Error("Invalid `nThreads` parameter")
    }
    const nTempAccounts = 50;
    const eachAmount = parseInt(argv.ethamount)

    argv.provider = new ethers.providers.WebSocketProvider(argv.l2url);

    if (argv.nThreads <= nTempAccounts) {
      console.log("Fund thread accounts sequentially ...");
      for (let i=0;i<argv.nThreads;i++) {
        await sendTransaction({
          ...argv,
          wait: true,
          to: `threaduser_${argv.to}`,
        }, i);
      }
      return;
    }

    const maxTimes = Math.ceil(argv.nThreads/nTempAccounts);
    const maxGasFeeEachAccount = 10;

    console.log("Fund to temp funding accounts ...");
    for(let i=0;i<nTempAccounts;i++) {
      await sendTransaction({
        ...argv,
        ethamount: `${maxTimes*eachAmount + maxGasFeeEachAccount}`,
        wait: true,
        to: "threaduser_l2temp",
      }, i);
    }

    console.log("Fund thread accounts ...");
    for(let i=0;i<argv.nThreads;) {
      let promiseArray: Array<Promise<void>>
      promiseArray = []
      for (let srcIdx = 0; srcIdx < nTempAccounts; srcIdx++) {
        if (i >= argv.nThreads) {
          break
        }
        const threadPromise = runThread({
          ...argv,
          from: "threaduser_l2temp",
          to: `user_${argv.to}_thread_${i++}`,
          ethamount: `${eachAmount}`,
        }, srcIdx, sendTransaction)
        promiseArray.push(threadPromise)
      }
      console.log(`.. end with thread index ${i}`)
      if (promiseArray.length > 0) {
        await Promise.all(promiseArray)
          .catch(error => {
              console.error(error)
              process.exit(1)
          })
      }
    }

    if (argv.wait) {
      await sendTransaction({
        ...argv,
        from: "threaduser_l2temp",
        to: `user_${argv.to}_thread_0`,
        ethamount: "0.01",
        wait: true,
      }, 0)
    }

    argv.provider.destroy();
  }
}

export const countTotalTxsCommand = {
  command: "count-total-txs",
  describe: "count total txs",
  builder: {
    fromblock: { string: true, describe: "from block to count" },
  },
  handler: async (argv: any) => {
    const rpcProvider = new ethers.providers.WebSocketProvider(argv.l2url)

    const response = await rpcProvider.send("eth_getBlockByNumber", ["latest", false])
    console.log({response, fromblock: argv.fromblock, url: argv.url})
    const latestBlock = parseInt(response.number, 16)
    if (!argv.fromblock) {
      console.log(JSON.stringify({ latestBlock }))
      return
    }

    let curr = latestBlock;
    let count = 0;
    while (curr > argv.fromblock) {
      const response = await rpcProvider.send("eth_getBlockByNumber", ['0x' + curr.toString(16), false]).catch((e) => {
        console.warn(`Get Block ${curr} got err ${e}`);
        return null;
      })
      
      curr--;
      if(!response?.transactions) {
        continue;
      }
      count += response.transactions.length;
    }

    console.log(JSON.stringify({ latestBlock, totalTxs: count }))
  }
}