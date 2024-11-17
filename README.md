# c-toxcore-build-with-zig

[![ci](https://github.com/nodecum/c-toxcore-build-with-zig/actions/workflows/ci.yaml/badge.svg)](https://github.com/nodecum/c-toxcore-build-with-zig/actions/workflows/ci.yaml)

The intension of this repository is to provide a zig build file for the
c-toxcore library. The usual way of doing this is to have build.zig in the
root of the library. To add no further dependencies to the back of the c-toxcore
developers this repository exists to be a proxy to the c-toxcore library.

## Building with zig 0.14.0 (2024.10.0-mach)
to install this zig version using [zvm](https://www.zvm.app) do

> zvm vmu zig mach

> zvm i 2024.10.0-mach

## Build the static library using [c-toxcore v0.2.19](https://github.com/TokTok/c-toxcore/releases/download/v0.2.19) 

> zig build install

## Update the list of C source files

If a new c-toxcore version should be used and names of files may have changed,
src/params.zig which contains the source files to be used can be updated by running

> zig build update

This will extracts the necessary c-toxcore sources from CMakeLists.txt. 

## Generate zig bindings

> zig build tox_zig
