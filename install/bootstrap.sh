#!/usr/bin/env bash
#
# Kuber — bare-metal bootstrap. Run AFTER a standard Arch base install,
# as your normal user (in group wheel), from a TTY:
#
#     ~/.config/install/bootstrap.sh
#
# Does only: hardware detection, pacman install, enable PipeWire +
# NetworkManager, font cache, SSH key offer, git-hook wiring, append the
# Hyprland launch line to ~/.bash_profile, source the Kuber shell dressing
# from ~/.bashrc, and install the security tooling (root-owned copies,
# systemd timers, sudoers rule, pacman hook, audit rules, ufw) — UNLESS
# that security backend is already installed by another rice on this
# machine (e.g. Skemos), in which case it's shared rather than duplicated.
# See README.md "Security" for why.
# Does NOT touch disks, partitioning, the bootloader or autologin. The only
# boot-adjacent action is a `mkinitcpio -P` you are asked to confirm, which
# rewrites the initramfs image(s) in /boot.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '\n\033[1m>> %s\033[0m\n' "$*"; }

# Identity values that feed the root-owned conf, the sudoers rule and the audit
# rules come from the passwd database, not the (user-controllable) environment.
SK_USER="$(id -un)"
SK_HOME="$(getent passwd "$(id -u)" | cut -d: -f6 || true)"
if [[ ! $SK_USER =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "bootstrap: refusing unusual username '$SK_USER'" >&2; exit 1
fi
if [[ $SK_HOME != /* || $SK_HOME == *[[:space:]]* || $SK_HOME == *\\* ]]; then
  echo "bootstrap: refusing unusual home directory '$SK_HOME'" >&2; exit 1
fi
[[ $SK_HOME == "$HOME" ]] || echo "bootstrap: note — \$HOME ($HOME) differs from the passwd home ($SK_HOME); using the passwd home for system config." >&2
SK_HOME_SED="$(printf '%s' "$SK_HOME" | sed 's/[&|\\]/\\&/g')"

# 1. hardware detection ---------------------------------------------------
if ! command -v lspci >/dev/null 2>&1; then
  say "lspci not found — installing pciutils for hardware detection."
  sudo pacman -S --needed pciutils \
    || { echo "bootstrap: could not install pciutils (run 'sudo pacman -Sy pciutils' then re-run)" >&2; exit 1; }
fi
PCI_OUT="$(lspci -nn || true)"

detect_cpu_pkg() {
  case "$(grep -m1 '^vendor_id' /proc/cpuinfo | awk '{print $NF}' || true)" in
    AuthenticAMD) echo amd-ucode ;;
    GenuineIntel) echo intel-ucode ;;
    *) echo "" ;;
  esac
}

detect_gpu_pkgs() {
  if grep -Eq '(VGA compatible controller|3D controller).*\[10de:' <<<"$PCI_OUT"; then
    echo "nvidia-open-dkms linux-headers egl-wayland"
  fi
}

cpu_pkg="$(detect_cpu_pkg)"
gpu_pkgs="$(detect_gpu_pkgs)"

say "Detected CPU: $(grep -m1 '^model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//' || true) -> ${cpu_pkg:-'(unknown vendor — add your microcode package manually)'}"
say "Detected GPU(s):"
grep -E 'VGA compatible controller|3D controller' <<<"$PCI_OUT" | sed 's/^/   /' || true
if [[ -n $gpu_pkgs ]]; then
  say "  -> NVIDIA present, adding: $gpu_pkgs"
fi

# 2. packages ---------------------------------------------------------
mapfile -t PKGS < <(sed -E 's/#.*//' "$HERE/packages.txt" | tr -s ' \t' '\n' | grep -E '^[a-z0-9]')
ALL_PKGS=("${PKGS[@]}" mesa)
[[ -n $cpu_pkg ]] && ALL_PKGS+=("$cpu_pkg")
[[ -n $gpu_pkgs ]] && ALL_PKGS+=($gpu_pkgs)

say "Install / verify ${#ALL_PKGS[@]} packages:"
printf '   %s\n' "${ALL_PKGS[@]}"
read -r -p "   Enter to run 'sudo pacman -Syu --needed ...', Ctrl-C to abort. " _
sudo pacman -Syu --needed "${ALL_PKGS[@]}"

# 3. nvidia system changes (confirm-before-apply) --------------------
if [[ -n $gpu_pkgs ]]; then
  say "NVIDIA detected — reviewing system-level changes. Each one asks"
  say "before touching /etc; none of this touches disks or the bootloader. (The only boot-adjacent step is a 'mkinitcpio -P' you confirm.)"

  NOUVEAU_CONF=/etc/modprobe.d/nouveau-blacklist.conf
  if [[ -f $NOUVEAU_CONF ]] && grep -q '^blacklist nouveau' "$NOUVEAU_CONF" 2>/dev/null; then
    say "  $NOUVEAU_CONF already blacklists nouveau — skipping."
  else
    echo "  Would create $NOUVEAU_CONF containing: blacklist nouveau"
    read -r -p "  Apply? [y/N] " a
    if [[ $a == y || $a == Y ]]; then
      echo "blacklist nouveau" | sudo tee "$NOUVEAU_CONF" >/dev/null
    fi
  fi

  MKINITCPIO=/etc/mkinitcpio.conf
  if grep -qE '^MODULES=.*nvidia' "$MKINITCPIO" 2>/dev/null; then
    say "  $MKINITCPIO already lists an nvidia module set — skipping."
  else
    say "  $MKINITCPIO needs an nvidia module set, e.g.:"
    say '    MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)'
    read -r -p "  Open it in \$EDITOR now? [y/N] " a
    if [[ $a == y || $a == Y ]]; then
      SUDO_EDITOR="${EDITOR:-${VISUAL:-/usr/bin/nvim}}" sudoedit "$MKINITCPIO" \
        || say "  editor failed — edit $MKINITCPIO by hand, then run 'sudo mkinitcpio -P'."
      say "  'mkinitcpio -P' rewrites the initramfs image(s) in /boot (on systemd-boot layouts /boot is the ESP)."
      read -r -p "  Run 'sudo mkinitcpio -P' now (needed for the change to take effect)? [y/N] " b
      [[ $b == y || $b == Y ]] && sudo mkinitcpio -P
    fi
  fi

  for svc in nvidia-suspend nvidia-resume nvidia-persistenced; do
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
      say "  $svc.service already enabled — skipping."
    else
      read -r -p "  Enable $svc.service (needed for suspend/resume to work)? [Y/n] " a
      [[ $a != n && $a != N ]] && sudo systemctl enable "$svc"
    fi
  done

  say "  Kernel cmdline still needs (bootloader-specific, manual — see INSTALL.md §4):"
  say "    nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"
fi

# 4. audio --------------------------------------------------------------
say "Enabling PipeWire user services."
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service

# 5. networking -------------------------------------------------------
say "Enabling NetworkManager."
sudo systemctl enable --now NetworkManager.service

# 6. fonts -----------------------------------------------------------
say "Rebuilding font cache."
# No curl fetch here: unlike Skemos's Departure Mono (AUR-only, fetched as a
# checksummed OTF), Kuber's display font (JetBrains Mono Nerd) is an
# official-repo package already installed in step 2. One less exception.
fc-cache -f

# 7. ssh readiness -----------------------------------------------------
say "Checking SSH readiness."
if ! compgen -G "$HOME/.ssh/id_ed25519" >/dev/null && ! compgen -G "$HOME/.ssh/id_rsa" >/dev/null; then
  read -r -p "  No SSH keypair found. Generate one now (ed25519)? [Y/n] " a
  if [[ $a != n && $a != N ]]; then
    ssh-keygen -t ed25519 -C "$USER@$(uname -n)" -f "$HOME/.ssh/id_ed25519"
    say "  Public key (add this to GitHub/GitLab/wherever you push):"
    cat "$HOME/.ssh/id_ed25519.pub"
  fi
else
  say "  SSH keypair already present — skipping."
fi

# 8. git hooks (gitleaks secret scan) ----------------------------------
if [[ "$(git -C "$HOME/.config" config --get core.hooksPath 2>/dev/null)" != ".githooks" ]]; then
  say "Wiring the gitleaks pre-commit hook (git config core.hooksPath .githooks)."
  git -C "$HOME/.config" config core.hooksPath .githooks
else
  say "git hooks already wired — skipping."
fi

# 9. launch on login ----------------------------------------------
if ! grep -q 'start-hyprland' "$HOME/.bash_profile" 2>/dev/null; then
  say "Appending the Hyprland launch guard to ~/.bash_profile"
  printf '\n' >> "$HOME/.bash_profile"
  cat "$HERE/bash_profile.snippet" >> "$HOME/.bash_profile"
else
  say "~/.bash_profile already has a start-hyprland line — leaving it."
fi

# 10. shell dressing -------------------------------------------------
if ! grep -q 'bash/kuber.bash' "$HOME/.bashrc" 2>/dev/null; then
  say "Sourcing the Kuber shell dressing (prompt + banner) from ~/.bashrc"
  {
    printf '\n# Kuber shell dressing (corp-terminal prompt + login banner).\n'
    printf '[[ -f ~/.config/bash/kuber.bash ]] && . ~/.config/bash/kuber.bash\n'
  } >> "$HOME/.bashrc"
fi

# 11. security tooling ---------------------------------------------------
# This backend (group, /etc/skemos-security.conf, the five systemd units,
# the sudoers rule, the pacman hook, the audit rules) is SHARED machine-level
# infrastructure, not per-rice branding — it keeps its original "skemos-*"
# names on purpose so Kuber and Skemos read the exact same monitoring data
# instead of running two rootkit scanners / two auditd rule sets side by
# side. If it's already installed (by Skemos, or a previous Kuber run),
# this step just joins the group and otherwise does nothing.
if command -v skemos-security-run >/dev/null 2>&1 || [[ -x /usr/local/bin/skemos-security-run ]]; then
  say "Shared security backend already installed — joining its group, not reinstalling."
  getent group skemos-security >/dev/null && sudo usermod -aG skemos-security "$SK_USER"
  say "Log out/in once for the skemos-security group to take effect."
else
  say "Installing the shared security backend (systemd units, sudoers rule, pacman hook)."

  SEC_SRC="$HERE/../security"

  if ! getent group skemos-security >/dev/null; then
    sudo groupadd skemos-security
  fi
  sudo usermod -aG skemos-security "$SK_USER"

  printf 'SKEMOS_USER=%q\nSKEMOS_HOME=%q\n' "$SK_USER" "$SK_HOME" \
    | sudo install -o root -g root -m 0644 /dev/stdin /etc/skemos-security.conf

  sudo install -d -o root -g root -m 0755 /usr/local/lib/skemos-security
  sudo install -o root -g root -m 0755 \
    "$SEC_SRC/scripts/lib.sh" \
    "$SEC_SRC/scripts/integrity-check.sh" \
    "$SEC_SRC/scripts/rkhunter-scan.sh" \
    "$SEC_SRC/scripts/arch-audit-scan.sh" \
    "$SEC_SRC/scripts/ufw-status.sh" \
    "$SEC_SRC/scripts/audit-status.sh" \
    /usr/local/lib/skemos-security/
  sudo install -o root -g root -m 0644 "$SEC_SRC/arch-audit-ack.txt" /usr/local/lib/skemos-security/arch-audit-ack

  sudo ln -sfn /usr/local/lib/skemos-security/integrity-check.sh /usr/local/bin/skemos-integrity
  sudo install -o root -g root -m 0755 "$SEC_SRC/scripts/skemos-security-run" /usr/local/bin/skemos-security-run

  sudo install -o root -g root -m 0644 "$SEC_SRC"/systemd/*.service "$SEC_SRC"/systemd/*.timer /etc/systemd/system/
  sudo systemctl daemon-reload

  tmp_sudoers="$(sudo mktemp)"
  sudoers_ok=0
  sed "s/__SKEMOS_USER__/$SK_USER/g" "$SEC_SRC/sudoers.d/skemos-security" | sudo tee "$tmp_sudoers" >/dev/null
  if sudo visudo -c -f "$tmp_sudoers"; then
    sudo install -o root -g root -m 0440 "$tmp_sudoers" /etc/sudoers.d/skemos-security
    sudoers_ok=1
    say "  sudoers rule installed."
  else
    say "  sudoers template failed validation — NOT installed (see visudo output above)."
  fi
  sudo rm -f "$tmp_sudoers"

  sudo install -d -o root -g root -m 0755 /etc/pacman.d/hooks
  sudo install -o root -g root -m 0644 "$SEC_SRC/pacman-hooks/99-skemos-integrity-resync.hook" /etc/pacman.d/hooks/

  sudo install -d -o root -g root -m 0750 /etc/audit/rules.d
  install -d -m 0700 "$SK_HOME/.ssh"
  sed "s|__SKEMOS_HOME__|$SK_HOME_SED|g" "$SEC_SRC/audit-rules/skemos.rules" | sudo install -o root -g root -m 0640 /dev/stdin /etc/audit/rules.d/skemos.rules
  sudo systemctl enable --now auditd.service
  sudo augenrules --load || say "  audit rules failed to load — check 'sudo auditctl -l'"

  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo systemctl enable ufw.service
  sudo ufw --force enable

  sudo /usr/local/lib/skemos-security/integrity-check.sh --rebaseline-all \
    || say "  first integrity baseline failed — the first timer run will create it; see /var/log/skemos-security/integrity.log"
  sudo rkhunter --propupd || true

  for t in skemos-integrity rkhunter-scan arch-audit-scan ufw-status audit-status; do
    sudo systemctl enable --now "$t.timer" || say "  could not enable $t.timer — check 'systemctl status $t.timer'"
  done

  say "Security tooling installed. Log out/in once for the skemos-security group to take effect."
  if (( ! sudoers_ok )); then
    say "WARNING: sudoers rule NOT installed — SUPER+S run-now will not work until fixed."
  fi
fi

# 12. Claude Code (optional, prompted; a documented exception to
# official-repos-only — see install/claude-code.sh) -----------------------
"$HERE/claude-code.sh" || say "Claude Code step did not complete (non-fatal)."

say "Done. Verify with 'Hyprland --verify-config', then log out and log back in."
