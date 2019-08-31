# Cawbird 1.0.1

Cawbird is a fork of the [Corebird Twitter client from Baedert](https://corebird.baedert.org/), which became unsupported after Twitter disabled the streaming API.

Cawbird works with the new APIs and includes a few fixes and modifications that have historically been patched in to IBBoard's custom Corebird build on
[his personal Open Build Service account](https://build.opensuse.org/project/show/home:IBBoard:desktop).

## Packaging and installation

Official packages are built in the [Cawbird Open Build Service project](https://build.opensuse.org/project/show/home:IBBoard:cawbird). They can be installed from the [Cawbird download page](https://software.opensuse.org//download.html?project=home%3AIBBoard%3Acawbird&package=cawbird) (Note: CentOS is listed under Fedora)

**[Install Cawbird](https://software.opensuse.org//download.html?project=home%3AIBBoard%3Acawbird&package=cawbird)**

Packages currently exist for:

* openSUSE
  * openSUSE Tumbleweed
  * openSUSE Leap 15
  * openSUSE Leap 15.1
* Fedora
  * Fedora 29
  * Fedora 30
* CentOS
  * CentOS 7
* Ubuntu
  * Ubuntu 18.04 (Bionic Beaver)
  * Ubuntu 19.04 (Disco Dingo)

The following distros should be supported in future:

* Ubuntu
  * Ubuntu 19.10 (Eoan Ermine)

Twitter uses specific codecs for videos. These are provided by `libav` and are not included in the core repositories of many distros. The following additional repositories are known to include the required libraries:

* openSUSE - [Packman](http://packman.links2linux.org/)
* Fedora/CentOS - [RPMFusion](https://rpmfusion.org/)
* Ubuntu - Universe

## Shortcuts

| Key                | Description                                                                                                                                 |
| :-----:            | :-----------                                                                                                                                |
| `Ctrl + t`         | Compose Tweet                                                                                                                               |
| `Back`             | Go one page back (this can be triggered via the back button on the keyboard, the back thumb button on the mouse or  `Alt + Left`)           |
| `Forward`          | Go one page forward (this can be triggered via the forward button on the keyboard, the forward thumb button on the mouse or  `Alt + Right`) |
| `Alt + num`        | Go to page `num` (between 1 and 7 at the moment)                                                                                            |
| `Ctrl + Shift + s` | Show/Hide topbar                                                                                                                            |
| `Ctrl + p`         | Show account settings                                                                                                                       |
| `Ctrl + k`         | Show account list                                                                                                                           |
| `Ctrl + Shift + p` | Show application settings                                                                                                                   |

When a tweet is focused (via keynav):

* `r`  - reply
* `tt` - retweet
* `f`  - favorite
* `q`  - quote
* `dd` - delete
* `Return` - Show tweet details

## Limitations

Due to [changes in the Twitter API](https://developer.twitter.com/en/docs/accounts-and-users/subscribe-account-activity/migration/introduction), Cawbird has the following limitations:

* Cawbird will update every two minutes
* Cawbird does not get notified of the following, which will be refreshed on restart:
  * Unfavourite
  * Follow/Unfollow
  * Block/Unblock
  * Mute/Unmute
  * DM deletion
  * Some list changes

All limitations are limitations imposed by Twitter and are not the fault of the Cawbird client.

## Translations

  Since February 2014, there has been a [Corebird project on Transifex](https://www.transifex.com/projects/p/corebird). Cawbird is currently still using those translations.

## Contributing

  All contributions are welcome (artwork, design, code, just ideas, etc.) but if you're planning to
  actively change something bigger, talk to me first.

## Compiling Cawbird

### Compiling

Cawbird uses the Meson build system rather than the more archaic autoconf/make combination. Building is as simple as:

```Bash
meson build
ninja -C build
```

Cawbird installs its application icon into `/usr/share/icons/hicolor/`, so an appropriate call to `gtk-update-icon-cache` might be needed.

### Dependencies

* `gtk+-3.0 >= 3.20`
* `glib-2.0 >= 2.44`
* `json-glib-1.0`
* `sqlite3`
* `libsoup-2.4`
* `gettext >= 0.19.7`
* `vala >= 0.28` (makedep)
* `automake >= 1.14` (makedep)
* `gst-plugins-base-1.0` (for playbin, disable via --disable-video)
* `gst-plugins-bad-1.0 >= 1.6` (disable via --disable-video, default enabled)
* `gst-plugins-good-1.0` (disable via --disable-video, default enabled)
* `gst-libav-1.0` (disable via --disable-video, default enabled)
* `gspell-1 >= 1.2` (for spellchecking, disable via --disable-spellcheck, default enabled)

Note that the above packages are just rough estimations, the actual package names on your distribution may vary and may require additional repositories (e.g. RPMFusion in Fedora, or Packman in openSUSE)

If you pass `--disable-video` to the configure script, you don't need any gstreamer dependency but won't be able to view any videos.
