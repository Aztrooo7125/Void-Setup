#!/bin/bash
#  void_setup_v3.sh
#  Void Linux — i7-8650U / Intel UHD 620 / 16GB DDR4 2400MHz
#  niri · no waybar · mako status-hud · Void Night theme
#  ─────────────────────────────────────────────────────────────────────────
#  REUSABILITY: Hardware-specific blocks are marked ← [i7-8650U] / ← [UHD620].
#  Everything else is generic Void Linux.

xi() {
  sudo xbps-install "$@"
}

xr() {
  sudo xbps-remove "$@"
}

set -e
[ "$(id -u)" -eq 0 ] && echo "Run as regular user, not root." && exit 1
VOID_USER=$(id -un)
echo "Void Linux Setup — User: $VOID_USER"


# ─────────────────────────────────────────────────────────────────────────────
# (I.)  REPOS & INITIAL UPDATE
# ─────────────────────────────────────────────────────────────────────────────

sudo -v

xi -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
xi -Syu

xi -Sy dbus
sudo ln -sf /etc/sv/dbus /var/service/ && sudo sv up dbus 2>/dev/null || true

xi -Sy flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo


# ─────────────────────────────────────────────────────────────────────────────
# (II.)  FIRMWARE, MICROCODE & i915 OPTIONS             ← [i7-8650U/UHD620]
# ─────────────────────────────────────────────────────────────────────────────

xi -Sy linux-firmware

grep -q "GenuineIntel" /proc/cpuinfo && xi -Sy intel-ucode

#  i915 driver options for Intel UHD 620 (Kaby Lake-R / Gen 9.5)     ← [UHD620]
#  enable_guc=3 — GuC + HuC: enables full VA-API hardware decode (H.264/H.265)
#  enable_psr=1 — Panel Self-Refresh: power save on static content
#  enable_fbc=1 — Frame Buffer Compression: reduces VRAM bandwidth
if grep -q "GenuineIntel" /proc/cpuinfo; then
    sudo tee /etc/modprobe.d/i915.conf << 'EOF'
options i915 enable_guc=3 enable_psr=1 enable_fbc=1
EOF
fi

KVER=$(uname -r | grep -oP '^\d+\.\d+')
sudo xbps-reconfigure -f "linux${KVER}"


# ─────────────────────────────────────────────────────────────────────────────
# (III.)  GRUB — ZERO TIMEOUT + SHIFT → WINDOWS             ← [Kaby Lake-R]
# ─────────────────────────────────────────────────────────────────────────────

sudo tee /etc/default/grub << 'EOF'
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_DISTRIBUTOR="Void Linux"
GRUB_DEFAULT=0
GRUB_DISABLE_RECOVERY=true
EOF

sudo chmod +x /etc/grub.d/31_hold_shift
sudo grub-mkconfig -o /boot/grub/grub.cfg


# ─────────────────────────────────────────────────────────────────────────────
# (IV.)  CORE SERVICES
# ─────────────────────────────────────────────────────────────────────────────

xi -Sy elogind
sudo ln -sf /etc/sv/elogind /var/service/ && sudo sv up elogind 2>/dev/null || true

xi -Sy NetworkManager
[ -L /var/service/dhcpcd ] && sudo rm /var/service/dhcpcd
[ -L /var/service/wpa_supplicant ] && sudo rm /var/service/wpa_supplicant
sudo ln -sf /etc/sv/NetworkManager /var/service/
sleep 10; sudo sv up NetworkManager 2>/dev/null || true

xi -Sy chrony
sudo ln -sf /etc/sv/chronyd /var/service/

xr -RF pulseaudio || true


# ─────────────────────────────────────────────────────────────────────────────
# (V.)  USER GROUPS
# ─────────────────────────────────────────────────────────────────────────────

sudo usermod -aG audio,video,input,network,storage,wheel "$VOID_USER"


# ─────────────────────────────────────────────────────────────────────────────
# (VI.)  WIFI
# ─────────────────────────────────────────────────────────────────────────────

echo
read -rp "Set up WiFi now? [y/ANY]: " SETUP_WIFI
if [[ "$SETUP_WIFI" =~ ^[Yy]$ ]]; then
    nmcli device wifi list
    while true; do
        IFS=';' read -rp "Enter [SSID];[password]: " ssid password
        sudo nmcli device wifi connect "$ssid" password "$password"
        ping -c 4 8.8.8.8 > /dev/null 2>&1 && echo "Connected." && break
        echo "Failed, retrying."
    done
fi


# ─────────────────────────────────────────────────────────────────────────────
# (VII.)  DESKTOP — NIRI STACK (no waybar)
# ─────────────────────────────────────────────────────────────────────────────
#  Status is handled by a single mako notification script.
#  libnotify provides notify-send used by the status-hud script.

xi -Sy \
    niri \
    swaylock swaybg \
    foot \
    fuzzel \
    mako libnotify \
    brightnessctl \
    wl-clipboard \
    unzip iw \
    kanshi \
    lxsession mesa-dri xwayland-satellite\
    xdg-desktop-portal xdg-desktop-portal-wlr \
    xdg-user-dirs xdg-utils \
    gnome-themes-extra dconf \
    udiskie

xdg-user-dirs-update
mkdir -p ~/.startup_assets ~/Pictures


# ─────────────────────────────────────────────────────────────────────────────
# (VIII.)  AUDIO — PIPEWIRE
# ─────────────────────────────────────────────────────────────────────────────

xi -Sy \
    pipewire wireplumber \
    alsa-utils alsa-plugins-pulseaudio \
    pavucontrol

sudo ln -sf /etc/sv/pipewire /var/service/
sudo ln -sf /etc/sv/pipewire-pulse /var/service/
sudo ln -sf /etc/sv/wireplumber /var/service/


# ─────────────────────────────────────────────────────────────────────────────
# (IX.)  APPLICATIONS
# ─────────────────────────────────────────────────────────────────────────────

xi -Sy \
    libreoffice \
    firefox \
    mpv imv lmms\
    btop \
    yt-dlp \
    nano wget curl psmisc rsync\
    Thunar yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg ImageMagick glow \

curl https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh | sh
sudo flatpak install -y flathub md.obsidian.Obsidian com.github.johnfactotum.Foliate org.audacityteam.Audacity com.spotify.Client


#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# (X.) COMPLETE FONT SUITE (System, CJK, Symbols, Adobe, MS-compatible, Inter)
# ─────────────────────────────────────────────────────────────────────────────

xi -Syu
xi -Syu

# 1. Official Void Linux packages (Noto, CJK, Emoji, Icons, Standards)
xi -Sy \
    noto-fonts-ttf \
    noto-fonts-ttf-extra \
    noto-fonts-cjk \
    noto-fonts-emoji \
    dejavu-fonts-ttf \
    liberation-fonts-ttf \
    font-awesome \
    nerd-fonts-symbols-ttf \
    cantarell-fonts \
    cabextract

# Organized font directories
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"/{JetBrainsMono,NerdSymbols,Adobe,MSCoreFonts,MetricCompatible,Inter}

# Small helper: download with retries, report failure instead of failing silently
dl() {
    # $1 = url  $2 = output path
    if curl -fL --retry 3 --retry-delay 2 --show-error -o "$2" "$1"; then
        return 0
    else
        echo "    !! FAILED to download: $1" >&2
        return 1
    fi
}

echo "--> Rebuilding Font Cache..."
fc-cache -fv

# ─────────────────────────────────────────────────────────────────────────────
# (XI.)  DEV TOOLS + VA-API                                        ← [UHD620]
# ─────────────────────────────────────────────────────────────────────────────
#  iHD is the correct VA-API driver for Intel UHD 620 (Gen 8+ / Kaby Lake-R).
#  After reboot, verify: vainfo --display drm --device /dev/dri/renderD128
#  Firefox: set media.ffmpeg.vaapi.enabled=true in about:config

xi -Sy \
    xtools base-devel pkg-config \
    git github-cli lazygit \
    clang llvm cmake ninja meson gdb lldb strace \
    python3 python3-pip python3-devel python3-virtualenv uv \
    nodejs pnpm \
    rustup go \
    curl wget jq yq \
    ripgrep fd fzf bat eza btop \
    file tree unzip zip rsync direnv tmux neovim \
    sqlite openssl \
    bind-utils \
    intel-video-accel libva-utils vulkan-loader mesa-vulkan-intel \
    docker docker-compose \
    speedtest-cli

curl -f https://zed.dev/install.sh | sh
curl -fsSL https://opencode.ai/install | bash


# ─────────────────────────────────────────────────────────────────────────────
# (XII.)  PERFORMANCE
# ─────────────────────────────────────────────────────────────────────────────

# ── zram ─────────────────────────────────────────────────────────────────────
sudo mkdir -p /etc/sv/zram-swap
sudo tee /etc/sv/zram-swap/run << 'EOF'
#!/bin/sh
grep -q zram0 /proc/swaps && exec sleep infinity
modprobe zram
_sz=$(awk '/MemTotal/{printf "%.0f", $2 * 512}' /proc/meminfo)
grep -qw zstd /sys/block/zram0/comp_algorithm \
    && echo zstd > /sys/block/zram0/comp_algorithm \
    || echo lz4  > /sys/block/zram0/comp_algorithm
echo "$_sz" > /sys/block/zram0/disksize
mkswap /dev/zram0 >/dev/null
swapon -p 100 /dev/zram0
exec sleep infinity
EOF
sudo chmod +x /etc/sv/zram-swap/run
sudo tee /etc/sv/zram-swap/finish << 'EOF'
#!/bin/sh
swapoff /dev/zram0 2>/dev/null || true
EOF
sudo chmod +x /etc/sv/zram-swap/finish
sudo ln -sf /etc/sv/zram-swap /var/service/

# ── SSD trim ─────────────────────────────────────────────────────────────────
xi -Sy cronie
sudo ln -sf /etc/sv/crond /var/service/
echo "0 3 * * 0 root fstrim -av" | sudo tee /etc/cron.d/ssd-trim

# ── sysctl ───────────────────────────────────────────────────────────────────
sudo mkdir -p /etc/sysctl.d && sudo touch /etc/sysctl.d/99-void-performance.conf
sudo tee /etc/sysctl.d/99-void-performance.conf << 'EOF'
vm.swappiness = 100
vm.page-cluster = 0
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.dirty_writeback_centisecs = 1500
vm.vfs_cache_pressure = 50
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = cake
kernel.nmi_watchdog = 0
kernel.sched_autogroup_enabled = 1
EOF
sudo sysctl --system
printf 'tcp_bbr\nsch_cake\n' | sudo tee /etc/modules-load.d/perf.conf
sudo modprobe tcp_bbr 2>/dev/null || true
sudo modprobe sch_cake 2>/dev/null || true

# ── IO scheduler ─────────────────────────────────────────────────────────────
sudo mkdir /etc/udev/rules.d && sudo touch /etc/udev/rules.d/60-ioschedulers.rules
sudo tee /etc/udev/rules.d/60-ioschedulers.rules << 'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]n*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF

# ── earlyoom ─────────────────────────────────────────────────────────────────
xi -Sy earlyoom
sudo ln -sf /etc/sv/earlyoom /var/service/

# ── irqbalance ───────────────────────────────────────────────────────────────
xi -Sy irqbalance
sudo ln -sf /etc/sv/irqbalance /var/service/

# ── TLP (i7-8650U / HWP) ─────────────────────────────────────────────────── ← [i7-8650U]
xi -Sy tlp
sudo ln -sf /etc/sv/tlp /var/service/
sudo tee /etc/tlp.d/01-custom.conf << 'EOF'
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=schedutil
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
NMI_WATCHDOG=0
CPU_BOOST_ON_AC=1
SATA_LINKPWR_ON_AC=max_performance
SATA_LINKPWR_ON_BAT=med_power_with_dipm
PCIE_ASPM_ON_BAT=powersupersave
EOF


# ─────────────────────────────────────────────────────────────────────────────
# (XIII.)  SHELL — ZSH + OH-MY-ZSH + POWERLEVEL10K
# ─────────────────────────────────────────────────────────────────────────────

xi -Sy zsh
sudo chsh -s /bin/zsh "$VOID_USER"
RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"


# ─────────────────────────────────────────────────────────────────────────────
# (XIV.)  THEME CONFIGS + ENVIRONMENT SETUP
# ─────────────────────────────────────────────────────────────────────────────
#
#  Palette:
#    bg_deep   #1a1e24  — terminal, notification backgrounds
#    bg_base   #21262e  — slightly lighter surfaces
#    border    #3d4a5c  — window/panel borders
#    border_ac #6e9dbf  — status-hud accent border
#    text      #c5cdd8  — primary text
#    text_dim  #64718a  — muted / inactive
#    accent    #7a9db8  — blue-grey accent

cp -r .config ~/.config
cp -r .startup_assets ~
cp .misc/* ~
xr -OOo && sudo vkpurge rm all


printf '\n\e[1;34m────────────────────────────────────────────────────\e[0m\n'
printf '\e[1;34m  Git Configuration\e[0m\n'
printf '\e[1;34m────────────────────────────────────────────────────\e[0m\n\n'

read -rp "Enter Git Email: " git_email
read -rp "Enter Git Username: " git_user

if [ -n "$git_email" ]; then
    git config --global user.email "$git_email"
    echo "--> Git email set to: $git_email"
fi

if [ -n "$git_user" ]; then
    git config --global user.name "$git_user"
    echo "--> Git username set to: $git_user"
fi

printf '\n\e[1;32m────────────────────────────────────────────────────\e[0m\n'
printf '\e[1;32m  Setup complete.\e[0m\n'
printf '\e[1;32m────────────────────────────────────────────────────\e[0m\n\n'
sudo reboot
