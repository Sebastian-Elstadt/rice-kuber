# Kuber

A Hyprland rice built around a black-glass corporate terminal — Arasaka /
CP2077 corp-HUD, not neon cyberpunk and not Skemos's e-ink schematic look.
One hard accent (corp red), cold white text, a single cyan reserved for live
telemetry. Sharp corners everywhere, no gradients, no soft glow.

The headline visual decision: **no bar across the top.** `waybar/config.jsonc`
is an array of four small bar instances, one per screen corner — brand +
workspaces (top-left), a clock (top-right), vitals + security status
(bottom-left), audio/network/tray/mode (bottom-right) — closer to a game HUD
than a desktop taskbar.

Same function set as [Skemos](https://github.com/Sebastian-Elstadt/rice-skemos)
so muscle memory carries over between the two rices: `SUPER+W` window
switcher, `SUPER+S` security panel, minimize drawer, TILE/DESK toggle, etc.
Only the look changes. See `hypr/binds.lua` for the full bind list.

## Quick start

```sh
cd ~
git clone git@github.com:Sebastian-Elstadt/rice-kuber.git ~/.config
cd ~/.config
./install/bootstrap.sh
```

Same shape as Skemos's bootstrap: installs `install/packages.txt` from
official Arch repos only, detects GPU/microcode, wires up security tooling,
symlinks `~/.bashrc`/`~/.bash_profile`, optionally offers Claude Code.

## Layout

```
hypr/       Hyprland config (Lua) — compositor, binds, animations, scripts
waybar/     FOUR corner HUD modules (config.jsonc is a bar-config array)
rofi/       launcher — right-edge panel, filled-red selection
mako/       notifications — red left-rule, filled-red on urgent
foot/       kitty/     terminal configs
gtk-3.0/    gtk-4.0/   GTK theme settings
bash/       shell prompt + login banner
security/   firewall / auditd / rootkit / CVE / integrity scripts — SHARED
            backend (see "Security" below), plus Kuber's own panel skin
install/    bootstrap.sh, the package list, the Claude Code installer
```

## Security

Same provenance rule as Skemos: every package in `install/packages.txt`
comes from the official Arch `core`/`extra` repos — no AUR, no npm, no
curl-pipe-to-shell. The one documented exception is Claude Code
(`install/claude-code.sh`): opt-in, default No, downloaded to a file and
checksum-verified, never piped blindly to a shell.

**Deliberate architecture call, not an oversight:** the actual security
backend — `ufw`, `auditd`, `rkhunter`, `arch-audit`, the file-integrity
checker, their five systemd timers, the sudoers rule, the pacman hook, the
audit rules — is the exact SAME shared infrastructure Skemos installs.
Everything under `security/` in this repo still says `skemos-*`
(`/etc/skemos-security.conf`, `/var/log/skemos-security`,
`/usr/local/bin/skemos-security-run`, the `skemos-security` group) on
purpose: it's machine-level monitoring, not rice branding, and two rices
running two separate rootkit scanners / two separate auditd rule sets on
the same box would be waste, not safety. `install/bootstrap.sh` checks
whether that backend is already installed (by Skemos or a previous Kuber
run) and only joins its group if so; it installs the identical backend,
under the identical names, if neither rice has set it up yet — so Kuber
still bootstraps a bare machine standalone.

What *is* per-rice: `security/scripts/security-panel.sh` (the `SUPER+S`
terminal UI — reskinned for Kuber, reads the shared log/summary files),
`security-toggle.sh` (own `kuber-security` window class, so it doesn't
collide with Skemos's panel if both repos are ever checked out at once),
and `security-analyze.sh` (the optional read-only Claude Code triage
action). `waybar/scripts/security-status.sh` is new — a bottom-left pill
that shows the worst of the five jobs' status at a glance, reading the same
summaries; clicking it opens the full panel.

A pre-commit hook (`gitleaks`) blocks commits containing secrets, same as
Skemos.

## Status — what's built vs. not yet verified

This repo was assembled file-by-file against Skemos's existing structure as
a reference, but I could not actually launch Hyprland + Waybar from here to
screenshot it — there's no display available in this shell. Before calling
it done:

- **Waybar corner placement is the biggest unknown.** The four-bar
  `config.jsonc` + `style.css` are built on how Waybar's multi-bar array and
  per-bar `width`/`margin` are documented to behave; if a bar stretches
  full-width instead of sitting in its corner on your machine, that's the
  first thing to fix (trim `width` per bar in `config.jsonc`).
- Every shell script passed `bash -n` and every Lua config passed
  `luac -p`; the waybar JSON parses. That catches syntax errors, not
  runtime behavior.
- `install/bootstrap.sh`'s shared-backend branch (§11) is new logic, not
  something Skemos's bootstrap had to do — it hasn't been run against a
  machine that already has the Skemos backend installed. Worth a dry read
  before trusting it on `saber`.
- No wallpaper/hyprlock screenshot taken; the corner-bracket geometry in
  `hyprlock.conf` is carried over from Skemos's math at the same
  2560×1440 resolution, not re-measured.

None of this is destructive to try — `bootstrap.sh` asks before every
system-level change, same as Skemos's. Good next step: check it out
somewhere other than the live `~/.config` (or make the Skemos/Kuber
switcher the earlier conversation sketched) and actually run it.

## Machine

Same box as Skemos: `saber`, NVIDIA RTX 5070 + AMD iGPU, 2560×1440@180. The
GPU pin in `hypr/hyprland.lua` is machine-specific, not rice-specific, and
is duplicated here rather than shared — see that file's comment for why
(Aquamarine's output-primary pick races boot to boot without it).
