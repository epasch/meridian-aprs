# Future Features

Ideas and enhancements beyond the current milestone scope. Not committed to any release.

---

## Messaging

- **Group / bulletin messages** — APRS bulletin (`BLN`) and announcement (`BLN0`–`BLN9`) support; display in a separate Bulletins tab
- **Message search / archive** — local SQLite persistence of message history; search by callsign or keyword
- **Background notifications** — platform push notification (or persistent service on Android) for incoming messages while the app is in the background
- **Threaded replies** — link messages to a conversation with reply quoting, like a basic chat

---

## Beaconing

- **SmartBeaconing map overlay** — show the beacon path on the map with breadcrumb dots, fading with age
- **Altitude in position packets** — include altitude in the position comment when available from GPS
- **Compressed position encoding** — APRS compressed format for shorter packets on RF
- **Object / item TX** — create and transmit APRS objects and items (weather stations, repeaters, nets)

---

## Connection & Transport

- **Passcode secure storage** — migrate APRS-IS passcode from SharedPreferences to platform keychain / keystore
- **TCP KISS TNC** — TCP KISS transport (e.g., Direwolf running on a network host)
- **Soundcard TNC** — integrate a pure-Dart or platform-native AFSK modem for RF TX/RX without dedicated hardware
- **APRS-IS server filter configuration** — user-configurable `#filter` parameter (range, callsign, type)
- **Multi-server support** — failover between APRS-IS tier-2 servers

---

## Map & Stations

- **Cluster markers** — group overlapping stations into a count badge at low zoom levels
- **Track history** — show station movement track (breadcrumbs) on map for a configurable duration
- **Object / item display** — render APRS objects and items with their own symbols and info sheets
- **Weather overlays** — display weather station data (WX) on map with colour-coded temperature / wind
- **Offline tiles** — cache map tiles for offline use (MBTiles or similar)

---

## Platform & Polish

- **iPad multi-window** — support split-screen and Slide Over on iPad
- **macOS menu bar** — native menu bar integration for connection management
- **Keyboard shortcuts** — compose, send, beacon actions via keyboard on desktop
- **Accessibility** — screen reader labels, sufficient contrast ratios, dynamic type support
- **Localisation** — i18n framework; initial target: EN, DE, JA
