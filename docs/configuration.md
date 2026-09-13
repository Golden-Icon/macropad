# Configuration reference

Everything lives in `~/.config/macropad-manager/`. All files are plain text and
safe to edit by hand — the GUI and HUD pick up external changes automatically.

```
~/.config/macropad-manager/
    state.json
    profiles/
        default.yaml
        media.yaml
```

---

## `state.json`

Which profiles are in the cycle, and which one is active.

```json
{
  "active_index": 0,
  "order": ["default.yaml", "media.yaml"]
}
```

| Field | Type | Meaning |
|---|---|---|
| `active_index` | integer | Index into `order` of the currently loaded profile |
| `order` | array of strings | Profile filenames, in `Ctrl+Shift+Q` cycle order |

The file is self-healing on read: filenames whose profile no longer exists are
dropped, and `active_index` is wrapped into range. A missing file is treated as
an empty state and rebuilt from whatever is in `profiles/`.

`active_index` is only written **after** a successful upload, so if flashing
fails the recorded state still matches what is actually on the device.

---

## Profile YAML

One file per profile in `profiles/`. These are ordinary `ch57x-keyboard-tool`
configs and can be used with it directly:

```bash
ch57x-keyboard-tool validate < ~/.config/macropad-manager/profiles/default.yaml
ch57x-keyboard-tool upload   < ~/.config/macropad-manager/profiles/default.yaml
```

```yaml
model: ch57x-2          # always written by the app
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
labels:                 # optional, this app only
  button1: COPY
  button2: TERMINAL
  button3: FILES
  knob_cw: VOL
```

### Slots

The GUI and `macropad-status` use nine flat slot names, which map onto the
nested structure above (buttons row-major — `button1` is top-left of a 3x2 pad):

| Slot | Position in the YAML |
|---|---|
| `button1`, `button2`, `button3` | `layers[0].buttons[0][0..2]` |
| `button4`, `button5`, `button6` | `layers[0].buttons[1][0..2]` |
| `knob_ccw` | `layers[0].knobs[0].ccw` |
| `knob_press` | `layers[0].knobs[0].press` |
| `knob_cw` | `layers[0].knobs[0].cw` |

### `labels`

Optional display names, one per slot, used by the HUD and the GUI diagram.
`ch57x-keyboard-tool` ignores the key, so adding it does not affect validation
or upload. Slots with no label fall back to showing the raw binding.

The HUD draws a single knob, so it shows the first label it finds among
`knob_cw`, `knob_press`, `knob_ccw` — label any one of them and it appears.

### Binding names

Valid binding strings come from `ch57x-keyboard-tool`:

```bash
ch57x-keyboard-tool show-keys
```

Modifiers combine with dashes (`ctrl-shift-c`). Media keys are `prev`, `play`,
`next`, `volumeup`, `volumedown`, `mute` — *not* `prevsong`/`nextsong`, which
will fail validation.

---

## HUD (Plasma widget)

The HUD is a Plasma 6 widget, so its look is governed by the desktop theme
(`PlasmaCore.Theme`) — there is no `hud.json` and nothing to tune by hand. It is
sized by Plasma like any panel/desktop widget:

- on the **desktop** it sits on the wallpaper (large, fine for a glance),
- pinned to a **panel** it floats above windows and can be small/autohidden.

It polls `macropad-status` every 1.5 s, so edits in the GUI appear within a
couple of seconds.

---

## Shortcuts written by the installer

Registration lives in `~/.local/share/applications/` and
`~/.config/kglobalshortcutsrc`:

| Component | Action | Binding |
|---|---|---|
| `[services]` → `macropad-cycle.desktop` (command shortcut) | `_launch` | `Ctrl+Shift+Q` (default) |
| `kwin` → `Walk Through Windows (Reverse)` | — | gains `Ctrl+Alt+Shift+F9` |
| `kwin` → `Overview` | — | gains `Ctrl+Alt+Shift+F10` |
| `kwin` → `Walk Through Windows` | — | gains `Ctrl+Alt+Shift+F11` |

The KWin chords are *added* to the existing shortcuts (as extra alternative
bindings), so the default `Alt+Tab` / `Meta+Tab` / `Meta+W` behaviour is
unchanged. Plasma only (re)reads these at session start, hence the "log out and
back in" step after installing.

Command shortcuts live in a `[services][<app>.desktop]` group whose `_launch`
value is the bare shortcut string — the friendly name and default come from the
`.desktop` file's `Name` / `X-KDE-Shortcuts` entries instead of the config. A
copy of the desktop file is also kept in `~/.local/share/kglobalaccel/` so the
daemon can always rediscover the app, even before `ksycoca` has indexed it.

Changes are visible in System Settings → Shortcuts.