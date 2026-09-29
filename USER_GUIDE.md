# Virtual Gamepad - User Guide

This guide is for anyone installing the APK on their phone. No coding needed.

## What You Need

- Windows PC/laptop with the game (Steam/Epic)
- Android phone
- USB Type-C cable (for USB mode) or same Wi-Fi network (for Wi-Fi mode)
- `VirtualGamepad-v1.0.apk` from `releases/` folder
- `Start-Gamepad.bat` + `VirtualControllerServer.exe` on the PC (keep both in SAME folder)

---

## 1. PC Setup

You must run `Start-Gamepad.bat` **every time** you want to play. It auto-checks/installs ViGEmBus, opens firewall, shows your IP, and starts the server. Keep its window open while playing.

1. Copy **both** `Start-Gamepad.bat` and `VirtualControllerServer.exe` to a folder on your PC (e.g. Desktop). Do not separate them.
2. Double-click `Start-Gamepad.bat` to run it. If Windows asks, click Yes on the UAC prompt.
   - If ViGEmBus is missing, the launcher will try to download and install it automatically (needs internet). If download fails, it will show a link: https://github.com/nefarius/ViGEmBus/releases - download ViGEmBusSetup_x64.msi, install, restart PC, then run the launcher again.
   - It will also add a firewall rule for UDP 8888.
   - It prints your IP addresses - note the one for your mode (Wi-Fi or USB).
3. When ready you should see:
   ```
   [+] ViGEmBus found.
   [+] Firewall rule already exists.
   [+] UDP Socket listening on port 8888
   [+] Virtual Xbox 360 Controller connected to Windows!
   [*] Ready to receive mobile controller inputs...
   ```
   Keep this window OPEN while playing. Close window or Ctrl+C to disconnect. To test, open `joy.cpl` (Windows + R, type joy.cpl) - you should see "Xbox 360 Controller" and it will respond when the phone is connected.
4. On first ViGEmBus install you must restart PC once, then run the launcher again.

---

## 2. Phone Setup

1. Copy `VirtualGamepad-v1.0.apk` to your phone (via USB, Drive, Telegram, etc.).
2. On phone, tap the APK file to install. If blocked, enable "Install unknown apps" for your file manager when prompted.
3. Open "Virtual Gamepad" app. You will see the connection bar at the top.

---

## 3. Connecting

At the top of the app you will see:

- **Mode selector:** Wi-Fi | USB | Auto
- **PC IP Address field:** enter your PC's IP
- **Connect button**
- **Vibration ON/OFF switch**

### Option A: Wi-Fi Mode (Easiest if both devices on same Wi-Fi)

1. On PC, open Command Prompt (Windows + R, type `cmd`), run `ipconfig`.
2. Find "Wireless LAN adapter Wi-Fi" -> IPv4 Address, e.g. `192.168.1.10`.
3. In app, select **Wi-Fi** mode, type that IP into the PC IP field, tap **Connect**.
4. Status should show "Connected". Controls now work.

### Option B: USB Mode (No Wi-Fi Needed)

Use this when you connect phone to PC with a USB Type-C cable. Just plugging the cable is NOT enough - you must enable USB tethering so the phone and PC share a network over the cable (RNDIS).

1. Plug phone to PC with USB cable.
2. On phone: Settings > Network & Internet > Hotspot & tethering > **Enable USB tethering**. (Path may vary: on Samsung it's Settings > Connections > Mobile Hotspot and Tethering > USB tethering). Allow if prompted.
3. On PC, open Command Prompt, run `ipconfig`. Look for a new adapter:
   `Ethernet adapter Remote NDIS based Internet Sharing Device` -> IPv4 Address, usually `192.168.42.1` or `192.168.137.1` or `192.168.42.129`. The gateway is the PC's address on this USB network.
4. In app, select **USB** mode, type that gateway IP (e.g. `192.168.42.129` or `192.168.42.1` - try both if unsure), tap **Connect**.
5. Keep the cable plugged in and keep USB tethering ON while playing. No Wi-Fi needed.

Tip: If USB mode doesn't connect, toggle USB tethering off/on, run `ipconfig` again, and update the IP in the app. Some phones use `192.168.137.x` instead of `192.168.42.x`.

### Option C: Auto Mode

Auto tries to connect to the last saved IP automatically when you open the app. Useful after you have connected once - just open the app and it reconnects.

---

## 4. Vibration / Rumble

Games that use Xbox controller rumble will send vibration to the phone.

- **Vibration switch ON:** phone vibrates on rumble events. Strength of large/small motors is preserved as much as Android allows.
- **Vibration switch OFF:** all rumble is ignored, phone never vibrates. Toggle this if vibration is too strong or you prefer silent.

You can toggle this anytime, even mid-game. Switch is visible in the connection bar and as a floating button on the controller screen.

Note: Android vibration strength varies by phone model. Some low-end phones have only on/off vibration.

---

## 5. Using the Controller

Once connected, use the on-screen gamepad:

- **D-Pad:** up/down/left/right
- **A/B/X/Y**, **View/Menu**, **LB/RB**, **LT/RT** (LT/RT are analog, slide to control pressure)
- **Left Stick / Right Stick:** drag to move, release to center

The app sends 12-byte UDP packets to port 8888. The server maps them to the virtual Xbox 360 controller that Steam/Epic games see.

Keep the app in foreground while playing for smoothest input.

---

## 6. Disconnect / Reconnect

- Tap **Disconnect** in the app, or just close the app.
- Close the server by pressing Ctrl+C or closing its window.
- Reconnect anytime by tapping Connect again. If IP changed (e.g. switched Wi-Fi), run `ipconfig` again and update the field.

Invalid packets, disconnects, and shutdowns are handled safely - no crash.

---

## 7. Troubleshooting

| Problem | Fix |
|---|---|
| App shows not connected | Check PC firewall for UDP 8888, check IP is correct (run `ipconfig`), ensure server is running |
| joy.cpl shows no controller | Reinstall ViGEmBus, restart PC, run server as Administrator |
| USB tethering option greyed out | Ensure USB cable is data cable (not charge-only), try different USB port, enable developer options not required |
| USB ipconfig shows no RNDIS adapter | Toggle USB tethering off/on, unplug/replug cable, wait 10 seconds |
| Controls lag | Use USB mode for lower latency, or stay close to Wi-Fi router, close background apps |
| No vibration | Check Vibration switch is ON, check phone vibration is not muted in system settings, test with a game that has rumble |
| APK won't install | Enable Install unknown apps, check Android version 7.0+ |

---

## 8. Files in This Repo

- `releases/VirtualGamepad-v1.0.apk` - Release APK (shareable)
- `Start-Gamepad.bat` - Launcher to run every time (auto-handles ViGEmBus + firewall + shows IP + starts server; keep both exe+bat together)
- `VirtualControllerServer.exe` - Windows server (run via launcher)
- `VirtualControllerServer.cpp` / `src/ViGEmClient.cpp` / `include/` - Server source
- `android_app/` - Flutter app source
- `BUILD.md` - Build instructions for developers (or just double-click the .bat)
- `USER_GUIDE.md` - This guide

---

## 9. For Developers - Building

See `BUILD.md` for building the server and the APK from source.

```
Server: g++ -g -I ./include VirtualControllerServer.cpp src/ViGEmClient.cpp -o VirtualControllerServer.exe -lsetupapi -lws2_32
APK:    cd android_app && flutter build apk --release
```
APK output: `android_app/build/app/outputs/flutter-apk/app-release.apk`
