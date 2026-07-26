# Laptop-only services. Imported by physical hosts, not the VM.
# These back noctalia's battery / bluetooth / power-profile widgets.
{ ... }:
{
  services.upower.enable                = true;  # battery + power events
  hardware.bluetooth.enable             = true;  # bluetooth radio
  services.power-profiles-daemon.enable = true;  # performance/balanced/saver toggle
  # NOTE: do NOT enable TLP here — it conflicts with power-profiles-daemon.

  # Hand the lid switch to niri, which runs `noctalia msg session lock-and-suspend`
  # (see switch-events in config/niri/config.kdl). logind's own default is a plain
  # suspend with no lock, so closing the lid and reopening it landed straight on an
  # unlocked desktop. Both handlers acting would race, hence "ignore" here.
  services.logind.settings.Login.HandleLidSwitch = "ignore";
}
