# Content Creator

Local-first content calendar for creators. Plan captions, images, tags, and cover art on a visual month grid—without a server or account.

**Product page:** [voltislabs.com/product-content-creator](https://voltislabs.com/product-content-creator)

## Features

- Month grid with cover thumbnails per day
- Per-day captions, tags, multiple images, and accessibility alt text
- Local JSON + image storage (offline, no backend)
- Windows desktop and Android
- Dark mode, resizable grid, stay-on-top window (desktop)

## Development

Requires [Flutter](https://docs.flutter.dev/) 3.11+.

```bash
flutter pub get
flutter run -d windows   # or android, chrome
```

### Windows reinstall (installer)

```powershell
.\scripts\reinstall_windows.ps1
```

Builds the app, creates `ContentCalendarSetup.exe` in Downloads, and installs silently.

## License

Copyright Voltis Labs. See repository license when published.
