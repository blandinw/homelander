#!/bin/bash

set -ex

if [ -z "$1" ]; then
  BIN_DIR="$HOME/bin"
else
  BIN_DIR="$1"
fi

MIX_ENV=prod mix test
MIX_ENV=prod mix escript.build
./homelander --check
cp ./homelander "$BIN_DIR"
