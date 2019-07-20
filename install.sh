#!/usr/bin/env bash

set -euo pipefail

bindir="$HOME/.local/bin"

if [[ "$UID" = 0 ]]; then
    bindir=/usr/local/bin
fi

if [[ ! -d "$bindir" ]]; then
    mkdir -p "$bindir"
fi

cp bin/*.sh "$bindir/"

echo "Installed to $bindir"
