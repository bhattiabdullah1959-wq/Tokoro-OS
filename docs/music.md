# Music: the now-playing widget

Tokoro OS ships a panel widget, **Tokoro Now Playing**
(`org.tokoro.nowplaying`), that shows what is playing, lets you control it, and
lists your local music so a song is one click away.

## Adding it

Right-click the panel → **Add Widgets…** → **Tokoro Now Playing**. The compact
icon shows play/pause state; clicking opens the popup.

## How it connects to Spotify

Through **MPRIS**, the standard Linux media interface. Spotify's own Linux
client (including the Flathub package) exposes
`org.mpris.MediaPlayer2.spotify`, so the widget reads the track, artist, album
and cover art, and sends play/pause, next and previous — with no account, API
key or vendor SDK, and nothing leaving the machine. The same code drives Elisa,
Strawberry, Amberol, mpv, VLC and browser players, so the widget is not tied to
one service.

**What it deliberately does not do:** list Spotify's queue or browse Spotify's
catalogue. MPRIS exposes the current track and transport, not a queue, and
reading Spotify's library requires OAuth credentials tied to a developer app.
Shipping those in an image would mean every user shares one secret — so instead
the clickable, scrollable list is **your local library**, and Spotify is fully
controllable in the transport row above it.

## The scrollable track list

The list comes from `tokoro library`, which indexes `~/Music` (plus any folder
in `TOKORO_MUSIC_DIRS` or passed with `--dir`) and caches it at
`~/.local/share/tokoro/library.json`.

```bash
tokoro library            # what was indexed
tokoro library --refresh  # rescan after adding files
```

Clicking a track plays it in the player chosen during setup (`tokoro music
--play <file>`), so it works with Elisa, Strawberry, Amberol or Lollypop.
Scrolling over the list scrolls it; the popup is fixed-height so the list
scrolls instead of the panel growing.

## The level bars

Bars follow the audio when **cava** is installed, which is the only way to get a
real spectrum: `cava` reads the audio sink and reports per-band levels.

```bash
sudo rpm-ostree install cava      # optional, ~250 KB
systemctl reboot
```

Without cava the widget still moves — it draws a pulse derived from playback —
and it shows **live** next to the bars only when the values come from cava, so a
fake spectrum is never presented as real. `tokoro levels --available` reports
which mode you are in.

## Helper commands (test features)

```bash
tokoro now                  # what is playing, one line
tokoro now --json           # the widget's data source
tokoro now play-pause       # also: next, previous, raise, players
tokoro library --json       # the widget's track list
tokoro levels --json        # 24 bars, 0-100
```

## Honest limitations

- The widget's QML was **not rendered or linted** in the build environment (no
  Plasma session, no `qmllint`). The three helper commands behind it are covered
  by `tests/test_media.py`, including MPRIS parsing from real Spotify-shaped
  output, but the popup itself needs a real Plasma panel to confirm.
- Steering **Spotify** works through MPRIS; starting a *specific* Spotify track
  from the list is not possible without OAuth, as explained above.
- Track titles come from file names and folders, not embedded tags, so a
  carefully tagged library may show slightly different names.
