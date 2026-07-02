# patch

[GNU patch](https://savannah.gnu.org/projects/patch/) — applies a diff/patch file to one or more originals. A single self-contained binary, built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/patch/actions/workflows/patch.yml/badge.svg)](https://github.com/unpins/patch/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install patch`.

## Usage

Run the `patch` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin patch -p1 < changes.patch      # apply a unified diff
unpin patch file.txt changes.patch   # patch a single file
```

To install it onto your PATH:

```bash
unpin install patch
```

## Build locally

```bash
nix build github:unpins/patch
./result/bin/patch --version
```

Or run directly:

```bash
nix run github:unpins/patch -- --version
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/patch/releases) page has standalone binaries for manual download.

## Build notes

- **Platforms:** Linux, macOS, Windows.
- **Windows:** built via [Cosmopolitan](https://github.com/jart/cosmopolitan), not mingw — see [`cosmo.nix`](cosmo.nix). patch 2.8 added a POSIX-only symlink-attack sandbox (`src/safe.c`: `getrlimit`/`openat`/`<sys/resource.h>`) whose bundled gnulib has no mingw replacement, so the mingw cross dead-ends in a wall of POSIX gaps; Windows distros build patch under msys2/cygwin, which is the POSIX layer cosmo provides for a single binary. Three small libc fixes vs the Linux/macOS build: `-fgnu89-inline` (gnulib's `_GL_INLINE` expects gnu89 `extern inline`), pin `DIRFD_INVALID = -1` (cosmo exposes `AT_FDCWD` as a link-time `extern const int`, not a constant expression), and rename patch's static `makedirs` (cosmo's libc already exports a `makedirs`).
- **Man pages:** `patch.1` is embedded; read with `unpin man patch`.
- **Tests:** GNU patch's testsuite runs on native builds (0 failures under static-musl) and auto-skips on cross targets the build host can't execute.
