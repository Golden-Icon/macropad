"""macropad-window: retained for compatibility; window switching is now native.

On KDE Plasma/Wayland the knob chords control window focus directly through
KWin's built-in global shortcuts, which install.sh binds to the same chords the
macropad emits (Ctrl+Alt+Shift+F9/10/11). No separate helper or D-Bus bridge is
needed, so this entry point just explains what to do instead.
"""

from __future__ import annotations

import sys

from . import core

WINDOW_ACTIONS = ["next", "prev", "overview"]


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in WINDOW_ACTIONS:
        print(f"usage: macropad-window {{{'|'.join(WINDOW_ACTIONS)}}}",
              file=sys.stderr)
        return 2
    core.notify(
        "Macropad",
        "Window switching is now handled by KWin's native shortcuts.\n"
        "Configure Ctrl+Alt+Shift+F9/F10/F11 in System Settings > Shortcuts "
        "(Walk Through Windows / Overview), then set them as the knob chords "
        "in the profile.",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())