# Troubleshooting

## The HUD does not appear

**First, check whether plasmashell sees it and its QML loads:**

```bash
journalctl --user -b | grep macropadhud
```

| Symptom | Cause and fix |
|---|---|
| No lines at all, or `Could not create window` | The widget has not been installed. Run `./install.sh` and log out/in |
| `qml: ...` errors near `PlasmaCore.DataSource` | QML syntax error — see the widget source in `~/.local/share/plasma/plasmoids/org.flanshaw.macropadhud/` |
| Lines present but nothing on screen | The widget is installed but not placed on a desktop or panel — add it |

To **add** the widget: right-click the desktop → *Add Widgets* → search for
**Macropad HUD** and add it. On the desktop it sits on the wallpaper; drop it
into a small autohide panel instead and it floats above windows.

No `hud.json` exists — fonts and colours come from the Plasma theme
(`PlasmaCore.Theme`) automatically.

## Changes to the HUD have no effect

If you edited `main.qml`, you must log out and back in (or restart plasmashell:
`kquitapp6 plasmashell && plasmashell &`). QML templates are created from a
compiled cache at load time, so editing the file on disk is not enough.

Changes to `profiles/*.yaml` need no reload — the HUD re-polls every 1.5 s.
See [development.md](development.md) for the full matrix.

## `Ctrl+Shift+Q` does nothing

1. Confirm the command shortcut is registered:

   ```bash
   kreadconfig6 --file kglobalshortcutsrc --group services --group macropad-cycle.desktop --key _launch
   ```

   It should print the shortcut as a **single value**, e.g. `Ctrl+Shift+Q`.

   > Older installers wrote a `[macropad-cycle.desktop/_launch]` group with a
   > `shortcut,default,description` triplet. Plasma loads that legacy layout as
   > a dormant component that never fires. Re-running `./install.sh` rewrites
   > the entry in the `[services]` form the daemon actually reads.

2. Confirm the `.desktop` file exists:

   ```bash
   cat ~/.local/share/applications/macropad-cycle.desktop
   ```

3. If registered but unresponsive, log out and back in — Plasma only loads new
   command shortcuts at session start.

4. Test the command directly. If this works but the hotkey does not, the
   problem is the binding, not the app:

   ```bash
   macropad-cycle
   ```

5. Another application may have claimed the shortcut. Re-run the installer with
   a different one: `./install.sh Meta+F9`.

## The knob does not switch windows

Check a profile's knob bindings first — `ccw`, `press`, and `cw` should be the
`ctrl-alt-shift-f9/f10/f11` chords (see README). Then verify that KWin knows
about them:

```bash
for a in "Walk Through Windows (Reverse)" "Walk Through Windows" "Overview"; do
  echo "=== $a ==="
  kreadconfig6 --file ~/.config/kglobalshortcutsrc --group kwin --key "$a"
done
```

Each line's active field (before the first `,`) must include the chord. If
the chords are missing, the installer has not run yet, or a fresh session is
needed (KWin only reads `kglobalshortcutsrc` at startup).

- **Some windows are skipped** — only windows on the *current workspace* are
  in the walk, and anything set to skip the taskbar is excluded.

## Upload fails

Run it in a terminal to see the error:

```bash
macropad-cycle
```

| Error | Fix |
|---|---|
| Permission / access denied | Missing udev rule — see [README](../README.md#device-permissions), then replug |
| `device not found` / no device | `lsusb -d 1189:8890` to confirm it is connected |
| `ch57x-keyboard-tool not found in PATH` | Install the AUR package |
| `error MapRes at: …` | An invalid binding name — check `ch57x-keyboard-tool show-keys` |

Note that a failed upload deliberately leaves `active_index` unchanged, so the
recorded state keeps matching the device.

## Validation fails on media keys

Use `prev`, `play`, `next` — not `prevsong`, `playpause` or `nextsong`. Full
list:

```bash
ch57x-keyboard-tool show-keys
```

## The GUI will not start

```bash
macropad-manager
```

`ModuleNotFoundError: No module named 'gi'` means the package was installed
without access to system PyGObject. Reinstall with:

```bash
pipx install --force --system-site-packages .
```

## The device forgets its mapping after reboot

That is expected — the mapping is volatile. The `macropad-daemon` user service
re-flashes the active profile at login:

```bash
systemctl --user status macropad-daemon.service
systemctl --user enable --now macropad-daemon.service
```

If it runs before the device is ready, just press `Ctrl+Shift+Q` twice to cycle
back around, or run `macropad-cycle --restore`.

## Profiles disappeared from the cycle

`state.json` drops entries whose file no longer exists. If you renamed or moved
a profile outside the GUI, re-add it by editing `order` in
`~/.config/macropad-manager/state.json`, or delete the file entirely to have it
rebuilt from the contents of `profiles/`.