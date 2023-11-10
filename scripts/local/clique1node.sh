#!/bin/bash
EXE_DIR=../l2geth/build/bin
BOOTNODE_BINARY=$EXE_DIR/bootnode
GETH_BINARY=$EXE_DIR/geth
EXTRADATAGEN_BINARY=$EXE_DIR/extradatagen
ETHKEY_BINARY=$EXE_DIR/ethkey

NETWORK_DIR=./scripts/local/network
GENESIS_PATH=$NETWORK_DIR/genesis.json
CHAIN_ID="1930"
BOOT_PORT="30309"

# Reset
rm -rf "$NETWORK_DIR"
mkdir -p $NETWORK_DIR
for x in geth bootnode; do
	pgrep "$x" | xargs kill -9
done

set -ex
set -o pipefail


echo "Setting up bootnode"
echo "==================="
$BOOTNODE_BINARY -genkey $NETWORK_DIR/boot.key
$BOOTNODE_BINARY -nodekey $NETWORK_DIR/boot.key \
    -addr ":$BOOT_PORT" > $NETWORK_DIR/bootnode.out 2>&1 &
printf 'Waiting for bootnode to be available...'
until grep enode < "$NETWORK_DIR/bootnode.out"; do
    sleep 1
    printf '.' 
done
echo

echo "Creating signers"
echo "================"
# Generate pw for all
pw_file="$NETWORK_DIR/password"
echo "g1mmU7a31e" > "$pw_file"
# Generate keys
addresses=()
for i in {0..0}; do
  data_dir="$NETWORK_DIR/signer-$i"

  # Generate key
  $GETH_BINARY account new --datadir "$data_dir" --password "$pw_file"  > /dev/null

  # Extract public address
  address=$(ls -la $data_dir/keystore | grep "UTC--" | cut -d '-' -f 17 | tr -d '\n')
  addresses+=("$address")
done

echo "Generating genesis.json"
echo "======================="

cat >$GENESIS_PATH << EOF
{
  "config": {
    "chainId": $CHAIN_ID,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "muirGlacierBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "arrowGlacierBlock": 0,
    "grayGlacierBlock": 0,
    "clique": {
      "period": 5,
      "epoch": 30000
    }
  },
  "difficulty": "1",
  "gasLimit": "800000000",
  "extradata": "0x0000000000000000000000000000000000000000000000000000000000000000$(echo "${addresses[@]}" | tr -d ' ')0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "alloc": {
    "B23650A2b25aB51590e3b4e66bFc4AE426Eb1cA5": { "balance": "30000000000000000000" },
    "1064c5ddD8635bA3D8FEe5cd8DEf8d502721EcEa": { "balance": "40000000000000000000" },
    "${addresses[0]}": { "balance": "10000000000000000000000" }
  }
}
EOF

echo "Initialising geth nodes"
echo "======================="

for i in {0..0}; do
     data_dir="$NETWORK_DIR/signer-$i"
     $GETH_BINARY init --datadir $data_dir $GENESIS_PATH
done

echo "Starting geth nodes"
echo "==================="

for i in {0..0}
do
    data_dir="$NETWORK_DIR/signer-$i"

    address=$(ls -la $data_dir/keystore | grep "UTC--" | cut -d '-' -f 17)
    $GETH_BINARY --datadir "$data_dir" \
        --networkid "$CHAIN_ID"  \
        --authrpc.port 855$i \
        --http \
        --http.port "854$i" \
        --http.api eth,net,web3,admin,l2trace \
        --ws.port 853$i \
        --metrics.port 606$i \
        --verbosity 3 \
        --port 3030$i \
        --bootnodes "enode://$($BOOTNODE_BINARY -nodekey ./scripts/local/network/boot.key -writeaddress)@127.0.0.1:$BOOT_PORT" \
        --unlock 0x$address \
        --allow-insecure-unlock \
        --password "$pw_file" \
        --miner.etherbase "0x$address" \
        --mine > "$NETWORK_DIR/geth-00$i.out" 2>&1 &

    printf 'Waiting for node %s to be available...' $i
    until [ -S "$data_dir/geth.ipc" ]; do
        sleep 1
        printf '.' 
    done
    echo
done

tail -f "$NETWORK_DIR/geth-00"*
