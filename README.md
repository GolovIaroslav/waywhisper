# WayWhisper

Press a hotkey, speak, press it again, and the text appears in the app you were
using.

WayWhisper is local voice typing for Linux Wayland. It records from PipeWire,
transcribes with `faster-whisper`, copies the result with `wl-copy`, and can
paste it into the focused window with `ydotool`.

It is made for the simple KDE Plasma workflow: bind one command to a shortcut,
then use that shortcut to start and stop dictation.

## Install

```bash
git clone https://github.com/GolovIaroslav/waywhisper.git
cd waywhisper
./install-arch.sh
```

If you want to see what the installer will do before it touches anything, run:

```bash
./install-arch.sh --dry-run
```

If you want to install the files but not start the service yet, run:

```bash
./install-arch.sh --no-start
```

## Use It

After installing, bind this command to a KDE Plasma shortcut:

```bash
~/.local/bin/waywhisper-toggle
```

Open KDE `System Settings`, go to `Keyboard`, then `Shortcuts`, add a command
shortcut, paste `~/.local/bin/waywhisper-toggle`, and bind it to something like
`Meta+H` / `Win+H`.

Press the shortcut once to start recording. Speak normally. Press the shortcut
again to stop recording. WayWhisper transcribes what you said and pastes it into
the focused app.

The last recognized text is also saved here:

```bash
~/.cache/waywhisper/last.txt
```

To unload the model from memory before launching a game, stop the service:

```bash
systemctl --user stop waywhisper
```

You can also bind a separate shortcut to this command:

```bash
~/.local/bin/waywhisper-stop
```

The `.desktop` files are not desktop icons. They are small application entries
installed under `~/.local/share/applications` so desktop environments can expose
the commands in their launcher/shortcut tools.

## Settings

Config lives here:

```bash
~/.config/waywhisper/waywhisper.env
```

The default mode copies the recognized text and pastes it automatically:

```bash
WAYWHISPER_PASTE_MODE=clipboard
```

If automatic paste gets annoying, switch to copy-only mode:

```bash
WAYWHISPER_PASTE_MODE=copy
```

In copy-only mode WayWhisper still puts the text into the clipboard and saves it
to `~/.cache/waywhisper/last.txt`, but it does not press paste for you.

By default the model stays loaded after transcription, so the next use is
faster:

```bash
WAYWHISPER_EXIT_AFTER_TRANSCRIBE=false
```

If you prefer freeing VRAM/RAM after every dictation, change it to:

```bash
WAYWHISPER_EXIT_AFTER_TRANSCRIBE=true
```

Long dictation is safer with VAD disabled, so this is the default:

```bash
WAYWHISPER_VAD_FILTER=false
```

## GPU And CPU

The recommended default is:

```bash
WAYWHISPER_DEVICE=auto
WAYWHISPER_COMPUTE_TYPE=auto
```

On NVIDIA systems with enough free CUDA VRAM, WayWhisper uses the GPU. If CUDA
is not available, VRAM is low, or the machine uses AMD/Intel graphics, it falls
back to CPU with `int8` compute. That uses normal RAM and is slower, but it is
the reliable default for non-NVIDIA systems.

For CPU use, a smaller model is usually better:

```bash
WAYWHISPER_MODEL=small
WAYWHISPER_DEVICE=cpu
WAYWHISPER_COMPUTE_TYPE=int8
```

ROCm depends on the local CTranslate2/faster-whisper build and the local ROCm
setup. The installer does not promise AMD GPU acceleration; AMD GPU machines are
supported through CPU fallback.

## Files

The installer keeps files in user-owned paths:

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

## Commands

```bash
systemctl --user status waywhisper
systemctl --user restart waywhisper
systemctl --user stop waywhisper
journalctl --user -u waywhisper -f
```

The journal shows recorded duration, transcribed duration, segment count, and
character count. That helps debug cases where a long recording produces too
little text.
