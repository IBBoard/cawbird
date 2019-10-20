# Cawbird 1.0.3

<a href="https://ibboard.co.uk/cawbird/#screenshots"><img src="./screenshot1.jpg" style="float:right; margin-left: 1em;" /></a>

[Cawbird](https://ibboard.co.uk/cawbird/) is a fork of the [Corebird](https://corebird.baedert.org/) Twitter client from Baedert, which became unsupported after Twitter disabled the streaming API.

Cawbird works with the new APIs and includes a few fixes and modifications that have historically been patched in to IBBoard's custom Corebird build on his personal Open Build Service account<sup>[1](#footnote1)</sup>.

## Packaging and installation

Cawbird packages are built in the [Cawbird Open Build Service project](https://build.opensuse.org/project/show/home:IBBoard:cawbird). They can be installed from the [Cawbird download page](https://software.opensuse.org//download.html?project=home%3AIBBoard%3Acawbird&package=cawbird).

<a href="https://software.opensuse.org//download.html?project=home%3AIBBoard%3Acawbird&package=cawbird" style="display: inline-block; padding: 0.5em 1em; border: 1px solid #000; border-radius: 0.5em; background: #444; color: #eee; font-weight: bold">**Install Cawbird**</a>

These packages are currently available for:

* openSUSE
  * openSUSE Tumbleweed
  * openSUSE Leap 15
  * openSUSE Leap 15.1
* Fedora
  * Fedora 29
  * Fedora 30
  * Fedora Rawhide
* CentOS
  * CentOS 7
* Ubuntu
  * Ubuntu 18.04 (Bionic Beaver)
  * Ubuntu 19.04 (Disco Dingo)
  * Ubuntu 19.10 (Eoan Ermine)
* Debian
  * Testing
  * Unstable

The following distros will be supported in future:

* Fedora 31

### Official distro repositories

The following distros currently have their own official packages:

* [Fedora (30+)](https://apps.fedoraproject.org/packages/cawbird)
  * `sudo dnf install cawbird`
* [NixOS (19.09+)](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cawbird/default.nix)
  * `nix-shell -p cawbird` for testing, `nix-env -iA cawbird` for permanent installation

## Community builds

 * [Cawbird Snap](https://snapcraft.io/cawbird) on Snapcraft.io
 * Cawbird Flatpak - [in progress](https://github.com/IBBoard/cawbird/issues/24)

### Dependencies

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
* `k` - Print tweet details to stdout (debug builds)

## Limitations

Due to [changes in the Twitter API](https://developer.twitter.com/en/docs/accounts-and-users/subscribe-account-activity/migration/introduction), Cawbird has the following limitations:

* Cawbird will update every two minutes
* Cawbird does not get notified of the following actions when performed outside Cawbird, which will be refreshed on restart:
  * Unfavourite
  * Follow/Unfollow
  * Block/Unblock
  * Mute/Unmute
  * DM deletion
  * Some list changes

All limitations are limitations imposed by Twitter and are not the fault of the Cawbird client. They have affected [all third-party client applications](http://apps-of-a-feather.com/).

## Known issues

Due to a [bug in GnuTLS](https://gitlab.com/gnutls/gnutls/issues/841#note_225110002), Cawbird is currently suffering from occasional TLS errors. These are being handled under [Cawbird bug 9](https://github.com/IBBoard/cawbird/issues/9) to handle them when they do. A future version of GnuTLS should resolve the underlying problem.

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

## Footnotes

<a name="footnote1"></a>1: [home:IBBoard:desktop](https://build.opensuse.org/project/show/home:IBBoard:desktop)