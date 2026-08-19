{
  description = "GNU patch as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # Single binary, no companions. Native from pkgsStatic.gnupatch.
  #
  # Windows: patch 2.8 added a POSIX-only symlink-attack sandbox (src/safe.c,
  # using getrlimit/openat/symlinks + <sys/resource.h>), and its bundled gnulib
  # has no sys/resource.h replacement. The mingw cross hits a wall of POSIX gaps
  # (incompatible-pointer rewinddir, S_IFLNK, sys/resource.h, …). Windows distros
  # build patch under msys2/cygwin — a POSIX layer — which is exactly what cosmo
  # provides for a single binary. So Windows goes through cosmo, not mingw.
  # See ./cosmo.nix (proven: applies a real patch under wine, 0 refs, single PE .exe).
  outputs = { self, unpins-lib }:
    let lib = unpins-lib.lib;
    in
    lib.mkStandaloneFlake {
      inherit self;
      name = "patch";
      binName = "patch";
      # Upstream nixpkgs attr is `gnupatch` (binary is `patch`). pkgsAttr must
      # name it so the engine's stdenv override targets the right attr.
      pkgsAttr = "gnupatch";
      smoke = [ "--version" ];
      smokePattern = "GNU patch";

      # Build via the unpin-llvm engine + emit a bitcode multicall module
      # (one program). Windows cosmo path is untouched (engine is Linux-only).
      engine = "unpin-llvm";
      multicall = {
        programs = [{ name = "patch"; }];
      };

      build = pkgs:
        let drv = pkgs.pkgsStatic.gnupatch; in
        drv.overrideAttrs (old: {
          # Run GNU patch's testsuite on native runners; auto-skips on crosses
          # the build host can't execute. `ed` is a check-only input: the
          # ed-style-patch tests shell out to it.
          doCheck = drv.stdenv.buildPlatform.canExecute drv.stdenv.hostPlatform;
          nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [ pkgs.buildPackages.ed ];
          # ... but having `ed` on PATH at configure time makes
          # `AC_PATH_PROG([ED], [ed], [ed])` bake its ABSOLUTE store path into
          # EDITOR_PROGRAM, so the shipped binary carries a store ref that does
          # not exist on a user's machine (and drags ed's closure). patch runs
          # the editor through system(), so a bare name resolves via PATH at
          # runtime — which is what every distro build ships. Pre-seed the
          # autoconf cache var; the test suite still finds ed on PATH.
          configureFlags = (old.configureFlags or [ ]) ++ [ "ac_cv_path_ED=ed" ];
          # Drop the flaky `bad-filenames` test: its `emit_patch | patch`
          # pipeline races — when patch fast-fails on a bad name, `cat` loses
          # the write and prints "cat: write error: Broken pipe", which 2>&1
          # captures into the compared output. It lost the race on i686. The
          # other 48 tests run.
          postPatch = (old.postPatch or "") + ''
            sed -i '/^\tbad-filenames \\$/d' tests/Makefile.am tests/Makefile.in
          '';
        });
      windowsBuild = import ./cosmo.nix { inherit unpins-lib; };
    };
}
