{ pkgs, user, ... }:
{
  # Looking after the one disk that holds anything irreplaceable. Imported only by
  # hosts/t480 — the VMs run on virtual disks that are rebuilt from this repo, so
  # scrubbing them checks nothing and snapshotting them protects nothing.

  # ── btrfs scrub ──────────────────────────────────────────────────
  # btrfs checksums every block it stores but only verifies a block when something
  # reads it — so a bit that rots in a file you have not opened in a year is found
  # a year late, if ever. A scrub reads and verifies the whole filesystem, and with
  # single-profile data (no RAID) it cannot repair, only *report* — which is still
  # the difference between knowing a file is gone and silently backing up a
  # corrupt copy over the good one. `fileSystems` is left unset: the module fills
  # it in from every btrfs mount in the config, deduplicated by device, so the
  # three subvolumes here produce one scrub and not three.
  services.btrfs.autoScrub = {
    enable   = true;
    interval = "monthly";   # results land in `systemctl status btrfs-scrub-*`
  };

  # ── SMART monitoring ─────────────────────────────────────────────
  # The NVMe reports its own wear and error counters; nothing was reading them.
  # smartd polls and shouts before a failing drive becomes a dead one. Notification
  # is by `wall` only (module default) — the mail path stays off by itself because
  # no sendmail wrapper exists on this host, so there is no silently-failing mailer.
  services.smartd.enable = true;

  # ── snapshots ────────────────────────────────────────────────────
  # This is an "undo", NOT a backup: the snapshots live on the same LUKS volume as
  # the data, so they cover `rm -rf` on the wrong path and a bad rebuild — and
  # cover nothing at all if the SSD dies or the laptop is stolen. Off-machine
  # copies are still an open item; syncthing replicates deletions, so it is not it.
  #
  # /nix is deliberately not snapshotted. It is the one subvolume that is already
  # reproducible from this repo, and it is by far the largest — snapshotting it
  # would pin every garbage-collected store path and defeat `nix.gc`.
  services.snapper.configs = {
    root = {
      SUBVOLUME        = "/";
      ALLOW_USERS      = [ user ];
      TIMELINE_CREATE  = true;
      TIMELINE_CLEANUP = true;
      # Shallow on purpose: with /home and /nix on their own subvolumes, "/" is
      # mostly /etc and /var, which NixOS can already roll back by generation.
      TIMELINE_LIMIT_HOURLY  = 5;
      TIMELINE_LIMIT_DAILY   = 7;
      TIMELINE_LIMIT_WEEKLY  = 0;
      TIMELINE_LIMIT_MONTHLY = 0;
      TIMELINE_LIMIT_YEARLY  = 0;
    };
    home = {
      SUBVOLUME        = "/home";
      ALLOW_USERS      = [ user ];   # so `snapper -c home list` needs no sudo
      # ALLOW_USERS on its own only covers snapper's own commands — it does NOT
      # grant access to the /home/.snapshots tree, which snapper-bootstrap below
      # creates 0750 root:root. Without this, recovering a file by plain `cp` out
      # of a snapshot needs sudo, which is the most common thing you actually do
      # here. SYNC_ACL puts ALLOW_USERS on the directory as an ACL instead.
      #
      # Safe because it grants traversal of .snapshots and nothing more: the files
      # inside each snapshot keep the ownership and mode they had when it was
      # taken, so this exposes the user's own files back to them and no one else's.
      # Not set on the `root` config on purpose — those snapshots contain /etc and
      # /var, and there is no reason to hand a normal user a readable copy.
      SYNC_ACL         = true;
      TIMELINE_CREATE  = true;
      TIMELINE_CLEANUP = true;
      # Deeper, because this is the subvolume holding work that exists nowhere else.
      TIMELINE_LIMIT_HOURLY  = 8;
      TIMELINE_LIMIT_DAILY   = 10;
      TIMELINE_LIMIT_WEEKLY  = 4;
      TIMELINE_LIMIT_MONTHLY = 3;
      TIMELINE_LIMIT_YEARLY  = 0;
    };
  };

  # snapper requires a subvolume named `.snapshots` to already exist inside each
  # configured subvolume, and the NixOS module does not create one — it only writes
  # /etc/snapper/configs/*. Without this the timer starts failing an hour after the
  # first boot on the new config and nothing obvious says why. Creating them here
  # covers both paths at once: the machine that is already installed (next rebuild)
  # and a fresh disko install (first boot). Idempotent, so it is a no-op after that.
  systemd.services.snapper-bootstrap = {
    description = "Create the .snapshots subvolumes snapper expects";
    wantedBy    = [ "multi-user.target" ];
    path        = [ pkgs.btrfs-progs ];
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    script = ''
      for sv in / /home; do
        # ''${sv%/} strips the trailing slash so "/" yields "/.snapshots"
        snapdir="''${sv%/}/.snapshots"
        if [ ! -d "$snapdir" ]; then
          echo "creating $snapdir"
          btrfs subvolume create "$snapdir"
          # 750: snapshots of /home expose every user's files through one directory
          chmod 750 "$snapdir"
        fi
      done
    '';
  };

  # Ordering, so the first timeline run cannot land before the directories exist.
  systemd.services.snapper-timeline = {
    wants = [ "snapper-bootstrap.service" ];
    after = [ "snapper-bootstrap.service" ];
  };
  systemd.services.snapper-cleanup = {
    wants = [ "snapper-bootstrap.service" ];
    after = [ "snapper-bootstrap.service" ];
  };
}
