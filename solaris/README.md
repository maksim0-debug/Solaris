# Solaris — Advanced Circadian Monitor Control

<img src="solaris/assets/icon/icon.png" width="250">

**Solaris** is a professional Windows application built with Flutter that synchronizes your monitor's brightness and color temperature with natural circadian rhythms. By calculating the precise position of the sun (elevation and azimuth) based on your geographic location, Solaris ensures a comfortable, healthy, and fully automated computing experience 24/7.

---

## 🌟 Key Features

### 🌖 Circadian Mode (Auto-Adjustment)
The core of Solaris. The app automatically calculates the sun's position relative to your horizon and adjusts monitor brightness according to a customizable curve.
- **Real-time Sun Tracking**: High-precision calculations for sunrise, sunset, solar noon, and twilight.
- **Smooth Transitions**: Brightness changes are applied gradually to avoid sudden flashes.

### 🌡️ Dynamic Color Temperature
Protect your eyes from blue light. Solaris shifts your display to warmer tones as the sun goes down.
- **Range**: Smooth transition from 6500K (Daylight) to 3300K (Warm).
- **Automation**: Fully synced with the solar cycle to maintain your natural sleep-wake rhythm.

### 🖥️ Multi-Monitor Mastery
Full control over your entire workspace.
- **DDC/CI Integration**: Direct hardware communication with monitors via system-level APIs.
- **Individual Control**: Set unique brightness offsets or manual levels for each display.
- **Unified Sync**: Adjust all monitors at once with a single click.

### 📈 Interactive Brightness Curves
Don't settle for defaults. Visualize and refine your lighting profile.
- **Bezier Curves**: Fine-tune how brightness responds to solar elevation.
- **Presets**: Swiftly switch between **Bright**, **Balanced**, **Soft**, and **Custom** profiles.
- **Real-time Preview**: See changes instantly on the luminosity graph.

### 🎮 Smart Game Mode (Exclusions)
Focus on the win without distractions.
- **Auto-Lock**: Solaris detects when you start a game and prevents brightness from shifting during intense sessions.
- **Customizable Lists**: Add specific apps to a **Whitelist** (always lock) or **Blacklist** (never lock).


### ☁️ Weather Influence
The first monitor controller that cares about the sky.
- **Cloudiness Logic**: Naturally dims brightness when it's overcast, rainy, or snowy using real-time Open-Meteo data.
- **Atmospheric UI**: Beautiful background animations for rain, snow, thunder, and clouds within the dashboard.

### ⌨️ Global Hotkeys
Control your environment without leaving your current app.
- **Custom Bindings**: Set shortcuts for Next/Prev Preset, Brightness Up/Down, and Toggling Auto-mode.
- **Stepless Control**: Fine-tune brightness in precise increments (e.g., 5% per press).

### 📍 Precise Location
- **Auto-Geolocation**: Uses GPS to determine your coordinates automatically.
- **Map Selection**: Choose your location on an interactive map if GPS is unavailable.
- **Persistence**: Remembers your preferred location across sessions.

---

## 🔐 Google Fit Integration (Advanced Mode)

Solaris supports direct synchronization with **Google Fit** to retrieve your sleep history, enabling high-precision adjustments to monitor color temperature and brightness based on your personal circadian rhythms.

> [!IMPORTANT]
> **Access & Security Policy:** Due to Google's stringent security policies regarding health data (**Restricted Scopes**), public applications are prohibited from accessing sleep history without undergoing an extensive and costly independent security audit.
>
> Consequently, the official release builds of Solaris cannot natively sync with your Google Fit account for automated adjustments.

To utilize Google Fit synchronization, you must configure a private integration by following these steps:

1. **Create a Project**: Set up a free personal project in the [Google Cloud Console](https://console.cloud.google.com/).
2. **Configure OAuth**: Define your "OAuth Consent Screen" and generate a Client ID with the `fitness.sleep.read` scope enabled.
3. **Local Setup**: Clone this repository to your local system.
4. **Environment Variables**: Navigate to the `solaris/` directory, rename `.env.example` to `.env` and insert your personal **Client ID**.
5. **Manual Build**: Compile and execute the application from source using the Flutter SDK (`flutter run -d windows`).

*By utilizing a personal API key, the application will operate as a private developer instance, bypassing the verification requirements typically imposed on public distributions.*

---

## 🚀 Technical Stack

Solaris leverages cutting-edge technologies for peak performance on Windows:

- **Framework**: [Flutter](https://flutter.dev/) (Windows Desktop)
- **State Management**: [Riverpod](https://riverpod.dev/) (using AsyncNotifiers and StreamProviders)
- **Hardware Interop**: 
    - [Dart FFI](https://dart.dev/guides/libraries/c-interop) and [win32](https://pub.dev/packages/win32) for low-level OS calls.
    - Custom MethodChannels for DDC/CI communication.
- **APIs & Services**:
    - **Google Fit API**: Health data synchronization.
    - **Open-Meteo**: High-precision weather data.
    - **Mapbox**: Location services.
- **Math engine**: Spherical trigonometry and solar algorithms (`solar_calculator`, `sunrise_sunset_calc`).

---

## 📂 Project Structure

```text
lib/
├── l10n/              # Localization (English, Russian, Ukrainian support)
├── models/            # Data structures (SolarPhase, SettingsState, PresetType)
├── providers/         # Feature-specific logic (Weather, Temperature, Lifecycle)
├── screens/           # UI Screens (Dashboard, Schedule, Settings, Location, Sleep)
├── services/          # Core mechanics (Monitor control, Sun math, Hotkeys)
├── theme/             # Premium Glassmorphism styling and palettes
└── widgets/           # Specialized UI components (SunPathPainter, Dials, Charts)
```

---

## 🛠️ Getting Started

### Requirements
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel)
- Windows 10/11
- Monitors with **DDC/CI** support (Ensure it is enabled in your monitor's OSD menu)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/maksim0-debug/Solaris.git
   ```
2. Get dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run -d windows
   ```

### Building for Release
```bash
flutter build windows
```

---

---
## 📄 Legal
- **Privacy Policy**: [Read our Privacy Policy](https://maksim0-debug.github.io/Solaris/docs)
- **License**: This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---
*Developed with ❤️ for visual health and focused productivity.*
