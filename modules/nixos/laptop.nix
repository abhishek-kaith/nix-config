{ ... }:
let
  # ThinkPad charge thresholds, in percent. Charging stops at `end`, and does not
  # restart until the pack falls below `start` — the gap is what stops a machine
  # that lives on AC from cycling between 99% and 100% all day. 75/80 trades about
  # a fifth of the runtime for a large gain in pack lifespan; raise both (95/100)
  # for a day out with no charger, then rebuild to put them back.
  chargeStart = 75;
  chargeEnd   = 80;
in
{
  # Everything here is true because this host is a laptop with real hardware to
  # look after: firmware it can be updated from, a lid, and a battery that ages.
  # The VMs import none of it. Imported only by hosts/t480.
  #
  # NOT here: CPU/graphics/thermal tuning, TrackPoint, microcode, `throttled`,
  # the i915 kernel params. The nixos-hardware lenovo-thinkpad-t480 profile
  # already sets all of it — verified against the evaluated config, not assumed.

  # ── firmware updates ─────────────────────────────────────────────
  # Without this there is no path to a UEFI/BIOS or Thunderbolt controller update
  # on this machine at all, short of a bootable USB from Lenovo. fwupd pulls from
  # LVFS and stages UEFI capsules on the ESP (/boot, mounted by disko), so:
  #   fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr update
  # A capsule update applies during the *next* boot, not immediately.
  services.fwupd.enable = true;

  # ── lid close → suspend, then hibernate ──────────────────────────
  # hosts/t480/disko.nix sizes an 18G swap LV inside LUKS specifically so a full
  # 16G of RAM can be written out, and sets resumeDevice — but until now nothing
  # ever invoked hibernation, so that space was reserved for a feature that only
  # fired if you typed `systemctl hibernate`. This wires it to the lid.
  #
  # suspend-then-hibernate rather than plain hibernate: closing the lid suspends
  # (instant resume, the common case — moving between desks), and only if the
  # machine stays shut for HibernateDelaySec does it write RAM to swap and power
  # off. So a lid closed for two minutes costs nothing, and a lid closed overnight
  # no longer drains the battery flat.
  #
  # This works only because the swap LV lives *inside* LUKS and initrd unlocks it
  # before resume (boot.initrd.systemd.enable in base.nix). A random-key swap
  # would suspend fine and then lose the image on resume.
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  # HandleLidSwitchExternalPower is left unset: systemd defaults it to the value
  # above, which is what we want — the drain being avoided happens on AC too, and
  # a docked machine is covered separately by HandleLidSwitchDocked (default:
  # ignore, i.e. an external monitor keeps it awake with the lid shut).
  systemd.sleep.settings.Sleep.HibernateDelaySec = "30min";

  # ── battery charge thresholds ────────────────────────────────────
  # COSMIC cannot do this: cosmic-settings 1.6 declares get/set_charge_thresholds
  # on its System76 power-daemon D-Bus proxy, but the Power page only renders the
  # power-profile list and never calls them — and this machine is on
  # power-profiles-daemon regardless. TLP owns these knobs on other distros, but
  # TLP and power-profiles-daemon conflict over the same policy and COSMIC needs
  # ppd, so the thresholds are written to sysfs directly instead. thinkpad_acpi
  # exposes them and the kernel keeps them in the EC.
  systemd.services.battery-charge-thresholds = {
    description = "Apply ThinkPad battery charge thresholds";
    # Ordered *after* the sleep targets while also being wanted by them: sleep
    # targets are torn down in reverse, so this is the standard idiom for "run on
    # resume". The EC normally holds the values across a suspend, but a hibernate
    # cuts power, and this host now hibernates on its own.
    after    = [ "suspend.target" "hibernate.target" ];
    wantedBy = [ "multi-user.target" "suspend.target" "hibernate.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for bat in /sys/class/power_supply/BAT*; do
        start="$bat/charge_control_start_threshold"
        end="$bat/charge_control_end_threshold"
        # No battery, or a kernel that does not expose the knobs: nothing to do.
        # (The T480 can carry two packs — internal + hot-swappable — hence the loop.)
        [ -w "$end" ] || continue

        # Relax `start` before writing `end`. The driver rejects an end value that
        # would land below the current start, so a straight write fails depending
        # on whatever the EC happens to be holding from the last boot. Written as
        # if/fi rather than `[ -w x ] && echo`, so a machine without the start knob
        # cannot hand systemd a non-zero exit from the last line of the loop.
        if [ -w "$start" ]; then echo 0 > "$start"; fi
        echo ${toString chargeEnd} > "$end"
        if [ -w "$start" ]; then echo ${toString chargeStart} > "$start"; fi

        echo "''${bat##*/}: charge thresholds set to ${toString chargeStart}-${toString chargeEnd}%"
      done
    '';
  };
}
