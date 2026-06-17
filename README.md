# WayWhisper

Small local voice input for Linux Wayland sessions. It records from PipeWire,
transcribes with `faster-whisper`, copies the result with `wl-copy`, and can
paste it into the focused app through `ydotool`.

The setup is aimed at Arch Linux and KDE Plasma Wayland, but the daemon itself
is not tied to Plasma. On other Wayland desktops you can bind
`waywhisper-toggle` with your desktop's shortcut settings.

## Install on Arch Linux

```bash
git clone https://github.com/your-name/waywhisper.git
cd waywhisper
./install-arch.sh
```

After the installer finishes, bind this command in KDE shortcuts:

```bash
~/.local/bin/waywhisper-toggle
```

A common binding is `Meta+H` / `Win+H`.

## Usage

Press the shortcut once to start recording. Press it again to stop. The daemon
keeps about one second of audio after the stop key, which helps avoid cutting
off the last word.

The last recognized text is also saved here:

```bash
~/.cache/waywhisper/last.txt
```

## Configuration

Edit:

```bash
~/.config/waywhisper/waywhisper.env
```

Useful options:

```bash
WAYWHISPER_MIC=@DEFAULT_SOURCE@
WAYWHISPER_MODEL=large-v3-turbo
WAYWHISPER_DEVICE=auto
WAYWHISPER_COMPUTE_TYPE=auto
WAYWHISPER_PASTE_MODE=clipboard
WAYWHISPER_STOP_TAIL_SECONDS=1.0
WAYWHISPER_VAD_FILTER=false
WAYWHISPER_CONDITION_ON_PREVIOUS_TEXT=false
```

Set `WAYWHISPER_PASTE_MODE=copy` if you only want to copy text and paste it
manually.

For long dictation, `WAYWHISPER_VAD_FILTER=false` is the safer default. Whisper
will process the whole recording in 30-second windows. If you mostly dictate
short messages in a noisy room, you can try `WAYWHISPER_VAD_FILTER=true`.

## GPU and games

With the default model, the daemon can keep several gigabytes of VRAM reserved
while it is running. Before launching a game or another GPU-heavy app, stop it:

```bash
systemctl --user stop waywhisper
```

Start it again later:

```bash
systemctl --user start waywhisper
```

If free VRAM is low, auto mode falls back to CPU or shows a desktop warning.
For a lighter setup, change the model:

```bash
WAYWHISPER_MODEL=medium
```

## Service Commands

```bash
systemctl --user status waywhisper
systemctl --user restart waywhisper
journalctl --user -u waywhisper -f
```

The daemon logs the recorded duration, transcribed duration, segment count, and
character count to the user journal. That is useful when a long recording
unexpectedly produces very little text.

## Notes

Automatic paste requires `ydotool.service`. If it is not running, WayWhisper
still copies the full text to the Wayland clipboard.
