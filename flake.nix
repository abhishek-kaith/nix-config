{
  description = "k's NixOS configuration";

  inputs = {
    nixpkgs.url          = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    noctalia.url = "github:noctalia-dev/noctalia";
    # intentionally NOT following nixpkgs — noctalia cachix is built with its own nixpkgs;
    # overriding causes a hash mismatch and forces a full source compile

    # hardware-specific tuning profiles (e.g. ThinkPad T480)
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";
  };

  # inputs@ binds ALL inputs as a single attribute set called `inputs`
  # so we can pass the whole set to lib and down to every host module
  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, ... }:
    let
      system = "x86_64-linux";
      lib    = import ./lib { inherit nixpkgs nixpkgs-unstable inputs; };
      pkgs   = import nixpkgs { inherit system; };

      # One-command installer: partition+mount via disko, then nixos-install.
      # TMPDIR=/mnt/tmp keeps build scratch on the target disk (the live ISO's
      # /tmp is RAM-backed and overflows on a desktop closure).
      installer = pkgs.writeShellApplication {
        name = "install";
        # use the disko from our flake input (not nixpkgs) so the partitioner
        # and the host's disko NixOS module are the exact same revision
        runtimeInputs = [ inputs.disko.packages.${system}.disko pkgs.nixos-install-tools pkgs.coreutils ];
        text = ''
          host="''${1:-}"
          if [ -z "$host" ]; then
            echo "usage: nix run .#install -- <hostname>" >&2
            exit 1
          fi
          if [ ! -f flake.nix ]; then
            echo "error: run this from the repo root (no flake.nix in $PWD)" >&2
            exit 1
          fi

          echo ">>> Partitioning + mounting disk for '$host' (this ERASES the target disk)"
          disko --mode destroy,format,mount --flake ".#$host"

          echo ">>> Installing NixOS (TMPDIR on disk to avoid live-ISO RAM exhaustion)"
          mkdir -p /mnt/tmp
          # --no-root-passwd: skip the interactive root-password prompt; the
          # autologin 'k' user sets its own password on first boot (see README)
          TMPDIR=/mnt/tmp nixos-install --flake ".#$host" --root /mnt --no-root-passwd \
            --option extra-substituters https://noctalia.cachix.org \
            --option extra-trusted-public-keys noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=

          echo ">>> Done. Set a password on first boot: passwd k"
        '';
      };
    in
    {
      nixosConfigurations = {
        vm   = lib.mkHost { hostname = "vm"; };
        t480 = lib.mkHost { hostname = "t480"; };
      };

      apps.${system}.install = {
        type    = "app";
        program = "${installer}/bin/install";
        meta.description = "Partition + install a host from the NixOS live ISO (disko + nixos-install)";
      };
    };
}
