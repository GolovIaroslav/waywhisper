# WayWhisper

Press a hotkey, speak, press it again, and the text appears in the app you were
using.

WayWhisper is a small local voice typing tool for Linux Wayland sessions. It
records your microphone with PipeWire, transcribes speech with `faster-whisper`,
copies the text through `wl-copy`, and can paste it into the focused window with
`ydotool`.

It is built around the KDE Plasma workflow on Arch Linux, but the core command
is just `waywhisper-toggle`, so other Wayland desktops can use it too if they
can bind a command to a keyboard shortcut.

## What It Does

- One shortcut starts recording.
- The same shortcut stops recording and inserts the recognized text.
- The text is also saved to `~/.cache/waywhisper/last.txt`.
- Long dictation is copied through the clipboard instead of typed key by key.
- A small audio tail is kept after stop, so the last word is less likely to be
  cut off.
- If CUDA VRAM is low, it falls back to CPU/RAM instead of crashing.
- Automatic paste can be turned off if you only want the text copied.

## Install On Arch Linux

```bash
git clone https://github.com/GolovIaroslav/waywhisper.git
cd waywhisper
./install-arch.sh
```

Preview the install first:

```bash
./install-arch.sh --dry-run
```

Install files without starting the service:

```bash
./install-arch.sh --no-start
```

## Where It Installs

The installer keeps everything in user-owned locations:

```text
~/.local/bin/waywhisper-daemon
~/.local/bin/waywhisper-toggle
~/.local/bin/waywhisper-stop
~/.local/share/waywhisper/venv/
~/.config/waywhisper/waywhisper.env
~/.config/systemd/user/waywhisper.service
~/.local/share/applications/waywhisper-toggle.desktop
~/.local/share/applications/waywhisper-stop.desktop
```

## KDE Plasma Hotkey

The important command is:

```bash
~/.local/bin/waywhisper-toggle
```

In KDE Plasma:

1. Open `System Settings`.
2. Go to `Keyboard`.
3. Open `Shortcuts`.
4. Add a new command/application shortcut.
5. Use this command:

```bash
~/.local/bin/waywhisper-toggle
```

6. Bind it to something like `Meta+H` / `Win+H`.

After that:

1. Press the hotkey.
2. Speak.
3. Press the hotkey again.
4. The text is pasted into the focused app.

To unload the model from memory before a game, run:

```bash
systemctl --user stop waywhisper
```

You can also bind this command to another shortcut:

```bash
~/.local/bin/waywhisper-stop
```

## Configuration

Edit:

```bash
~/.config/waywhisper/waywhisper.env
```

Common settings:

```bash
WAYWHISPER_MODEL=large-v3-turbo
WAYWHISPER_DEVICE=auto
WAYWHISPER_COMPUTE_TYPE=auto
WAYWHISPER_PASTE_MODE=clipboard
WAYWHISPER_EXIT_AFTER_TRANSCRIBE=false
WAYWHISPER_STOP_TAIL_SECONDS=1.0
WAYWHISPER_VAD_FILTER=false
```

Paste behavior:

```bash
# Default: copy text and paste it automatically with ydotool.
WAYWHISPER_PASTE_MODE=clipboard

# Copy only. Nothing is pasted automatically.
WAYWHISPER_PASTE_MODE=copy
```

Memory behavior:

```bash
# Keep the model loaded for fast next use.
WAYWHISPER_EXIT_AFTER_TRANSCRIBE=false

# Exit after each transcription to free VRAM/RAM.
WAYWHISPER_EXIT_AFTER_TRANSCRIBE=true
```

## GPU, AMD, And CPU

`WAYWHISPER_DEVICE=auto` is the recommended default.

On NVIDIA systems with enough free CUDA VRAM, WayWhisper uses the GPU. If CUDA
is not available, VRAM is low, or the machine uses AMD/Intel graphics, it falls
back to CPU with `int8` compute. That uses normal RAM and is slower, but it is
the most reliable default on non-NVIDIA systems.

For CPU use, a smaller model is often more comfortable:

```bash
WAYWHISPER_MODEL=small
WAYWHISPER_DEVICE=cpu
WAYWHISPER_COMPUTE_TYPE=int8
```

ROCm support for this stack depends on the CTranslate2/faster-whisper build and
the local ROCm setup, so the installer does not promise AMD GPU acceleration.
AMD GPU machines are supported through the CPU fallback.

## Useful Commands

```bash
systemctl --user status waywhisper
systemctl --user restart waywhisper
systemctl --user stop waywhisper
journalctl --user -u waywhisper -f
```

The journal shows recorded duration, transcribed duration, segment count, and
character count. This helps debug cases where a long recording produces too
little text.
