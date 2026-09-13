# Macropad Layer Manager

Profile ("layer") manager for CH57x-based **6-key (3x2) + 1-knob** USB macropads
(VID:PID `1189:8890`) on Arch / CachyOS with KDE Plasma 6 (Wayland).

A single `Super+Q` press cycles to the next profile and re-flashes the device,
so the same six keys can be copy/paste shortcuts while coding and media
controls the rest of the time. An always-present Plasma widget shows what the
keys currently do.

<p align="center">
  <img src="docs/images/widget.png" alt="The macropad HUD: active profile, per-key labels and bindings, and the profile list" width="480">
</p>

This is a **companion to [`ch57x-keyboard-tool`](https://github.com/kriomant/ch57x-keyboard-tool)**,
not a replacement — all writing to the device is done by shelling out to that
CLI, and profiles are plain `ch57x-keyboard-tool` config files.

---

## Components

| Component | What it is |
|---|---|
| **HUD** (`org.flanshaw.macropadhud`) | Plasma 6 widget: compact, always-on-screen view of the keycaps |
| **`macropad-manager`** | GTK4/libadwaita GUI for editing, validating and uploading profiles |
| **`macropad-cycle`** | CLI that switches profile and flashes the device — what `Super+Q` runs |
| **`macropad-status`** | CLI that prints the current state as JSON (consumed by the HUD) |
| **`macropad-window`** | Kept for compatibility; KWin's native shortcuts do the job now |
| **`macropad-daemon`** | systemd `--user` oneshot that re-flashes the active profile at login |

The HUD polls `macropad-status` straight from disk, so the GUI does not need to
be running for anything else to work.

### The HUD

The friendly **label** sits above each key (`COPY`, `TERMINAL`, `FILES`, `VOL`)
and the raw **binding** inside the keycap (`ctrl-shift-c`, `ctrl-alt-t`, …).
The active profile is named top-left and marked with a dot in the list. Click a
profile name to switch to it immediately; click the gear to open the editor.

### The editor

<img src="docs/images/config.png" alt="The GTK4 editor: key diagram, per-slot label and binding fields, and validate/save/upload actions" width="720">

The diagram across the top mirrors the HUD. Below it, each slot has a **Label**
field and a **Binding** field. The sidebar is the `Super+Q` cycle order —
reorder it with the arrows, add with **+**, remove with the bin.

---

## Requirements

- Arch / CachyOS with KDE Plasma 6 (Wayland)
- Python 3.11+
- `ch57x-keyboard-tool` on `PATH` — the AUR package (with a udev rule) is easiest
- `python-yaml`, `python-gobject`, `gtk4`, `libadwaita`, `python-pipx`,
  `qt6-tools`, `plasma-workspace` — `install.sh` installs anything missing

### Device permissions

Uploading writes to the USB device directly, which needs a udev rule — without
it every upload fails with a permissions error unless run as root:

```bash
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1189", ATTR{idProduct}=="8890", MODE="0666"' \
  | sudo tee /etc/udev/rules.d/99-ch57x-macropad.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Replug the macropad afterwards.

---

## Install

```bash
git clone https://github.com/flanshaw/macropad.git
cd macropad
./install.sh                # or: ./install.sh '<Super>F9' for a different hotkey
```

The installer pipx-installs the package, installs and enables the systemd user
unit, seeds a couple of starter profiles, copies the HUD into
`~/.local/share/plasma/plasmoids/`, and registers the shortcuts in
`~/.config/kglobalshortcutsrc`:

- `Super+Q` runs `macropad-cycle` (a *command shortcut* via a
  `macropad-cycle.desktop` entry), and
- the knob chords are added to KWin's own `Walk Through Windows` /
  `Walk Through Windows (Reverse)` / `Overview` shortcuts.

> **Log out and back in afterwards.** Plasma (re)loads global shortcuts and
> scans `plasmoids/` at session start, so the hotkeys and the HUD appear after
> you do. Then: right-click the desktop → *Add Widgets* → **Macropad HUD**.
> (On the desktop it sits on the wallpaper; on a panel it floats above
> windows.)

---

## Usage

- **`Super+Q`** — cycle to the next profile. Works from any application and
  shows a desktop notification naming the profile that was loaded.
- **HUD** — click a profile to jump straight to it; click ⚙ to open the editor.
- **`macropad-manager`** — the GUI. Each binding row has a **Label** field
  (shown by the HUD) and a **Binding** field (the actual key). Buttons:
  - *Validate* — runs `ch57x-keyboard-tool validate` and shows the result inline
  - *Save* — writes the profile YAML
  - *Upload now* — flashes the edited profile immediately for testing
- **`macropad-cycle --set media`** — jump to a named profile from a script.
- **`macropad-cycle --restore`** — re-flash the active profile (run at login).
- **`macropad-status`** — print active profile, bindings and labels as JSON.
- **`macropad-window next|prev|overview`** — move window focus (see below).

Run `ch57x-keyboard-tool show-keys` for the list of valid binding names — note
that media keys are `prev` / `play` / `next`, not `prevsong` and friends.

### Switching windows with the knob

The window profile uses the knob to walk between open windows: rotate to move
focus one window at a time, press to toggle the Overview.

`alt-tab` cannot do this directly: the macropad releases every modifier between
detents, so a key combo that needs a modifier held down just flips between the
two most recent windows however far you turn. So the knob *pretends* to type a
full chord, and KWin's own global shortcuts pick it up:

```
knob CCW   -> Ctrl+Alt+Shift+F9   ->  Walk Through Windows (Reverse)
knob press -> Ctrl+Alt+Shift+F10  ->  Overview
knob CW    -> Ctrl+Alt+Shift+F11  ->  Walk Through Windows
```

No helper is needed — KWin handles these natively on Wayland, walks every
window once on a full turn, and the shortcuts keep their original default
bindings (`Alt+Tab`, `Metak+Tab`, `Meta+W`) as alternatives.

`install.sh` adds those three chords to the KWin actions. To use the knob this
way in another profile, set its `ccw` / `press` / `cw` to the same chords.

---

## Configuration

Everything lives in `~/.config/macropad-manager/`:

```
state.json      {"active_index": 0, "order": ["default.yaml", "media.yaml"]}
profiles/
    default.yaml
    media.yaml
```

See [docs/configuration.md](docs/configuration.md) for the full reference.

### Profile format

Profiles are ordinary `ch57x-keyboard-tool` configs, so they stay usable
directly (`ch57x-keyboard-tool upload < profiles/default.yaml`). Display labels
live under an extra `labels:` key, which the CLI ignores:

```yaml
model: ch57x-2
orientation: normal
rows: 2
columns: 3
knobs: 1
layers:
  - buttons:
      - [ctrl-shift-c, ctrl-alt-t, ctrl-alt-shift-f]
      - [previous, play, next]
    knobs:
      - ccw: volumedown
        press: mute
        cw: volumeup
labels:
  button1: COPY
  button2: TERMINAL
  button3: FILES
  knob_cw: VOL
```

---

## Documentation

| Document | Contents |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How the pieces fit together and why |
| [docs/configuration.md](docs/configuration.md) | Every config file and field |
| [docs/development.md](docs/development.md) | Working on the code, and KDE Plasma reload rules |
| [docs/troubleshooting.md](docs/troubleshooting.md) | When something does not work |
| [docs/spec.md](docs/spec.md) | The original design spec |

---

## Repository layout

```
src/macropad_manager/       Python package
    core.py                 state, profile YAML, ch57x-keyboard-tool wrapper
    gui.py                  GTK4/libadwaita editor
    cycle.py                macropad-cycle entry point
    status.py               macropad-status entry point
    window.py               macropad-window entry point (compat stub)
plasmoid/                   Plasma 6 HUD widget
    org.flanshaw.macropadhud/
profiles/                   starter profiles install.sh seeds on first run
systemd/                    user unit for login restore
docs/                       documentation
install.sh                  one-shot installer
```

---

## Known limitations

- **KDE Plasma 6 / Arch only.** Global hotkeys ride on `kglobalshortcutsrc` and
  command shortcuts, and the HUD is a Plasma widget. The `ch57x-keyboard-tool`
  CLI behaves the same on any platform.
- **No chorded keys** (key1+key2 together) — a firmware limitation of the
  device, not something this app can add.
- **Shortcut/hotkey changes need a re-login.** Plasma applies new global
  shortcuts and `plasmoids/` additions at session start.
- The HUD renders one knob, so it shows whichever knob action carries a label.
- **Knob window switching walks the current workspace only**, and relies on
  KWin's built-in `Walk Through Windows` / `Overview` shortcuts keeping the
  chords `install.sh` adds.

---

## License

[MIT](LICENSE)
