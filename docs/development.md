# Development

## Layout

```
src/macropad_manager/       Python package (core, gui, cycle, status, window)
plasmoid/                   Plasma 6 HUD widget source (QML)
profiles/                   starter profiles install.sh seeds on first run
systemd/                    user unit
install.sh                  installs all of the above
```

`install.sh` is idempotent — re-run it after any change to reinstall the
package, refresh the widget files, and re-apply the global shortcuts.

## Working on the Python side

```bash
pipx install --force --system-site-packages .     # reinstall after edits
python3 -m py_compile src/macropad_manager/*.py   # quick syntax check
```

`--system-site-packages` is required: the GUI imports PyGObject, which is
installed system-wide on Arch/CachyOS and cannot be pip-installed into the pipx
venv.

Run without installing:

```bash
PYTHONPATH=src python3 -m macropad_manager.gui
PYTHONPATH=src python3 -m macropad_manager.status
```

Changes to Python take effect on the next run of the command — no session
restart, and the HUD picks up new `macropad-status` output automatically.

## Working on the widget

```bash
# syntax/lint check (unresolved PlasmaCore.* warnings are normal outside the
# shell - those types are registered by plasmashell at runtime)
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml plasmoid/org.flanshaw.macropadhud/contents/ui/main.qml

# install the edited files
install -Dm644 plasmoid/org.flanshaw.macropadhud/contents/ui/main.qml \
    ~/.local/share/plasma/plasmoids/org.flanshaw.macropadhud/contents/ui/main.qml
```

### Reloading — read this before debugging a change that "did nothing"

| What changed | What is needed |
|---|---|
| Profiles, bindings, labels | Nothing. The HUD re-polls `macropad-status` every 1.5 s |
| Python code | Reinstall (`pipx install --force ...`); next invocation uses it |
| **`main.qml` or `metadata.json`** | **Restart plasmashell** (`kquitapp6 plasmashell` then `plasmashell &`, or log out and back in) |

QML changes to an already-running plasmashell are not picked up: the widget's
templates are created from the compiled QML cache at load time. The same is why
a brand-new plasmoid is only listed in *Add Widgets* after a session restart.

### Checking which build is live

`metadata.json`'s `version` (bumped alongside `pyproject.toml`) is what the
widget browser shows. If a behaviour looks stale, confirm the installed copy
under `~/.local/share/plasma/plasmoids/org.flanshaw.macropadhud/` matches the
repo — the pipx package and the widget are independent installs.

Runtime errors from the widget land in the plasmashell journal:

```bash
journalctl --user -b | grep plasmashell
```

## Testing against the device

```bash
macropad-status | python3 -m json.tool     # what the HUD sees
macropad-cycle --set media                 # flash a specific profile
ch57x-keyboard-tool validate < ~/.config/macropad-manager/profiles/media.yaml
```

`validate` needs no hardware; `upload` needs the macropad plugged in and the
udev rule in place (AUR `ch57x-keyboard-tool` ships it, or see the README).

## Gotchas worth knowing

- The installed `ch57x-keyboard-tool` reads configs from **stdin**, not a
  filename argument. `core._run_tool` pipes the file in.
- Media keys are `prev` / `play` / `next`. `prevsong` and friends fail
  validation with a `MapRes` error.
- The HUD's `PlasmaCore.DataSource` `executable` engine runs its command through
  a shell (`KProcess::setShellCommand`), which is why `~/.local/bin/...`
  tilde paths work. Keep commands simple shell invocations.
- The knob cannot hold a modifier between detents, so `alt-tab`-style shortcuts
  never "stick". That is why the knob types full chords handled by KWin's
  built-in `Walk Through Windows` / `Overview` actions instead.
- Plasma command shortcuts are wired as a `.desktop` file
  (`X-KDE-GlobalAccel-CommandShortcut=true`) plus a `_launch` action under
  `[services][<app>.desktop]` in `kglobalshortcutsrc`, with the bare shortcut
  string as its value. The action key is literally named `_launch`.