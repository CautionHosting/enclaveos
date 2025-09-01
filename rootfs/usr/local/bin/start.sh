#!/bin/sh

echo "Configuring loopback network"
busybox ip addr add 127.0.0.1/32 dev lo
busybox ip link set dev lo up

echo "Establishing socat listener"
socat VSOCK-LISTEN:3000,reuseaddr,fork TCP:localhost:3000 &

echo "Starting Caddy"
caddy run --config /etc/caddy/Caddyfile
