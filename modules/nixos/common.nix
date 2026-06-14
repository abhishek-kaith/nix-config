{ pkgs, ... }:
{
  time.timeZone      = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store   = true;
      trusted-users         = [ "root" "k" ];
      substituters          = [ "https://noctalia.cachix.org" ];
      trusted-public-keys   = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
    };
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 30d";
    };
    channel.enable = false; # flakes handle pinning; channels are redundant
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # system monitoring
    btop          # interactive resource monitor (cpu/mem/net/disk)
    lm_sensors    # hardware temp & fan speed  (run: sensors)
    # nvtop removed — pulls in CUDA; add back when you have a real GPU
    iotop         # per-process disk I/O

    # editors
    neovim        # modal editor  (run: nvim)
    vim           # fallback editor

    # file & search
    ripgrep       # fast grep replacement  (run: rg)
    fd            # user-friendly find
    fzf           # fuzzy finder (shell keybindings wired in shell.nix)
    bat           # cat with syntax highlighting
    eza           # modern ls with colours
    zoxide        # smart cd that learns your dirs  (run: z <partial>)
    tree          # print directory trees

    # archives
    unzip  # .zip extraction
    zip    # .zip creation
    p7zip  # .7z and many other formats
    rsync  # efficient file sync / remote copy

    # network
    curl  # HTTP client — transfer data from URLs
    wget  # HTTP downloader — mirrors, recursive fetch
    nmap             # network scanner
    dig              # DNS lookups
    netcat-openbsd   # nc — network debugging

    # data
    jq    # query/format JSON
    yq    # same for YAML

    tmux  # terminal multiplexer — sessions that survive disconnect
    git
    htop  # lightweight fallback to btop

    grimblast  # screenshot: area and fullscreen to clipboard
  ];
}
