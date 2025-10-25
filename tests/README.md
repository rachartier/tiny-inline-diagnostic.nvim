# Test Suite for tiny-inline-diagnostic.nvim

Comprehensive unit tests using mini.test framework.

## Running Tests

```bash
./scripts/test.sh
./scripts/test.sh file tests/test_utils.lua
./scripts/test.sh interactive
```

## Test Coverage

- **test_utils.lua**: Utils module (color conversion, text wrapping, throttling)
- **test_filter.lua**: Filter module (diagnostic filtering by position/visibility)
- **test_state.lua**: State module (enable/disable, mode handling)
- **test_presets.lua**: Presets module (preset configurations)

## Test Structure

Tests use mini.test hierarchical organization with `MiniTest.new_set()` for grouping related test cases.

## Requirements

- mini.test (auto-installed by minimal_init.lua)
- Neovim >= 0.10
