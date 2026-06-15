# Laptop-only services. Imported by physical hosts, not the VM.
# These back noctalia's battery / bluetooth / power-profile widgets.
{ ... }:
{
  services.upower.enable                = true;  # battery + power events
  hardware.bluetooth.enable             = true;  # bluetooth radio
  services.power-profiles-daemon.enable = true;  # performance/balanced/saver toggle
  # NOTE: do NOT enable TLP here — it conflicts with power-profiles-daemon.
}
