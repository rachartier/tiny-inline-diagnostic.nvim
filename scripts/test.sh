#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

if [ "$1" = "file" ] && [ -n "$2" ]; then
  nvim --headless --noplugin -u tests/minimal_init.lua \
    -c "lua MiniTest = require('mini.test'); MiniTest.setup()" \
    -c "lua MiniTest.run_file('$2')" \
    -c "qa!"
elif [ "$1" = "interactive" ]; then
  nvim -u tests/minimal_init.lua \
    -c "lua require('tests.init')"
else
  nvim --headless --noplugin -u tests/minimal_init.lua \
    -c "lua MiniTest = require('mini.test'); MiniTest.setup({ execute = { reporter = MiniTest.gen_reporter.stdout() } })" \
    -c "lua MiniTest.run()" \
    -c "qa!"
fi
