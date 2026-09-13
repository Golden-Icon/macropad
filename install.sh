#!/usr/bin/env bash
# Install macropad-manager on Arch / CachyOS + KDE Plasma (Wayland or X11).
#
#   ./install.sh                    # default: Ctrl+Shift+Q cycles profiles
#   ./install.sh Meta+F9            # pick a different hotkey
#
# Sets up: the pipx package, a systemd user unit, the Plasma HUD plasmoid,
# and KDE global shortcuts (Ctrl+Shift+Q to cycle, knob chords for window
# switching via KWin). Shortcuts made by hand in kglobalshortcutsrc take effect
# at the next Plasma login, so the script ends by telling you to log out and
# back in - the same deal the original GNOME version had with its Shell
# extension.
set -euo pipefail
cd "$(dirname "$0")"

# --- knob chords: these are the key combinations the macropad emits. --------
# They must match the ccw/press/cw bindings in the window-switching profile.
CHORD_PREV="${MACROPAD_CHORD_PREV:-Ctrl+Alt+Shift+F9}"
CHORD_OVERVIEW="${MACROPAD_CHORD_OVERVIEW:-Ctrl+Alt+Shift+F10}"
CHORD_NEXT="${MACROPAD_CHORD_NEXT:-Ctrl+Alt+Shift+F11}"

# --- helpers ----------------------------------------------------------------

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }
rc() { # kglobalshortcutsrc <group> <key> <value>
    kwriteconfig6 --file "$HOME/.config/kglobalshortcutsrc" \
        --group "$1" --key "$2" "$3"
}

# Add an extra chord on top of an existing KWin shortcut, preserving its
# current bindings and defaults. The value format is
#   <active shortcuts>\t<...>,<defaults>,<friendly name>
add_kwin_chord() {
    local action="$1" chord="$2" current active defaults
    current=$(kreadconfig6 --file "$HOME/.config/kglobalshortcutsrc" \
        --group kwin --key "$action" 2>/dev/null || true)
    if [ -n "$current" ]; then
        active=${current%%,*}
        defaults=${current#*,}
    else
        # Seeded from the stock Plasma 6 defaults (several KWin actions only
        # get written once they are customised).
        case "$action" in
            "Walk Through Windows")          active=$'Alt+Tab\tMeta+Tab' ; defaults=$'Alt+Tab\tMeta+Tab,Walk Through Windows' ;;
            "Walk Through Windows (Reverse)") active=$'Alt+Shift+Tab\tMeta+Shift+Tab' ; defaults=$'Alt+Shift+Tab\tMeta+Shift+Tab,Walk Through Windows (Reverse)' ;;
            "Overview")                      active='Meta+W' ; defaults='Meta+W,Toggle Overview' ;;
            *) warn "unsupported KWin action: $action" ; return ;;
        esac
    fi
    # only add if not already present
    case "$active" in
        *"$chord"*) ;;
        *) rc kwin "$action" "$active"$'\t'"$chord,$defaults" ;;
    esac
}

normalize_hotkey() {
    # Accept GNOME-style (<Control><Shift>q / <Super>q) or KDE-style
    # (Ctrl+Shift+Q / Meta+Q) hotkeys and turn them into a Qt sequence,
    # uppercasing the final key (Qt wants Ctrl+Shift+Q, not Ctrl+Shift+q).
    local h="$1"
    h="${h//<Control>/Ctrl+}"
    h="${h//<Shift>/Shift+}"
    h="${h//<Alt>/Alt+}"
    h="${h//<Win>/Meta+}"
    h="${h//<Super>/Meta+}"
    h="${h//<>/}"
    h="${h//>/}"
    local base="" key=""
    if [[ "$h" == *+* ]]; then
        base="${h%+*}"
        key="${h##*+}"
        printf '%s+%s' "$base" "${key^^}"
    else
        printf '%s' "${h^^}"
    fi
}

# --- 0. deps ----------------------------------------------------------------

say "Checking dependencies..."
PKGS=(python-yaml python-gobject gtk4 libadwaita python-pipx qt6-tools plasma-workspace)
missing=()
for p in "${PKGS[@]}"; do
    pacman -Q "$p" &>/dev/null || missing+=("$p")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "    Installing missing packages: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
fi

command -v ch57x-keyboard-tool >/dev/null ||
    warn "ch57x-keyboard-tool not found in PATH - uploads will fail."

# --- 1. device permissions ---------------------------------------------------

UDEV_RULE=/etc/udev/rules.d/99-ch57x-macropad.rules
if [ ! -e "$UDEV_RULE" ] && \
   ! ls /usr/lib/udev/rules.d/50-ch57x-keyboard.rules &>/dev/null; then
    echo "    Installing udev rule for the macropad (needs root)..."
    echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1189", ATTR{idProduct}=="8890", MODE="0666"' \
        | sudo tee "$UDEV_RULE" >/dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo "    Replug the macropad afterwards if uploads still fail."
fi

# --- 2. the Python package ---------------------------------------------------

say "Installing package with pipx..."
if ! command -v macropad-cycle >/dev/null; then
    pipx install --force --system-site-packages .
fi

# --- 3. systemd user unit (re-flash active profile at login) ----------------

say "Installing systemd user unit..."
install -Dm644 systemd/macropad-daemon.service \
    "$HOME/.config/systemd/user/macropad-daemon.service"
systemctl --user daemon-reload
systemctl --user enable --now macropad-daemon.service || true

# --- 4. Plasma HUD plasmoid --------------------------------------------------

say "Installing Plasma HUD plasmoid..."
UUID=org.flanshaw.macropadhud
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/$UUID"
rm -rf "$PLASMOID_DIR"
mkdir -p "$PLASMOID_DIR"
cp -r "plasmoid/$UUID/." "$PLASMOID_DIR/"

# --- 5. seed default profiles on first run ----------------------------------

say "Seeding default profiles (default.yaml, media.yaml)..."
CFG_DIR="$HOME/.config/macropad-manager"
if ! ls "$CFG_DIR/profiles/"*.yaml &>/dev/null; then
    mkdir -p "$CFG_DIR/profiles"
    cp profiles/default.yaml profiles/media.yaml "$CFG_DIR/profiles/"
fi

# --- 6. global shortcuts ------------------------------------------------------

say "Registering KDE global shortcuts..."
mkdir -p "$HOME/.local/share/applications"

# GUI launcher entry (shows up in the app menu)
cat > "$HOME/.local/share/applications/macropad-manager.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Macropad Manager
GenericName=Macropad profile editor
Comment=Edit, validate and upload CH57x macropad profiles
Exec=$HOME/.local/bin/macropad-manager
Icon=input-keyboard
Terminal=false
Categories=Utility;
StartupNotify=true
EOF

# Ctrl+Shift+Q -> macropad-cycle (a command shortcut, like System Settings'
# "Add New -> Command or Script": a .desktop file + _launch action).
HOTKEY_ARG="${1:-<Control><Shift>q}"
HOTKEY="$(normalize_hotkey "$HOTKEY_ARG")"
cat > "$HOME/.local/share/applications/macropad-cycle.desktop" <<EOF
[Desktop Entry]
Name=Macropad Cycle
Comment=Cycle the macropad to the next profile
Exec=$HOME/.local/bin/macropad-cycle
Icon=input-keyboard
Terminal=false
Type=Application
Categories=Utility;
NoDisplay=true
X-KDE-GlobalAccel-CommandShortcut=true
EOF
rc macropad-cycle.desktop _k_friendly_name "Macropad Cycle"
rc macropad-cycle.desktop/_launch _swapped false
rc macropad-cycle.desktop/_launch _triggered true
rc macropad-cycle.desktop/_launch _launch "$HOTKEY,$HOTKEY,Macropad Cycle"

# knob chords -> KWin's native walk-through / overview
add_kwin_chord "Walk Through Windows (Reverse)" "$CHORD_PREV"
add_kwin_chord "Overview" "$CHORD_OVERVIEW"
add_kwin_chord "Walk Through Windows" "$CHORD_NEXT"

# make the GUI launcher appear in the app menu right away (no re-login needed)
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 &>/dev/null || true

# --- done ---------------------------------------------------------------------

say "Done. Press $HOTKEY to cycle profiles; run 'macropad-manager' for the GUI."
echo
echo "  Last step - Log out and back in so Plasma loads:"
echo "    * the new $HOTKEY shortcut and the knob chords, and"
echo "    * the Macropad HUD widget."
echo
echo "  Then add the HUD: right-click the desktop -> Add Widgets -> Macropad HUD."
echo "  (On a desktop it sits on the wallpaper; add it to a panel to float"
echo "  above windows, e.g. a small autohide panel at a screen corner.)"
echo
echo "  To set up the knob window-switching profile, open macropad-manager and"
echo "  set a profile's dial as: ccw=$CHORD_PREV press=$CHORD_OVERVIEW cw=$CHORD_NEXT"