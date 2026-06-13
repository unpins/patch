# GNU patch via cosmoStaticCross for Windows-x86_64.
#
# patch 2.8 added a POSIX symlink-attack sandbox (src/safe.c + safe.h) on top
# of the gnulib openat/fts machinery. mingw has none of that and its bundled
# gnulib ships no sys/resource.h replacement, so a pure-mingw cross dead-ends.
# cosmocc carries the POSIX layer (the same route e2fsprogs takes), and builds
# the upstream source with a couple of small portability fixes.
#
# Fixes vs the Linux/macOS build:
#
#  1. **DIRFD_INVALID constant-expression** — safe.h derives the sentinel as
#     `enum { DIRFD_INVALID = -1 - (AT_FDCWD == -1) }`. Under cosmocc AT_FDCWD
#     is an `extern const int` (a per-OS magic number resolved at link time,
#     canonical value -100), not a `#define`, so the enum initializer isn't a
#     constant expression and the build errors out. AT_FDCWD is never -1 on
#     cosmo, so the formula's result is simply -1 — pin it directly.
#
#  2. **`makedirs` collision** — cosmocc's libc exposes a `makedirs(const char*,
#     unsigned)` extension; patch declares its own `static void makedirs(char
#     const*)` in util.c. Same name, different signature → conflicting types.
#     Rename patch's private helper (word-boundaried, so `try_makedirs_errno`
#     is untouched).
#
#  3. **gnulib inline multiple-definition** — gnulib's headers (timespec.h,
#     …) declare functions like `timespec_cmp` with `_GL_INLINE`, expecting
#     classic gnu89 `extern inline` semantics where exactly one TU emits the
#     external copy. Under cosmocc's default C-std the test resolves to plain
#     external definitions, so every includer emits the symbol → "multiple
#     definition" at link. `-fgnu89-inline` restores the one-copy semantics.
{ unpins-lib }:
pkgs:
let
  cosmoPkgs = unpins-lib.lib.cosmoStaticCross pkgs;
in
cosmoPkgs.gnupatch.overrideAttrs (oa: {
  env = (oa.env or { }) // {
    NIX_CFLAGS_COMPILE = builtins.concatStringsSep " " [
      (oa.env.NIX_CFLAGS_COMPILE or "")
      "-fgnu89-inline"
    ];
  };
  postPatch = (oa.postPatch or "") + ''
    # fix 1: AT_FDCWD is extern const under cosmo → not a constant expression.
    substituteInPlace src/safe.h \
      --replace-fail 'enum { DIRFD_INVALID = -1 - (AT_FDCWD == -1) };' \
                     'enum { DIRFD_INVALID = -1 };'

    # fix 2: rename patch's private makedirs (collides with cosmo libc).
    sed -i 's/\bmakedirs\b/patch_makedirs/g' src/util.c
  '';
})
