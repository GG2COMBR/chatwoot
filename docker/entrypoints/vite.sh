#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

pnpm store prune
pnpm install --force

# Install missing gems for local dev. The base image is compiled for
# production, so the vite_ruby gem (required by bin/vite) may be absent
# until bundle install runs here, mirroring the rails entrypoint.
bundle install

BUNDLE="bundle check"

until $BUNDLE
do
  sleep 2;
done

echo "Ready to run Vite development server."

exec "$@"
