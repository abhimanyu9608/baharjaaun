# Bahar Jaaun? 🌫️

> **"Should I go out today?"** — Delhi's daily air quality, told straight in Hinglish.

A Flutter web app that fetches live PM2.5 data from OpenWeather, converts it to India's CPCB AQI scale (0–500), and gives you an animated scene + Hinglish verdict so you know whether to step outside.

**Live:** [cipherabhi.com](https://cipherabhi.com)

---

## Features

- **Live India AQI** — PM2.5 from OpenWeather Air Pollution API → CPCB linear interpolation (not OWM's coarse 1–5 scale)
- **Animated Delhi scene** — spinning sun, sliding cloud, smog/rain particles, bobbing mascot that sweats, coughs, or wears a mask based on AQI
- **Hinglish verdicts** — randomised Hinglish one-liners per category, shareable via WhatsApp
- **"Kya karna chahiye?"** — activity tips (go jogging / wear N95 / don't step out) per AQI category
- **AQI gradient bar** — visual 0–500 scale with live position marker, PM2.5 µg/m³ and temperature
- **Preview dots** — tap any of the 6 AQI category dots to preview what that level looks, feels, and reads like
- **Rain toggle** — switch baarish on/off, mascot reacts (sweat suppressed in rain)
- **Desktop ambient** — floating orbs and faded watermark text fill the sides on wide screens
- **45-minute cache** — SharedPreferences cache keyed by rounded lat/lon; no duplicate API calls
- **AdSense ready** — placeholder slot in layout, ready for ad unit

---

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.44 (web-only) |
| AQI data | OpenWeather Air Pollution API (`/data/2.5/air_pollution`) |
| Weather | OpenWeather Current Weather API (`/data/2.5/weather`) |
| AQI standard | India CPCB (Central Pollution Control Board) — 6 categories, 0–500 |
| Fonts | Baloo 2 · Fredoka · JetBrains Mono (via `google_fonts`) |
| Location | `geolocator` with 8s hard timeout → Delhi fallback |
| Cache | `shared_preferences` — 45 min TTL |
| HTTP | `http` package |
| Links | `url_launcher` |

---

## AQI Categories (CPCB)

| Range | Category | What it means |
|---|---|---|
| 0–50 | Good | Step out, breathe deep |
| 51–100 | Satisfactory | Fine for most people |
| 101–200 | Moderate | Sensitive groups: be careful |
| 201–300 | Poor | Mask up, avoid outdoors |
| 301–400 | Very Poor | Stay inside |
| 401–500 | Severe | Emergency level — don't go out |

---

## Local Setup

```bash
# Prerequisites: Flutter 3.x with web support
flutter doctor

# Clone
git clone https://github.com/abhimanyu9608/baharjaaun.git
cd baharjaaun

# Install dependencies
flutter pub get

# Run in Chrome
flutter run -d chrome

# Build for production
flutter build web --release --base-href /
```

The OpenWeather API key is in `lib/services/aqi_service.dart`. Replace with your own key from [openweathermap.org](https://openweathermap.org/api).

---

## Project Structure

```
lib/
├── data/
│   └── verdicts.dart        # Hinglish verdict lines + activity tips per category
├── models/
│   └── aqi_category.dart    # AqiCategory, pm25ToIndiaAqi(), CPCB breakpoints
├── screens/
│   ├── home_screen.dart     # Main screen: scene, AQI block, cards, preview dots
│   ├── about_screen.dart
│   ├── contact_screen.dart
│   ├── privacy_screen.dart
│   └── terms_screen.dart
├── services/
│   ├── aqi_service.dart     # OpenWeather fetch + 45-min SharedPreferences cache
│   └── location_service.dart # Geolocator with 8s timeout + Delhi fallback
├── theme/
│   └── app_theme.dart       # Colors, Google Fonts helpers
├── widgets/
│   ├── mascot.dart          # Animated character (bob, blink, sweat, cough, mask)
│   ├── sky_particles.dart   # Smog particles + rain streaks
│   ├── side_cast.dart       # Auto-rickshaw, chai glass, pigeon
│   ├── verdict_card.dart    # Fade-transition verdict card
│   ├── app_footer.dart      # Footer with nav links
│   └── info_scaffold.dart   # Shared scaffold for About/Contact/Privacy/Terms
└── main.dart                # Named routes, slide-up transitions
```

---

## Data & Disclaimers

- Air quality data: [OpenWeatherMap](https://openweathermap.org/) (updates hourly)
- AQI standard: [CPCB India](https://cpcb.nic.in/)
- This app is **not medical advice**. Do not rely solely on this for health decisions.

---

## License

MIT © 2026 [Abhimanyu Kumar](https://cipherabhi.com)
