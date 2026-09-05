# Cheatsheet

Every tool, key and app this config installs, and the one thing each is for.
`README.md` is the map of the repo; this is the map of what you got.

Searchable web version: <https://claude.ai/code/artifact/470da8fe-e99a-49a6-8379-4e953429e30d>

| Host   | Platform                 | User   |
|--------|--------------------------|--------|
| `t480` | ThinkPad T480            | `k`    |
| `t14`  | ThinkPad T14 Gen 1 (AMD) | `k`    |
| `vkvm` | QEMU/KVM VM              | `kvm`  |
| `vbx`  | VirtualBox VM            | `vbox` |

---

## Rebuilding & the Nix workflow

*Defined in `flake.nix`, `modules/nixos/base.nix`, `modules/nixos/dev.nix`.*

Nothing is installed imperatively. You edit a module, rebuild, and the whole
system moves as one generation — with the previous one still bootable.

### Apply and inspect

| Command | What it does |
|---|---|
| `sudo nixos-rebuild switch --flake ~/nix-config#t480` | Apply the config. Swap `t480` for this machine's own host attr. |
| `nixos-rebuild build --flake ~/nix-config#t480`<br>`nix store diff-closures /run/current-system ./result` | Build without activating, then read exactly which packages changed version. Built into nix. |
| `nix flake check` | Evaluate every host. Run before a switch — it catches a broken module on all four machines, not just yours. |
| `sudo nixos-rebuild --rollback` | Back to the previous generation. Or hold <kbd>Space</kbd> at boot for the generation menu. |

### Inputs and garbage

| Command | What it does |
|---|---|
| `nix flake update` | Bump every input: nixpkgs, home-manager, COSMIC's unstable, the agents, the nix-index database. |
| `nix flake update nixpkgs-unstable` | Just COSMIC's source — the desktop is pinned to unstable through an overlay. |
| `nix flake update llm-agents` | Just claude / codex / pi / opencode. They come from the `llm-agents` input precisely so they move on their own. |
| `nix-collect-garbage -d` | Manual GC. Automatic weekly GC (30-day retention) and store optimisation at 13:00 are already on. |
| `nix-tree` | Walk a closure's dependency graph — what is dragging in that 400 MB. |

### Finding things

| Command | What it does |
|---|---|
| `nix shell nixpkgs#<pkg>` | Run a program once without adding it to a module. The answer to "I need this for five minutes". |
| `nix-locate bin/<name>` | Which package provides this binary. The DB ships prebuilt and refreshes on `nix flake update` — never indexed locally. |
| `tldr <command>` | **tealdeer** — practical examples instead of a man page. |
| `nixfmt`, `nil` | Formatter and LSP for editing this repo itself. |

> **The rule of the repo.** Project toolchains (a pinned node, a go version,
> project deps) never go in a module — they go in a per-project `devShell`
> loaded by direnv, and one-offs go through `nix shell`. What lives in
> `dev.nix` is only what nvim and the agents need to start working at all.

---

## Shell — zsh, fzf, zoxide

*Defined in `modules/nixos/shell.nix`, `config/zsh/rc.zsh`.*

zsh in vi mode, with fuzzy finding bound into the line editor and a
frecency-ranked `cd`. `rc.zsh` is live-edited — open a new shell and it
applies, no rebuild.

### Keys

| Key | What it does |
|---|---|
| <kbd>Ctrl-R</kbd> | Fuzzy history search through fzf. |
| <kbd>Ctrl-T</kbd> | Fuzzy file picker — inserts the path onto the command line. |
| <kbd>Alt-C</kbd> | Fuzzy `cd` into a subdirectory. |
| <kbd>Ctrl-F</kbd> | Run **tmux-sessionizer** — pick a project, get a tmux session named after it. |
| <kbd>Ctrl-P</kbd> / <kbd>Ctrl-N</kbd> | History search backward / forward on what you have typed so far. |
| <kbd>Esc</kbd>, then vi keys | `bindkey -v` — the command line is a vi buffer. |
| <kbd>→</kbd> | Accept the greyed-out autosuggestion. |

### Behaviour

| Thing | What it does |
|---|---|
| `z <partial-name>` | **zoxide** — jump to a directory you visit often. `zi` picks interactively. |
| `<dirname>` ⏎ | `AUTO_CD` — a bare directory name changes into it. |
| *(leading space)* | Keeps the command out of history. Duplicates back-to-back are dropped too. |
| history | 10 000 entries, shared live across every open terminal. |
| `cd` into a project dir | **direnv** auto-loads the `.envrc` dev shell (silently). `direnv allow` on first visit. |
| `BAT_THEME=ansi` | bat and delta draw with the terminal's own 16 colours, so previews follow the COSMIC light/dark switch instead of fighting it. |
| prompt | **starship** — `config/starship.toml`, live-edited. Directory truncates to 3 segments / the repo root; git status shown. |

---

## tmux

*Defined in `config/tmux.conf`.*

Prefix is the default <kbd>Ctrl-b</kbd>. Windows start at 1. Most bindings are
repeatable — hold the prefix once and keep tapping the key.

| Key | What it does |
|---|---|
| `~/.scripts/tmux-sessionizer` | Fuzzy-pick a directory from `~`, `~/Projects`, `~/Projects/work`, `~/Projects/personal` → create or switch to a session named after it. Bound to <kbd>Ctrl-F</kbd> in zsh. |
| prefix <kbd>h</kbd>/<kbd>j</kbd>/<kbd>k</kbd>/<kbd>l</kbd> | Move to the pane left / down / up / right. Repeatable. |
| prefix <kbd>H</kbd>/<kbd>J</kbd>/<kbd>K</kbd>/<kbd>L</kbd> | Resize the pane by 2 cells in that direction. Repeatable. |
| prefix <kbd>m</kbd> | Zoom the current pane to full window (and back). |
| prefix <kbd>^</kbd> | Jump to the last window. |
| prefix <kbd>r</kbd> | Reload `tmux.conf` — this sources the repo file, so config edits apply instantly. |
| prefix <kbd>[</kbd> → <kbd>v</kbd> → <kbd>y</kbd> | Copy mode uses vi keys: `v` starts the selection, `y` copies it. |
| *mouse* | On — click panes, drag borders, scroll. Drag-release does **not** auto-copy, so a selection survives. |
| *escape-time* | 0 — no delay after <kbd>Esc</kbd>, which is what makes vi mode in nvim feel right inside tmux. |

---

## Neovim

*Defined in `config/nvim/`, `modules/home/neovim.nix`.*

Leader is <kbd>Space</kbd>. Plugins are managed by Neovim 0.12's built-in
`vim.pack`, pinned in `nvim-pack-lock.json` — commit that file and every host
gets identical revisions.

### Find — fzf-lua

| Key | What it does |
|---|---|
| <kbd>Ctrl-P</kbd> | Find files. |
| <kbd>Ctrl-\\</kbd> | Find open buffers. |
| <kbd>Ctrl-G</kbd> | Grep the project. |
| `<leader>l` | Live grep. |
| `<leader>k` | Pick from every fzf-lua picker — the way to reach the ones without a key. |
| <kbd>F1</kbd> | Search help tags. |

### Marks — grapple

| Key | What it does |
|---|---|
| `<leader>a` | Tag / untag the current file. |
| <kbd>Ctrl-E</kbd> | Open the tag list and jump between tagged files. |

### LSP

| Key | What it does |
|---|---|
| `gd` / `gD` / `gi` / `gr` | Definition / declaration / implementation / references. |
| `<leader>rn` | Rename symbol. |
| `<leader>ca` | Code action. |
| `<leader>e` | Toggle the diagnostic float, and focus it if already open. |
| `<leader>q` | Send diagnostics to the location list. |
| `<leader>f` | Format the buffer — conform routes to stylua / prettierd, falling back to the LSP. Also runs on save (500 ms budget). |
| *servers* | lua_ls, ts_ls, tailwindcss, clangd — installed by mason on first launch, along with stylua and prettierd. |

### Completion

| Key | What it does |
|---|---|
| <kbd>Alt-F</kbd> | Accept the **neocodeium** inline AI suggestion. |
| *menu* | blink.cmp with LuaSnip + friendly-snippets; signature help on, docs after 500 ms. |

### Git & editing

| Key | What it does |
|---|---|
| `<leader>lg` | Open **lazygit** inside nvim. gitsigns marks changes in the signcolumn. |
| <kbd>Esc</kbd> | Clear search highlight. |
| `<leader>o` | Write the buffer and re-source it — for editing this config. |
| `J` / `K` *(visual)* | Move the selected lines down / up, re-indenting. |
| `<` / `>` *(visual)* | Indent, keeping the selection. |
| <kbd>Ctrl-D</kbd>/<kbd>Ctrl-U</kbd>/`n`/`N` | All re-centre the cursor after moving. |
| `:CopyRFP`, `:CopyFP` | Copy the file path to the system clipboard — relative to `:pwd`, or absolute. `:CopyRDP`/`:CopyFDP` for the directory, `:CopyCWD` for the working dir. |
| `:lua vim.pack.update()` | Fetch plugin updates into a confirmation buffer — `:write` accepts, `:quit` discards. Commit the lockfile afterwards. |

> <kbd>Ctrl-h/j/k/l</kbd> are window movement, so the pickers that would collide
> use `<leader>` plus the same letter instead.

---

## Git

*Defined in `config/git/config`, `modules/nixos/packages.nix`.*

The shared config is in the repo; your name and email live in
`~/.config/git/local`, outside version control.

### Tools

| Command | What it does |
|---|---|
| `lazygit` | Full TUI for staging hunks, rebasing, stashing, browsing. Also reachable from nvim with `<leader>lg`. |
| `delta` | Syntax-highlighted diffs — follows `BAT_THEME`, so it matches the terminal. |
| `difft <a> <b>` | **difftastic** — structural diff. Shows that you moved a function rather than 200 changed lines. |
| `gh pr create`, `gh issue list` | GitHub from the terminal: PRs, issues, gists, releases. |
| `git lfs` | Large-file storage. |
| `tokei` | Count lines of code by language. |

### Behaviour already set

| Thing | What happens |
|---|---|
| `git push` *(new branch)* | Sets upstream automatically, and pushes annotated tags along with commits. |
| `git pull` | Rebases, and auto-stashes dirty work first. |
| `git rebase` | Autosquash `fixup!` commits, auto-stash, and update dependent branch refs in a stack. |
| `git fetch` | Prunes deleted remote branches and tags. |
| *conflicts* | `zdiff3` style — shows the common ancestor, so you can see what each side actually changed. **rerere** remembers how you resolved it. |
| *diffs* | Histogram algorithm, moved-block colouring, rename detection, `i/`-`w/`-`c/` prefixes instead of `a/`-`b/`. |
| `git branch` | Sorted by most recent commit, in columns. |
| `git commit` | Opens nvim with the full diff below the message. |
| *typos* | `git stauts` → prompts with the correction instead of just guessing. |

> **First boot, once per machine.** `git config --file ~/.config/git/local
> user.name "…"` and the same for `user.email`. Until then commits have no
> author.

---

## Files & search

*Defined in `modules/nixos/packages.nix`.*

| Command | What it does |
|---|---|
| `rg <pattern>` | **ripgrep** — grep across a tree, respecting `.gitignore`. Fast enough that it replaces the habit of narrowing first. |
| `fd <name>` | Find files by name. `find` without the syntax. |
| `fzf` | Fuzzy filter over any list. Pipe into it: `fd -t d \| fzf`. |
| `bat <file>` | `cat` with syntax highlighting, line numbers and git marks. |
| `eza -la --git` | `ls` with git status, icons and `--tree`. |
| `yazi` | TUI file manager with previews — the keyboard half of cosmic-files. |
| `tree` | Directory tree, plain. |
| `sd <find> <replace> <file>` | Find-and-replace with a sane syntax. `sed -i` without the escaping. |
| `wl-copy`, `wl-paste` | Pipe into and out of the Wayland clipboard: `cat key.pub \| wl-copy`. |

### Archives & transfer

| Command | What it does |
|---|---|
| `ouch d <file>`, `ouch c <out> <in…>` | One command to pack or unpack anything — it works out the format. |
| `unzip`, `zip`, `7z`, `unrar` | The specific ones, when you need a flag ouch doesn't expose. |
| `zstd`, `xz`, `bsdtar` | Modern `.zst`/`.xz` compression; bsdtar reads nearly every format. |
| `rsync -av <src> <dst>` | Incremental copy, local or over ssh. |
| `croc send <file>` | Device-to-device transfer over a relay with a spoken code phrase. No account, no LAN requirement. |
| `rclone` | Sync to cloud remotes (Drive, S3, B2, …). |
| `sshfs user@host:/path ~/mnt` | Mount a remote directory over ssh. |

---

## Monitoring the machine

*Defined in `modules/nixos/packages.nix`.*

| Command | What it does |
|---|---|
| `btop` | The one to open first — CPU, memory, disks, network, processes, all in one. |
| `htop` | The familiar process view when btop is more than you want. |
| `procs` | `ps` with a tree view, colour and search. |
| `iotop` | Which process is actually hitting the disk. |
| `bandwhich` | Live bandwidth **per process** — the one that answers "what is uploading right now". |
| `duf` | `df`, readable. Filesystem usage at a glance. |
| `ncdu` | Interactive disk usage — walk into the directory that is eating the SSD and delete from inside it. |
| `sensors` | Temperatures and fan speeds (**lm_sensors**). |
| `acpi -V` | Battery percentage, charge state, thermal zones. |
| `fastfetch`, `pfetch` | System summary. fastfetch is the detailed one. |
| `lspci`, `lsusb` | What hardware is actually attached (**pciutils**, **usbutils**). |
| `lsof`, `pstree`, `killall` | Open files; process tree; kill by name. |
| `file <path>` | What this actually is, regardless of extension. |
| `hyperfine '<cmd>'` | Benchmark a command properly — warmups, repeats, statistics. |
| `watchexec -e rs -- cargo test` | Re-run a command whenever matching files change. |
| `just <task>` | Project task runner — a `justfile` beside the code. |

---

## Network, DNS, HTTP

*Defined in `modules/nixos/packages.nix`, `modules/nixos/network.nix`.*

NetworkManager with systemd-resolved. DNS goes to Quad9 over TLS
opportunistically, Cloudflare as fallback; the firewall is on and only
Syncthing's ports are opened.

### Diagnose

| Command | What it does |
|---|---|
| `gping <host>` | Ping as a live graph — you see the jitter, not just the numbers. |
| `mtr <host>` | Traceroute and ping combined, continuously. The tool for "where in the path is it dropping". |
| `speedtest-cli` | Measure the actual ISP link. |
| `iftop` | Live per-connection throughput on an interface. |
| `iperf3 -s` / `iperf3 -c <host>` | Real throughput between two of your own machines. |
| `arp-scan --localnet` | Every device on the LAN, with MAC vendors. |
| `nmap <host>` | Port and service scan. |
| `tcpdump -i any port 443` | Packet capture, when nothing above explains it. |
| `whois <domain>` | Registration and ownership. |
| `nc -zv <host> <port>` | **netcat** — is that port even open. |

### DNS

| Command | What it does |
|---|---|
| `doggo <domain>` | Modern, colourful dig — understands DoH/DoT. |
| `dig`, `host`, `nslookup` | The classics, from **dnsutils**. |
| `resolvectl status` | What resolved is actually using per-interface — the check when DNS looks wrong. |

### HTTP & APIs

| Command | What it does |
|---|---|
| `xh <url>` | Friendly HTTP client, httpie-compatible: `xh POST api/x name=k`. |
| `curl`, `wget` | The universal fallbacks. |
| `grpcurl` | Call gRPC services from the shell. |
| `websocat <ws://…>` | Open and poke a websocket interactively. |

---

## JSON & data

*Defined in `modules/nixos/packages.nix`.*

| Command | What it does |
|---|---|
| `jq '.field'` | Query and reshape JSON in a pipeline. |
| `yq` | The same for YAML. |
| `jless <file.json>` | Interactive JSON viewer — fold, search, navigate a large response instead of squinting at it. |
| `fx` | Interactive viewer that also lets you type a JS expression against the data. |

---

## Media & documents

*Defined in `modules/nixos/apps.nix`, `modules/nixos/packages.nix`, `modules/home/xdg.nix`.*

GUI apps for looking at a file; CLI tools for doing something to it. The mime
defaults below are what `xdg-open` and double-click use.

### Apps

| App | What it is |
|---|---|
| `mpv <file\|url>` | Video and audio — including streaming a URL directly, via yt-dlp. Default for all video and audio types. HW decode on the T480. |
| `losange` | **Stremio client** — browse the catalogue, hand playback to an addon's stream. GTK4/libadwaita, so it follows COSMIC's light/dark on its own. Account and addons are configured in the app. |
| `qimgv` | Fast image viewer. Default for png / jpeg / gif / webp / tiff / bmp / avif / heif. |
| `gimp` | Real image editing — crop, retouch, layers. |
| `libreoffice` | The only thing here that opens .docx / .xlsx / .pptx and ODF. |
| `keepassxc` | Password manager. Browser integration is enabled inside the app, not in Nix. |
| `pavucontrol` | Per-application volume — finer than the panel applet. |
| `obs-studio` | Screen and webcam recording. Pick *Screen Capture (PipeWire)* as the source; the COSMIC portal handles the rest. |
| `satty -f ~/Pictures/Screenshots/x.png` | Annotate a screenshot — arrows, boxes, blur, text. cosmic-screenshot captures but cannot annotate. |
| *SVG* | Opens in Brave Origin — it is markup, and the browser renders it best. |

### From the shell

| Command | What it does |
|---|---|
| `yt-dlp <url>` | Download a stream. Needs no separate ffmpeg — nixpkgs already wraps one in. |
| `ffmpeg`, `ffprobe` | Transcode, cut, concatenate A/V yourself. |
| `magick`, `mogrify`, `identify` | **imagemagick** — scriptable image work: resize a folder, convert a format, read dimensions. |
| `exiftool -all= <file>` | Read or strip metadata — EXIF, GPS coordinates, camera serial. |
| `mediainfo <file>` | What codec, bitrate and profile is really inside. |
| `pdftotext`, `pdfimages`, `pdfunite` | **poppler-utils** — the CLI half of PDF work. |
| `vainfo` | Prove the Intel hardware-decode path is genuinely working. |

---

## Dev environment & containers

*Defined in `modules/nixos/dev.nix`.*

The shim layer that lets a NixOS machine behave like a normal Linux box for
prebuilt binaries, plus containers and phone tooling.

### Containers

| Command | What it does |
|---|---|
| `docker <…>` | It is **podman** under the name, with the docker socket enabled — compose and testcontainers work unchanged. |
| `docker-compose up` | Container DNS between services is on, which compose needs. |
| `lazydocker` | TUI over containers: logs, stats, shells, cleanup. |
| `dive <image>` | Walk an image layer by layer to see what is bloating it. |

### Phone

| Command | What it does |
|---|---|
| `adb`, `fastboot` | **android-tools**. USB permissions are handled automatically — nothing to configure. |
| `scrcpy` | Mirror and control a USB-connected Android phone from the desktop. |

### Runtimes & shims

| Thing | What it does |
|---|---|
| *nix-ld* | Why a downloaded, dynamically-linked binary runs at all here — Puppeteer's Chrome, mason's language servers, prebuilt npm native modules. |
| `uv run x.py`, `uvx ruff` | Python with no system Python. uv brings its own interpreters. |
| `node`, `npx` | The fallback runtime mason and MCP servers shell out to. Pin real versions per project in a devShell. |
| `cc` *(gcc)* | Needed by nvim-treesitter to compile parsers, and by node-gyp. |
| `chromium` | The scraper browser. `PUPPETEER_EXECUTABLE_PATH` and `CHROME_BIN` already point at it. |
| `./foo.AppImage` | Executable directly, via binfmt. |
| `flatpak install …` | Enabled, and it is also what makes cosmic-store appear. Add flathub once: `sudo flatpak remote-add --if-not-exists flathub …`. |
| *file limit* | 524 288 open files per process, up from systemd's 1024 — a large monorepo's watchers used to hit EMFILE. |

---

## AI coding agents

*Defined in `modules/nixos/dev.nix`, `lib/caches.nix`.*

From the `llm-agents` flake input rather than nixpkgs — it tracks upstream
releases within hours, and keeps agent bumps from dragging a new COSMIC along
with them. Each authenticates itself on first run; none can self-update,
because the store is read-only.

| Command | What it is |
|---|---|
| `claude` | Claude Code — Anthropic. State in `~/.claude`. |
| `codex` | OpenAI's Rust CLI; sandboxes with landlock/seccomp. State in `~/.codex`. |
| `pi` | Model-agnostic, MIT-licensed. Config in `~/.config/pi`. |
| `opencode` | Terminal coding agent. |
| `nix flake update llm-agents` | The only way they move. Prebuilt binaries come from `cache.numtide.com`. |

> **If a rebuild starts compiling an agent**, the numtide cache key rotated or
> the URL died. Check `lib/caches.nix` against the upstream flake's `nixConfig`.
> An unsigned path is rejected and built from source: slow, never wrong.

---

## The desktop — COSMIC

*Defined in `modules/nixos/cosmic.nix`, `modules/home/cosmic.nix`, `modules/nixos/desktop.nix`.*

COSMIC from nixpkgs-unstable through an overlay, with the greeter. Keybinds,
wallpaper and theme are COSMIC's own state under `~/.config/cosmic/` — not
managed by Nix, and they survive every rebuild.

### What ships with it

| App | What it is |
|---|---|
| `cosmic-files` | File manager, and the default handler for directories. gvfs gives it trash, mounting and network browsing. |
| `cosmic-term` | Terminal — what "Open in Terminal" resolves to. |
| `cosmic-edit` | Default for plain text. |
| `cosmic-reader` | Default for PDF; also thumbnails them in the file manager. |
| `cosmic-screenshot` | Capture. Saves to `~/Pictures/Screenshots`; annotate with satty. |
| `cosmic-store` | The app store — present only because flatpak is enabled. |
| `cosmic-launcher`, `cosmic-settings` | Launcher (pop-launcher backend) and settings. |
| `cosmic-randr` | Display configuration from the shell. |
| *cosmic-player* | Deliberately excluded — mpv is the video player. |

### Browser & theming

| Thing | What it does |
|---|---|
| `brave-origin` | The browser, from unstable, and the default for http/https/html. Its profile, extensions and settings are managed in its own UI. |
| `gtk-theme-sync` | Run it by hand to see what it decided. It watches COSMIC's `is_dark` flag and rewrites GTK3/GTK4 `settings.ini` so old GTK apps follow the light/dark switch — GTK4/libadwaita and COSMIC apps already do via the portal. |
| *fonts* | Iosevka Nerd Font (mono), JetBrains Mono as backup, Noto Sans/Serif, Noto Color Emoji. |
| *audio* | PipeWire with ALSA and PulseAudio compatibility; PulseAudio itself off. |
| `easyeffects` | GUI for the mic chain. Runs hidden as a service with the `mic` preset: RNNoise → DeepFilterNet → Speex (AGC + dereverb) → Exciter → Stereo Tools. If voices sound thin or underwater, bypass **one** of the two denoisers. |

---

## Background services & recovery

*Defined in `modules/nixos/storage.nix`, `syncthing.nix`, `laptop.nix`, `base.nix`.*

### Snapshots — laptops only

| Command | What it does |
|---|---|
| `snapper -c home list` | Timeline snapshots of `/home`: 8 hourly, 10 daily, 4 weekly, 3 monthly. No sudo needed. |
| `snapper -c home undochange N..M <path>` | Roll a file back to an earlier snapshot. |
| `snapper -c root list` | Same for `/`: 5 hourly, 7 daily. |
| `systemctl status btrfs-scrub-*` | Monthly btrfs scrub results — silent data corruption, found early. |
| `smartctl -a /dev/nvme0n1` | Drive health. **smartd** monitors it continuously. |

Snapshots are an undo, **not a backup** — they live on the same disk.

### Sync & firmware

| Command | What it does |
|---|---|
| <http://127.0.0.1:8384> | **Syncthing** UI, bound to localhost. Devices and folders are added in the UI and are never overwritten by a rebuild. |
| `fwupdmgr refresh && fwupdmgr get-updates`<br>`fwupdmgr update` | Firmware and BIOS updates — laptops. |

### Power — laptops

| Thing | What happens |
|---|---|
| *close the lid* | Suspend, then hibernate after 30 minutes. |
| `systemctl hibernate` | Worth confirming once after an install that resume actually works. |
| `cat /sys/class/power_supply/BAT*/charge_control_end_threshold` | Charging stops at 80% and restarts at 75%, reapplied after every suspend/hibernate. Change the pair in `laptop.nix`. |

### When things go wrong

| Command | What it tells you |
|---|---|
| `journalctl -u earlyoom` | What got killed when RAM ran out, and why. earlyoom SIGTERMs under 10% free, SIGKILLs under 5% — systemd-oomd is off. |
| `systemd-analyze critical-chain` | Where boot time actually goes. Measure before tuning. |
| `journalctl -b -p err` | Errors from this boot only. |
| *zram* | Compressed RAM swap, with swappiness at 180 and read-ahead off — the values zram wants, not the disk-swap ones. |
| *nix builds hogging the machine* | The daemon already runs at batch CPU priority and lowest I/O. Cap further with `max-jobs` per host. |
