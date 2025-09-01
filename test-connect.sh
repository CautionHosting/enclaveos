#!/usr/bin/env bash

SOCAT_PID=

cleanup_socat() {
	if test ! -z "$SOCAT_PID"; then
		kill "$SOCAT_PID"
	fi
}

ENCLAVE_CID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveCID")
socat TCP4-LISTEN:3000,reuseaddr,fork VSOCK-CONNECT:$ENCLAVE_CID:3000 &
SOCAT_PID="$!"

curl -k https://localhost:3000; echo

trap cleanup_socat EXIT
