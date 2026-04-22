# ScalewayGUI

A free, open-source macOS app for browsing Scaleway Object Storage.
Credentials live in your macOS Keychain. Nothing is sent anywhere except Scaleway.

## Features

- Multiple Scaleway accounts, switch between them from the sidebar
- Browse buckets and folders with breadcrumb navigation, search, and Quick Look preview
- Drag-and-drop upload — files and full folder trees (recursive)
- Create folders, download files, download whole folders
- Regions: Paris, Amsterdam, Warsaw (custom endpoints supported)

## Install

1. Download the latest `.dmg` from the [Releases](https://github.com/sevgjan/scaleway-storage-gui/releases) page.
2. Open the DMG and drag **ScalewayGUI** into **Applications**.
3. **First launch:** right-click the app → **Open** → confirm. macOS Gatekeeper blocks unsigned apps by default; right-click-Open is the supported bypass. Subsequent launches open normally.

> This app has no Apple Developer ID signature, so it isn't notarized. That's why Gatekeeper complains once. The source is public — you can build it yourself below.

## Requirements

- macOS 14 (Sonoma) or later
- Scaleway API keys ([generate here](https://console.scaleway.com/iam/api-keys))

## Build from source

```bash
git clone git@github.com:sevgjan/scaleway-storage-gui.git
cd scaleway-storage-gui
open ScalewayGUI.xcodeproj
```

Xcode 15+. The project builds with `CODE_SIGNING_ALLOWED=NO` by default — no signing setup required.

## Disclaimer

Unofficial. Not affiliated with Scaleway.

## License

MIT
