# Privacy Policy for Solaris

Last Updated: July 24, 2026

This Privacy Policy describes how Solaris ("we," "us," or "our") collects, uses, and protects your information when you use our desktop application (the "App").

## 1. Information We Collect

### A. Sleep Data (Google Fit API & Local Sleep API)

To enable automated, circadian-aligned display control, Solaris may process sleep data from two optional sources based on your configuration:
1. **Google Fit API**: Synchronizes historical sleep duration, start/end timestamps, and sleep sessions from your connected Google account.
2. **Local Sleep API**: Receives local sleep session payloads and real-time sleep/awake status pushed directly by third-party tracking applications, smart alarms, or custom scripts running on your local device or network via Solaris’s embedded API endpoints (`POST /api/v1/control`, `POST /api/sleep/sessions`, `POST /api/sleep/status`).

We do NOT use sleep data for medical diagnostics, health recommendations, or fitness tracking insights. Sleep data is processed and analyzed strictly locally on your device to calibrate monitor brightness, color temperature curves, and Wind Down transitions according to your real sleep debt and circadian sleep-wake schedule.

### B. Location Data

To accurately calculate sunrise, sunset, and solar phases for your specific geographic location and timezone, the App may collect or process your approximate or precise location data. This localized data is required solely for the App’s core functionality: driving automated real-time monitor brightness and color temperature adjustments and fetching relevant local weather data. Location calculations occur locally on your device.

### C. Device Information

We may collect technical information about your device, such as your operating system version and internet connectivity status, to ensure the App functions correctly.

## 2. How We Use Your Information

We use the information collected solely to provide the core functionality of the App:

- **Sleep Data (Google Fit & Local Sleep API)**: We process and analyze your sleep session history and real-time sleep status specifically to construct an accurate, dynamic circadian sleep regime. This localized data analysis is essential for the App’s core functionality: the automated synchronization of your monitor’s brightness and color temperature with your physiological circadian rhythm and sleep debt. By mapping display transitions to your actual sleep-wake patterns, Solaris provides a personalized, health-centric viewing experience that supports natural circadian balance and ocular comfort.
- **Location Data**: Essential for the App's primary purpose—automatically synchronizing your monitor's brightness and color temperature with the real-time solar path and ambient weather at your location. Coordinates are used locally to compute solar elevation/azimuth and to query weather APIs for cloud coverage compensation.

**We do NOT:**

- Share your sleep data or location data with third parties for advertising or marketing.
- Use your sleep data for any purpose other than providing and improving the core features of the App explicitly disclosed to you (i.e., the automated regulation of monitor settings based on your sleep patterns).
- Store your raw Google Fit or local sleep data on our external servers; data is cached locally on your device for performance and offline access.

## 3. Google API Services User Data Policy

Solaris’s use and transfer to any other app of information received from Google APIs will adhere to the **[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)**, including the **Limited Use** requirements.

We comply with the following principles:

1. **Limited Use**: We only use Google Fit data to provide or improve the user experience or features that are prominent in the App's interface.
2. **Privacy and Security**: We implement industry-standard security measures to protect your data.
3. **Transparency**: We provide clear and accurate information about the data we access and how we use it.

## 4. Data Storage and Security

- **Local Storage**: Your Google Fit data and application settings are stored locally on your device in your user profile's application support directory (`%APPDATA%\Solaris Team\solaris`). We use secure storage mechanisms to prevent unauthorized access.
- **Limited Third-Party Services**: We do not sell or trade your personal data. However:
  - Your approximate location may be sent securely and anonymously to third-party weather APIs solely to fetch current weather conditions necessary for the App's core functionality.
  - Your coordinates are sent securely via HTTPS to Mapbox to render the interactive map and resolve your city name on the Location screen.

## 5. Your Rights and Choices

- **Access and Control**: You can connect or disconnect your Google Fit account at any time through the App's settings.
- **Data Management**: When you disconnect Google Fit or stop using location features, previously cached data remains locally within your user account's application support directory (`%APPDATA%\Solaris Team\solaris`) on your Windows device. Because Solaris is distributed as a portable desktop application, local settings, credentials, and cached data persist in your user profile folder (`%APPDATA%\Solaris Team\solaris`) and can be manually inspected, cleared, or deleted by you at any time. You can also revoke Google API access via your Google Account security settings.

## 6. Children's Privacy

The App is not intended for use by children under the age of 13. We do not knowingly collect personal information from children.

## 7. Changes to This Policy

We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy within the App.

## 8. Disclaimer and Limitation of Liability

Solaris is provided strictly on an **"AS IS"** and **"AS AVAILABLE"** basis without any warranties, express or implied, including but not limited to implied warranties of merchantability, fitness for a particular purpose, hardware compatibility, or non-infringement.

### A. General Limitation of Liability

Under no circumstances shall the developer, authors, or contributors be held liable for any direct, indirect, incidental, special, consequential, punitive, or exemplary damages (including, without limitation, loss of profits, business interruption, loss of data, system compromise, or hardware degradation) arising out of or in connection with your use or inability to use the App.

### B. Embedded Control API, WebSocket & Local Server Security

Solaris includes an optional embedded Control API (REST) and WebSocket streaming server ("API Services"). By enabling API Services, LAN network access mode, or configuring Windows Defender Firewall rules through the App, you explicitly acknowledge and agree that:

- **User Responsibility for Network Security**: You assume sole and absolute responsibility for securing your local network environment, device, router, and access endpoints.
- **Token Safeguarding & Public Network Risks**: You are exclusively responsible for preserving the confidentiality of your generated API Access Tokens (`apiAccessToken`). The developer is not liable for token compromise, unauthorized API access, packet interception, or data leakage resulting from your use of API Services over unsecured, unencrypted, or public Wi-Fi networks.
- **Windows Firewall & LAN Binding**: Enabling LAN access mode triggers modifications to Windows Defender Firewall rules (`WindowsFirewallService`). You acknowledge that opening local network ports carries inherent security risks and agree that the developer bears no liability for network intrusions, port scanning, or unauthorized third-party connections to your device.
- **Outbound Webhooks**: You are solely responsible for all external URLs, secret keys, and payload delivery destinations configured within the Outbound Webhooks Engine. The developer is not liable for third-party HTTP endpoint vulnerabilities, data exposure on external servers, or unintended automation triggers.

### C. Hardware Interaction & Physical Display Disclaimer

Solaris communicates directly with display hardware via Win32 GDI Gamma Ramps, DDC/CI protocols, and I2C buses:

- **Hardware & Firmware Variations**: Display hardware, DDC/CI microcontrollers, graphics card drivers, and monitor firmware vary significantly. The developer does not guarantee uninterrupted hardware compatibility or error-free DDC/CI communications.
- **No Liability for Hardware or Ocular Impact**: The developer shall not be liable for any physical hardware malfunctions, monitor firmware corruption, backlight flickering, display panel issues, eye strain, or physical discomfort resulting from automated or manual brightness and color temperature adjustments.

You assume full risk, legal responsibility, and liability for all configurations, network settings, API token management, and hardware operations performed using Solaris.

## 9. Contact Us

If you have any questions about this Privacy Policy, please contact us at:
<solaris.app.contact@gmail.com>
maksim0-debug
