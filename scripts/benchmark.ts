import { ethers } from "ethers";
const path = require("path");

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