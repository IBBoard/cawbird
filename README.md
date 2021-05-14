# Cawbird 1.4.1

<a href="https://ibboard.co.uk/cawbird/#screenshots"><img src="./screenshot1.jpg" style="float:right; margin-left: 1em;" /></a>

[Cawbird](https://ibboard.co.uk/cawbird/) is a fork of the [Corebird](https://corebird.baedert.org/) Twitter client from Baedert, which became unsupported after Twitter disabled the streaming API.

Cawbird works with the new APIs and includes a few fixes and modifications that have historically been patched in to IBBoard's custom Corebird build on his personal Open Build Service account<sup>[1](#footnote1)</sup>.

## Packaging and installation

Cawbird packages are built in the [Cawbird Open Build Service project](https://build.opensuse.org/project/show/home:IBBoard:cawbird). They can be installed from the [Cawbird download page](https://software.opensuse.org//download.html?project=home%3AIBBoard%3Acawbird&package=cawbird).

<a href="https://software.opensuse.org//download.html?project=home%3AIBBoard%3Acawbird&package=cawbird" style="display: inline-block; padding: 0.5em 1em; border: 1px solid #000; border-radius: 0.5em; background: #444; color: #eee; font-weight: bold">**Install Cawbird**</a>

These packages are currently available for:

* openSUSE
  * openSUSE Tumbleweed
  * openSUSE Leap 15.2
  * openSUSE Leap 15.3
* Fedora
  * Fedora 32
  * Fedora 33
  * Fedora 34
  * Fedora Rawhide
* CentOS
  * CentOS 7
  * CentOS 8 (including Streams)
* Ubuntu
  * Ubuntu 18.04 (Bionic Beaver)
  * Ubuntu 20.04 (Focal Fossa)
  * Ubuntu 20.10 (Groovy Gorilla)
  * Ubuntu 21.04 (Hirstue Hippo)
* Debian
  * 10 (Buster)
  * Testing
  * Unstable
  * Raspbian 10

i586, x86_64 (amd64), aarch64 (arm64) and armv7l are available on most platforms (where supported by the distro).

### Official distro repositories

The following distros currently have their own official packages:

* [Alpine Linux / postmarketOS (Edge)](https://pkgs.alpinelinux.org/packages?name=cawbird&branch=edge)
  * `sudo apk add cawbird`
* [Arch Linux](https://www.archlinux.org/packages/community/x86_64/cawbird/) ("Community")
  * `pacman -Syu cawbird`
* [Fedora (30+)](https://apps.fedoraproject.org/packages/cawbird)
  * `sudo dnf install cawbird`
* [Guix](https://guix.gnu.org/en/packages/cawbird-1.4.1/)
  * `guix install cawbird`
* [NixOS (19.09+)](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cawbird/default.nix)
  * `nix-shell -p cawbird` for testing, `nix-env -iA cawbird` for permanent installation
* [Solus](https://dev.getsol.us/source/cawbird/)
  * `sudo eopkg it cawbird`

## Community builds

* [Cawbird Snap](https://snapcraft.io/cawbird) on Snapcraft.io
* [Cawbird Flatpak](https://flathub.org/apps/details/uk.co.ibboard.cawbird) on Flathub.org
* Arch Linux (AUR):
  * [Cawbird-git](https://aur.archlinux.org/packages/cawbird-git)

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

Cawbird has also been unable to implement the following features because Twitter did not provide a way for third-party applications to get the data:

* Notification of Likes, RTs, quote tweets and any other interaction that appears in the "All" tab of twitter.com's Notifications but not in "Mentions"
  * No API is available for other notifications, only a [mentions API](https://developer.twitter.com/en/docs/tweets/timelines/api-reference/get-statuses-mentions_timeline)
* DMs to Groups
  * Twitter's API only supports one-to-one DMs
  * Twitter explicitly [closed a request for this API](https://twitterdevfeedback.uservoice.com/forums/921790-twitter-developer-labs/suggestions/37689256-allow-access-to-dm-group-conversations-via-twitter) as "not a priority"
* Polls
  * The free API does not include polls as tweet "entities"
  * Twitter doesn't even mark posts so that we can direct people to the web
* Twitter's "[Bookmarks](https://blog.twitter.com/en_us/topics/product/2018/an-easier-way-to-save-and-share-tweets.html)" system
  * No API is available
* Full threads in a single request
  * No API is available
* Replies older than seven days
  * The free search is limited to returning results from the last seven days
* All replies to a tweet
  * No API is available and the search results are not guaranteed to find all replies
* Twitter [Cards](https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/abouts-cards)
  * No API is available
  * Twitter doesn't even mark posts so that we can direct people to the web
  * This results in @TwitterDev [posting a message](https://mobile.twitter.com/TwitterDev/status/1222596295090757636) that many devs can't see!

As of July 2020, Twitter has [announced v2 of the API](https://blog.twitter.com/developer/en_us/topics/tools/2020/introducing_new_twitter_api.html) and may support some of these features. We are [looking in to this](https://github.com/IBBoard/cawbird/issues/180) as that parts of the API are made available.

## Known issues

There are no current known issues with running Cawbird.

Previously, the following issues have occurred that were outside of our control:

* Due to a [bug in GnuTLS](https://gitlab.com/gnutls/gnutls/issues/841#note_225110002), Cawbird has suffered from occasional TLS errors. This has been handled under [Cawbird bug 9](https://github.com/IBBoard/cawbird/issues/9) and GnuTLS have released a fix for the underlying problem
* Due to a [bug in GStreamer 1.16.1](https://github.com/IBBoard/cawbird/pull/42#issuecomment-539437887), Cawbird suffered from glitchy audio and video when playing media. This has now been fixed in GStreamer
* Some combination of GStreamer, GTK and the Video Acceleration API (VAAPI) on some Intel chips can [cause corruption of videos](https://github.com/IBBoard/cawbird/issues/279). This is an [old and on-going problem](https://github.com/baedert/corebird/issues/540). Removing `gstreamer-vaapi` or equivalent resolves the problem.
* "Fragment downloading has failed consecutive times" messages from GStreamer appear to be due to changes in GStreamer's `adaptivedemux` code that are [fixed in v1.18.1](https://gstreamer.freedesktop.org/releases/1.18/#1.18.2)

## Translations

  Since February 2020, there has been a [Cawbird project on Transifex](https://www.transifex.com/cawbird/cawbird/dashboard/). Users can sign up on Transifex for free to help translate Cawbird.

## Testing

Since August 2020, there has been a [Cawbird "unstable" package](https://software.opensuse.org//download.html?project=home%3AIBBoard%3Acawbird-unstable&package=cawbird-unstable) built on the Open Build Service. These packages are intended for users who can't build Cawbird from source but want to test new features.

**Do not** use the unstable release unless you are testing new features and understand the risks. *They are not intended for everyday use*. They will be updated intermittently with new features from `git master`. They may have bugs. They may not get patched. They may be behind the main release. They may break things and eat your homework.

It is recommended that you backup `~/.config/cawbird` before running Cawbird-Unstable.

## Contributing

  All contributions are welcome (artwork, design, code, just ideas, etc.) but if you're planning to
  actively change something bigger, talk to me first.

## Compiling Cawbird

### Preparation

Twitter clients need keys and secrets so that Twitter can go through the OAuth process. Cawbird used to ship
with a standard set of  but has always supported custom keys through schema settings. However, that wasn't convenient for software builds. Cawbird now supports:

a) per-user tokens and secrets (so each user uses a different "app")

b) configuration of the default token and secret at build time

What this means for developers is that you need to supply two build options with the key and the secret before the software will build. To stop them being trivially identifiable, we base64 encode them.

If you wish to build your own "micro-fork" of the application then register at [developer.twitter.com](https://developer.twitter.com/) and create an application. To base64 encode the keys you can run `echo -n "<value>" | base64`.

Reasons you may wish to micro-fork Cawbird:

* You want to package a modified version with your own patches (as IBBoard used to do with Corebird)
* You want to appear retro and use the old Corebird keys to confuse people
* You want to check whether you're getting hit by Twitter limiting *applications*
(not just users - all users of the app in aggregate) to 100,000 calls to some endpoints ([docs](https://developer.twitter.com/en/docs/twitter-api/v1/tweets/timelines/api-reference/get-statuses-mentions_timeline))

Alternatively you can continue using the default keys by using the values `VmY5dG9yRFcyWk93MzJEZmhVdEk5Y3NMOA==` and `MThCRXIxbWRESDQ2Y0podzVtVU13SGUyVGlCRXhPb3BFRHhGYlB6ZkpybG5GdXZaSjI=` respectively.

### Compiling

Cawbird uses the Meson build system rather than the more archaic autoconf/make combination. Building is as simple as:

```Bash
meson build -Dconsumer_key_base64=<your-base64-key> -Dconsumer_secret_base64=<your-base64-secret>
ninja -C build
```

If you want to test translations locally then you will also need to:

* pass `-Dlocaltextdomain=true` to meson
* run `ninja -C build cawbird-gmo` to generate the binary `.mo` translations
* run `for file in po/*.gmo; do mkdir -p "${file/.gmo}/LC_MESSAGES/"; cp $file "${file/.gmo}/LC_MESSAGES/cawbird.mo"; done` to put the `.mo` files in the expected places
* run `pushd build; ./cawbird; popd` to run Cawbird from the build directory
  * to test a different language, run `cd build; LANGUAGE=aa_BB ./cawbird` with the appropriate language code

Note that executing `build/cawbird` may result in one of the following errors:

```Bash
Settings schema 'uk.co.ibboard.cawbird' is not installed

Settings schema 'uk.co.ibboard.cawbird' does not contain a key named 'foo'
```

To fix this, use the schemas from the build directory:

```Bash
GSETTINGS_SCHEMA_DIR=build/data/ GSETTINGS_BACKEND='memory' build/cawbird
```

Cawbird installs its application icon into `/usr/share/icons/hicolor/`, so an appropriate call to `gtk-update-icon-cache` might be needed.

### Build Dependencies

* `gtk+-3.0 >= 3.22`
* `glib-2.0 >= 2.44`
* `json-glib-1.0`
* `sqlite3`
* `libsoup-2.4`
* `librest-0.7`
* `liboauth`
* `gettext >= 0.19.7`
* `vala >= 0.28` (makedep)
* `meson` (makedep)
* `gst-plugins-base-1.0` (for playbin, disable by passing `-Dvideo=false` to Meson)
* `gst-plugins-bad-1.0 >= 1.6` or `gst-plugins-good-1.0` (disable by passing `-Dvideo=false` to Meson, default enabled)
  * Requires the `element-gtksink` feature, provided by `gstreamer1.0-gtk` on Ubuntu-based systems,
    `gstreamer1-plugins-bad-free-gtk` on older RPM-based systems and `gstreamer1-plugins-good-gtk` on
    newer RPM-based systems
* `gst-libav-1.0` (disable by passing `-Dvideo=false` to Meson, default enabled)
* `gspell-1 >= 1.2` (for spellchecking, disable by passing `-Dspellcheck=false` to Meson, default enabled)

Note that the above packages are just rough estimations, the actual package names on your distribution may vary and may require additional repositories (e.g. RPMFusion in Fedora, or Packman in openSUSE)

If you pass `-Dvideo=false` to the Meson script, you don't need any gstreamer dependency but won't be able to view any videos.

## Copyright

Cawbird is released under the GPL v3 - see [COPYING](./COPYING) for more details.

The [video fallback image](data/symbolic/apps/cawbird-video-placeholder.svg) is a Creative Commons "CC BY" licensed work [by Iris Li](https://thenounproject.com/term/film-reel/20395/).

## Footnotes

<a name="footnote1"></a>1: [home:IBBoard:desktop](https://build.opensuse.org/project/show/home:IBBoard:desktop)
