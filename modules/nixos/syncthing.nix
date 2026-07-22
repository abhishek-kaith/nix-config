{ user, ... }:
{
  # Syncthing runs as your user; folders/devices are added in the web UI at
  # http://127.0.0.1:8384. openDefaultPorts opens 22000/tcp (sync) + 21027/udp
  # (discovery) in the firewall; the GUI stays on localhost only.
  services.syncthing = {
    enable           = true;
    user             = user;
    configDir        = "/home/${user}/.config/syncthing";
    dataDir          = "/home/${user}";
    openDefaultPorts = true;
    guiAddress       = "127.0.0.1:8384";
    # don't let nix wipe devices/folders you add through the GUI
    overrideDevices  = false;
    overrideFolders  = false;
  };
}
