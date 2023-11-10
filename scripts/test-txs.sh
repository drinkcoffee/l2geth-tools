#!/bin/bash

set -e
set -o pipefail

# main
function main () {
	local env="$1"
	if ! echo "$env" | grep -q -e local; then
		echo "($env) is invalid arg: must be local"
		exit 1
	fi
	local regex="$2"
	local run_args=""
	if [ -n "$regex" ]; then
		run_args="-run $regex"
	fi

	priv_key="$(go run ./cmd/immutable/privkey/main.go --password "$(cat ./scripts/local/network/password)" < ./scripts/local/network/signer-0/keystore/UTC*)"
	export E2E_PRIVATE_KEY="$priv_key"
	export E2E_RPC_URL="http://localhost:8540"
	go clean -testcache
	go test -v ./tests/immutable/ ${run_args[@]}
}
main "$@"
