# c-toxcore-build-with-zig
The intension of this repository is to provide a zig build file for the
c-toxcore library. The usual way of doing this is to have build.zig in the
root of the library. To add no further dependencies to the back of the c-toxcore
developers this repository exists to be a proxy to the c-toxcore library.

## build the static library
> zig build install

If a new version should be used, src/params.zig which contains the
source files to be used can be updated by running

> zig build update

which pulls the necessary c-toxcore sources. 

> zig build tox_zig

can be used to generate the zig bindings to the toxcore library.
