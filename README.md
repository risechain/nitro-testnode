# Nitro Testnode

Nitro-testnode brings up a full environment for local nitro testing (with or without Stylus support) including a dev-mode geth L1, and multiple instances with different roles.

### Requirements

* bash shell
* docker and docker-compose

All must be installed in PATH.

## Using latest nitro release (recommended)

### Without Stylus support

Check out the release branch of the repository.

> Notice: release branch may be force-pushed at any time.

```bash
git clone -b release --recurse-submodules https://github.com/OffchainLabs/nitro-testnode.git
cd nitro-testnode
```

Initialize the node

```bash
./test-node.bash --init
```
To see more options, use `--help`.

### With Stylus support

Check out the stylus branch of the repository.
> Notice: stylus branch may be force-pushed at any time.

```bash
git clone -b stylus --recurse-submodules https://github.com/OffchainLabs/nitro-testnode.git
cd nitro-testnode
```

Initialize the node

```bash
./test-node.bash --init
```
To see more options, use `--help`.

## Using current nitro code (local compilation)

Check out the nitro or stylus repository. Use the test-node submodule of nitro repository.

> Notice: testnode may not always be up-to-date with config options of current nitro node, and is not considered stable when operated in that way.

### Without Stylus support
```bash
git clone --recurse-submodules https://github.com/OffchainLabs/nitro.git
cd nitro/nitro-testnode
```

Initialize the node in dev-mode (this will build the docker images from source)
```bash
./test-node.bash --init --dev
```
To see more options, use `--help`.

### With Stylus support
```bash
git clone --recurse-submodules https://github.com/OffchainLabs/stylus.git
cd stylus/nitro-testnode
```

Initialize the node in dev-mode (this will build the docker images from source)
```bash
./test-node.bash --init --dev
```
To see more options, use `--help`.

## Further information

### Working with docker containers

**sequencer** is the main docker to be used to access the nitro testchain. It's http and websocket interfaces are exposed at localhost ports 8547 and 8548 ports, respectively.

Stopping, restarting nodes can be done with docker-compose.

### Helper scripts

Some helper scripts are provided for simple testing of basic actions.

To fund the address 0x1111222233334444555566667777888899990000 on l2, use:

```bash
./test-node.bash script send-l2 --to address_0x1111222233334444555566667777888899990000
```

For help and further scripts, see:

```bash
./test-node.bash script --help
```

## Contact

Discord - [Arbitrum](https://discord.com/invite/5KE54JwyTs)

Twitter: [Arbitrum](https://twitter.com/arbitrum)

## Additional Stuff for RISE
### Install dependencies
https://docs.celestia.org/developers/arbitrum-deploy
```bash
# General
sudo apt update && sudo apt upgrade -y
sudo apt install curl tar wget clang pkg-config libssl-dev cmake jq build-essential git make ncdu -y
# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
# Golang
ver="1.20"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
go version
# Node
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
nvm install 16.20.0
nvm use 16.20.0
node --version
npm install --global yarn
yarn --version
# Other Dependencies
cargo install --force cbindgen
rustup target add wasm32-unknown-unknown
```
### Run in localhost
```bash
./test-node.bash --init --dev --blockscout --validate --local-da --local-l1 --detach
```

### Run with Ethereum, Celestia
1. Run Celestia light node
> By default, this settings is using Mocha Testnet as DA, this can be changed by updating the `docker-compose.yml` file in `deploy/celestia-light` folder. Follow the instruction here https://docs.celestia.org/nodes/light-node.
```yaml
command: >
    celestia light start
    --p2p.network=<change this>
    --keyring.accname my_celes_key
    --core.ip <change this>
    --rpc.addr=0.0.0.0
    --rpc.port=26658
    --gateway
environment:
    - NODE_TYPE=light
    - P2P_NETWORK=<change this>
ports:
    - "26658:26658"
volumes:
    - <change this>
```
2. Get Celestia token key
```bash
# Follow the instruction here https://docs.celestia.org/developers/celestia-node-key to install cel-key cmd
cel-key list --keyring-backend test --node.type light --p2p.network mocha --keyring-dir /mnt/disks/celestia/.celestia-light-mocha-4/keys
# Expected Output:
# - address: celestia1z76rfc2ngva7punhpv8sqarlj3jjtdw58x2zr6
#   name: my_celes_key
#   pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"AuyXiTzGJY81hblpQkzmAay4HiXY4dwtIkr5J/zLKkhW"}'
#   type: local
```
3. Fund your Celestia Wallet
https://docs.celestia.org/nodes/celestia-app-wallet#fund-a-wallet

4. Config L1 and Celestia RPC
Go to `test-node.bash`, change the following config or leave it as default
```
export L1_WS="wss://eth-sepolia.g.alchemy.com/v2/AYLT5e-_3mH-g3IM47rDmoMh88i17MhU"
export L1_RPC="https://eth-sepolia.g.alchemy.com/v2/AYLT5e-_3mH-g3IM47rDmoMh88i17MhU"
export DA_RPC="http://172.31.25.45:26658"
export DA_TENDERMINT_RPC="http://rpc-mocha.pops.one:26657"
# Address: celestia1z76rfc2ngva7punhpv8sqarlj3jjtdw58x2zr6
export CELESTIA_NODE_AUTH_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJwdWJsaWMiLCJyZWFkIiwid3JpdGUiLCJhZG1pbiJdfQ.nkEgLKyWJzRbk_KBitwLArYMRLhic00LLnYFpTgxlK0
```

5. Fund your L1 Wallet
- Find your L1 Wallet Address
```shell
./test-node.bash --build --no-run
./test-node.bash script print-address
```
- Send at least 3 Sepolia ETH to this address to deploy the stack.

6. Run the devstack
```shell
./test-node.bash --init --dev --blockscout --validate --detach
# run without fund l1, l2
./test-node.bash --init --dev --blockscout --validate --no-fund-l1 --no-fund-l2 --detach
# run without validator(s)
./test-node.bash --init --dev --blockscout --detach
# run with redundant sequencers
./test-node.bash --init --dev --blockscout --detach --redundantsequencers 2
```

