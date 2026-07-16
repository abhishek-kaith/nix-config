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
          # autologin user sets its own password on first boot (see README)
          TMPDIR=/mnt/tmp nixos-install --flake ".#$host" --root /mnt --no-root-passwd \
            --option extra-substituters https://noctalia.cachix.org \
            --option extra-trusted-public-keys noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=

          # Seed this repo into the new system so the editable configs resolve on
          # first boot. Everything hangs off repoDir (/home/<user>/nix-config):
          # niri/tmux-sessionizer are out-of-store symlinks into it, and zsh/tmux/
          # git/alacritty source files from it. Without this the fresh install comes
          # up with dangling symlinks and an empty shell until a manual git clone.
          #
          # Derive the user from the freshly-installed /mnt/etc/passwd (name, uid,
          # gid, home in one shot) so it stays correct for any host, not just 'k'.
          username="" uid="" gid="" home=""
          while IFS=: read -r pw_name _ pw_uid pw_gid _ pw_home _; do
            case "$pw_uid" in *[!0-9]*|"") continue ;; esac   # skip non-numeric uids
            if [ "$pw_uid" -ge 1000 ] && [ "$pw_uid" -lt 65534 ]; then
              username="$pw_name" uid="$pw_uid" gid="$pw_gid" home="$pw_home"
              break   # first normal user (every host here has exactly one)
            fi
          done < /mnt/etc/passwd

          if [ -n "$username" ]; then
            echo ">>> Seeding repo to $home/nix-config for user '$username'"
            mkdir -p "/mnt$home/nix-config"
            cp -a ./. "/mnt$home/nix-config"          # -a keeps .git → real working copy
            chown -R "$uid:$gid" "/mnt$home/nix-config"
          else
            echo "warning: no normal user in /mnt/etc/passwd — skipping repo seed" >&2
          fi

          [ -n "$username" ] || username="<user>"
          echo ">>> Done. Set a password on first boot: passwd $username"
        '';
      };
    in
    {
      nixosConfigurations = {
        vkvm = lib.mkHost { hostname = "vkvm"; user = "kvm";  };  # QEMU/KVM VM
        vbx  = lib.mkHost { hostname = "vbx";  user = "vbox"; };  # VirtualBox VM
        t480 = lib.mkHost { hostname = "t480"; };                 # ThinkPad (user: k)
      };

      apps.${system}.install = {
        type    = "app";
        program = "${installer}/bin/install";
        meta.description = "Partition + install a host from the NixOS live ISO (disko + nixos-install)";
      };
    };
}
