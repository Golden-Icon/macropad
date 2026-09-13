# Architecture

## Overview

Four small programs share one directory of state. Nothing talks over a socket
or a bus; the filesystem is the integration point, and the HUD polls the CLI
for changes.

```
      Ctrl+Shift+Q (Plasma) ─▶  macropad-cycle ──┐
                                            │  writes state.json
   HUD click        ─▶  macropad-cycle ────┤  uploads via ch57x-keyboard-tool
                                            │
   GUI save         ─▶  macropad-manager ──┤  writes profiles/*.yaml
                                            │
                                            ▼
                        ~/.config/macropad-manager/
                                            │
          HUD polls macropad-status (JSON)  │
                                            ▼
                          Plasmoid (org.flanshaw.macropadhud)
```

Consequences of this design:

- The GUI does not need to run for cycling, the HUD, or the hotkey to work.
- Any component can be replaced or scripted independently — `macropad-cycle`
  and `macropad-status` are ordinary CLIs.
- The Plasma widget is a dumb view: it polls `macropad-status` and never
  touches the config files itself.

## Components

### `macropad_manager.core`

The only module that knows about the on-disk formats. Everything else goes
through it.

- `load_state()` / `save_state()` — `state.json`, with self-healing: entries
  whose profile file has been deleted are dropped, and `active_index` is
  clamped into range.
- `load_profile()` / `save_profile()` — profile YAML, always forcing
  `model: ch57x-2`.
- `profile_bindings()` / `apply_bindings()` — map between the flat nine-slot
  view the UI uses (`button1..6`, `knob_ccw`, `knob_press`, `knob_cw`) and the
  nested `layers[0]` structure the CLI expects. Buttons are row-major:
  `button1` is the top-left key of a 3x2 pad, `button4` the bottom-left.
- `profile_labels()` / `apply_labels()` — the `labels:` extension key.
- `validate()` / `upload()` — wrap `ch57x-keyboard-tool`, capturing stdout and
  stderr together so the GUI can display failures instead of swallowing them.
- `notify()` — `notify-send`, best-effort.

### `macropad-cycle`

Stateless CLI. Computes the target index (next, explicit `--set`, or current
for `--restore`), uploads, and only then commits the new index to `state.json`
— a failed upload leaves the recorded state matching the device.

### `macropad-status`

Prints the whole picture (`active_index`, and each profile's bindings and
labels) as JSON. Exists because the HUD is written in QML, which has no YAML
parser; rather than reimplement the format there, the widget runs this CLI and
parses JSON.

### `macropad-manager` (GUI)

GTK4 + libadwaita. PyGObject ships on Arch too, so there is no extra
dependency. Editing operations save first and then act, so *Validate* and
*Upload now* always operate on exactly what is on screen. Renaming a profile
rewrites the file and repairs `state.json` order and active index in the same
step.

### HUD (Plasma 6 widget)

The original project's HUD was a GNOME Shell extension; GNOME does not allow
applications to position their own windows and Mutter lacks layer-shell, so an
extension was the only pinned-widget option. Plasma has no such constraint —
a widget is how Plasma widgets work everywhere.

- **Rendering** is a small QML scene: the active profile name, a 3x2 keycap
  grid with the friendly label over the raw binding, a one-knob column, and the
  clickable profile list.
- **Refresh** is driven by `PlasmaCore.DataSource` with the `executable` data
  engine, which runs `macropad-status` every 1.5 s and hands the JSON to the
  QML. Polling (rather than file monitors) keeps the widget a dumb view.
- **Interaction**: click a profile → `macropad-cycle --set <file>`; click the
  gear → `macropad-manager`.
- **Fonts and colors** come from `PlasmaCore.Theme`, so the widget follows the
  user's desktop theme automatically.

### `macropad-window`

A compatibility stub. The original used a D-Bus client to ask a Shell extension
to move focus, because only GNOME Shell may re-focus another window on Wayland.
KWin imposes no such restriction: its *built-in* `Walk Through Windows` /
`Overview` global shortcuts work directly, so the knob's chords are registered
against KWin actions and nothing else is needed.

### `macropad-daemon`

A `Type=oneshot` user unit running `macropad-cycle --restore` at login. The
device forgets its mapping when unplugged or on reboot, so this re-flashes
whatever `state.json` says is active. There is no long-running daemon process:
Plasma invokes the hotkey command directly, so nothing needs to sit resident.

## Key decisions

**Shelling out to `ch57x-keyboard-tool`.** The USB protocol is already
implemented and maintained upstream. Note that the installed version reads
configs from **stdin**, not a file argument, so `core._run_tool` pipes the file
in.

**Reliable window switching with a knob that can't hold modifiers.** `alt-tab`
needs Alt held down, which a knob cannot do between detents. Instead the knob
types full chords that are registered (as *extra alternative bindings*) on
KWin's native actions:

```
knob CCW   -> Ctrl+Alt+Shift+F9   ->  Walk Through Windows (Reverse)
knob press -> Ctrl+Alt+Shift+F10  ->  Overview
knob CW    -> Ctrl+Alt+Shift+F11  ->  Walk Through Windows
```

No popup is shown and each detent activates its window outright — the knob has
no "release" event to commit a selection with. Default KWin bindings
(`Alt+Tab`, `Meta+Tab`, `Meta+W`) stay intact as alternatives.

**Labels inside the profile YAML.** Storing them in a sidecar file would have
kept profiles pristine, but it doubles the number of files to keep in sync.
`ch57x-keyboard-tool validate` accepts unknown top-level keys, so `labels:`
rides along in the same file and profiles remain directly usable with the CLI.

**Plasma command shortcuts instead of raw key grabbing.** Global key grabs are
unreliable or blocked under Wayland. A command shortcut — a `.desktop` file
with `X-KDE-GlobalAccel-CommandShortcut=true` plus its `_launch` action in the
`[services]` section of `kglobalshortcutsrc` — is the Plasma-supported route,
and it means no process has to be listening.