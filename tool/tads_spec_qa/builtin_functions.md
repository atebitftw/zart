# TADS Spec Discrepancy Report: Unimplemented Built-in Functions

## Summary

This document tracks all tads-gen and t3vm built-in functions that exist in the
TADS 3 specification/reference implementation but are not yet implemented in
our Dart interpreter.

## tads-gen Function Set (vmbiftad.h)

| Index | Function | Status | Priority |
|-------|----------|--------|----------|
| 0 | datatype | ✅ Implemented | |
| 1 | getarg | ✅ Implemented | |
| 2 | firstobj | ✅ Implemented | |
| 3 | nextobj | ✅ Implemented | |
| 4 | randomize | ❌ Not implemented | Low |
| 5 | rand | ❌ Not implemented | Medium |
| 6 | toString | ❌ Not implemented | High |
| 7 | toInteger | ❌ Not implemented | High |
| 8 | gettime | ❌ Not implemented | Low |
| 9 | re_match | ❌ Not implemented | Medium |
| 10 | re_search | ❌ Not implemented | Medium |
| 11 | re_group | ❌ Not implemented | Medium |
| 12 | re_replace | ❌ Not implemented | Medium |
| 13 | savepoint | ❌ Not implemented | High |
| 14 | undo | ❌ Not implemented | High |
| 15 | save | ⚠️ Stub only | High |
| 16 | restore | ⚠️ Stub only | High |
| 17 | restart | ❌ Not implemented | High |
| 18 | max | ❌ Not implemented | Low |
| 19 | min | ❌ Not implemented | Low |
| 20 | makeString | ❌ Not implemented | Medium |
| 21 | getFuncParams | ✅ Implemented | |
| 22 | toNumber | ❌ Not implemented | Low |
| 23 | sprintf | ❌ Not implemented | Medium |
| 24 | makeList | ❌ Not implemented | Low |
| 25 | abs | ❌ Not implemented | Low |
| 26 | sgn | ❌ Not implemented | Low |
| 27 | concat | ❌ Not implemented | Low |
| 28 | re_search_back | ❌ Not implemented | Low |

## t3vm Function Set (vmbift3.h)

| Index | Function | Status | Priority |
|-------|----------|--------|----------|
| 0 | t3RunGC | ❌ Not implemented | Low |
| 1 | t3SetSay | ✅ Implemented | |
| 2 | t3GetVMVsn | ✅ Implemented | |
| 3 | t3GetVMID | ❌ Not implemented | Low |
| 4 | t3GetVMBanner | ❌ Not implemented | Low |
| 5 | t3GetVMPreinitMode | ✅ Implemented | |
| 6 | t3DebugTrace | ❌ Not implemented | Low |
| 7 | t3GetGlobalSymbols | ❌ Not implemented | Low |
| 8 | t3AllocProp | ❌ Not implemented | Medium |
| 9 | t3GetStackTrace | ❌ Not implemented | Medium |
| 10 | t3GetNamedArg | ❌ Not implemented | Low |
| 11 | t3GetNamedArgList | ❌ Not implemented | Low |

## Statistics

- **tads-gen**: 7 of 29 implemented (24%)
- **t3vm**: 4 of 12 implemented (33%)
- **Overall builtins**: 11 of 41 implemented (27%)

## Reference Files

- Spec: `packages/tads-sources/t3doc/techman/t3spec/fnset_t3.htm`
- tads-gen header: `packages/tads-runner/tads3/vmbiftad.h`
- tads-gen impl: `packages/tads-runner/tads3/vmbiftad.cpp`
- t3vm header: `packages/tads-runner/tads3/vmbift3.h`
- t3vm impl: `packages/tads-runner/tads3/vmbift3.cpp`
