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
  # See ./cosmo.nix (proven: applies a real patch under wine, 0 refs, single APE).
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

      build = pkgs: pkgs.pkgsStatic.gnupatch;
      windowsBuild = import ./cosmo.nix { inherit unpins-lib; };
    };
}
