{
  description = "k's NixOS configuration";

  inputs = {
    nixpkgs.url          = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # hardware-specific tuning profiles (ThinkPad T480, T14 AMD Gen 1)
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # prebuilt, daily-updated nix-index database — no local `nix-index` runs;
    # the DB refreshes whenever you `nix flake update`
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
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
          # Keep root locked. The normal user's password is requested below and
          # is never stored in this repository or the Nix store.
          TMPDIR=/mnt/tmp nixos-install --flake ".#$host" --root /mnt --no-root-passwd

          # Seed this repo into the new system so the editable configs resolve on
          # first boot. Everything hangs off repoDir (/home/<user>/nix-config):
          # niri/tmux-sessionizer are out-of-store symlinks into it, and zsh/tmux/
          # git source files from it. Without this the fresh install comes
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

          if [ -n "$username" ]; then
            echo ">>> Set the login/sudo password for '$username'"
            nixos-enter --root /mnt -c "passwd $username"
          else
            echo "error: no normal user found; cannot set a login password" >&2
            exit 1
          fi

          echo ">>> Done. Reboot into the installed system."
        '';
      };
    in
    {
      nixosConfigurations = {
        vkvm = lib.mkHost { hostname = "vkvm"; user = "kvm";  };  # QEMU/KVM VM
        vbx  = lib.mkHost { hostname = "vbx";  user = "vbox"; };  # VirtualBox VM
        t480 = lib.mkHost { hostname = "t480"; };                 # ThinkPad T480 (user: k)
        t14  = lib.mkHost { hostname = "t14";  };                 # ThinkPad T14 Gen 1 AMD (user: k)
      };

      apps.${system}.install = {
        type    = "app";
        program = "${installer}/bin/install";
        meta.description = "Partition + install a host from the NixOS live ISO (disko + nixos-install)";
      };
    };
}
