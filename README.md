# Mobile Virtual Gamepad for Steam & Epic Games

A network-based virtual gamepad solution that allows your mobile device to act as an Xbox 360 controller for Steam and Epic Games on Windows.

Phone (Flutter app) -> Windows C++ server over UDP port 8888 -> ViGEmBus virtual Xbox 360 controller -> Steam/Epic games.

## Features

- **UDP Network Protocol** - Low-latency controller input streaming (12-byte packet: buttons + 2 sticks + 2 triggers)
- **Xbox 360 Emulation** - Uses ViGEmBus to create a virtual Xbox 360 controller recognized by all games
- **Rumble / Vibration** - Game rumble from Xbox 360 (large + small motors) sent back to phone via ViGEm X360 notification callback; phone vibrates with relative strength. Visible Vibration ON/OFF toggle.
- **Wi-Fi and USB modes** - Works over Wi-Fi or over USB cable via RNDIS/USB tethering. No ADB required.
- **Connection screen** - Wi-Fi / USB / Auto selector, editable PC IP field (saved locally), Connect/Disconnect + status
- **Shareable APK** - Release APK works on any Android phone; no hardcoded IP. User enters PC IP on first run.
- **Real-time Input** - Buttons, D-pad, triggers, both analog sticks

## Components

- `VirtualControllerServer.cpp` - C++ UDP server that receives controller data and feeds it to Windows via ViGEmBus; also receives ViGEm X360 rumble callbacks and sends 3-byte rumble packet `[0x52, large, small]` back to phone
- `android_app/` - Flutter Android app (controller UI + rumble + connection modes)
- `releases/VirtualGamepad-v1.0.apk` - Shareable release APK (see USER_GUIDE.md)
- `src/ViGEmClient.cpp` / `include/` - ViGEm client library
- `test_sender.py` - Python test client for simulating controller inputs
- `USER_GUIDE.md` - Step-by-step guide for Wi-Fi and USB setup

## Quick Start

No manual driver install needed. Use the launcher:

1. Download `Start-Gamepad.bat` and `VirtualControllerServer.exe` (keep both in SAME folder on PC)
2. Double-click `Start-Gamepad.bat` every time you want to play (keep its window open). It auto-checks ViGEmBus (auto-downloads if missing), adds firewall UDP 8888, shows your PC IPs, and starts the server. Allow Yes on UAC if asked. On first ViGEmBus install, restart PC once then run the launcher again.
3. Install `releases/VirtualGamepad-v1.0.apk` on phone, open app
4. For Wi-Fi (no cable): connect phone + PC to same Wi-Fi, use Wireless LAN IPv4 shown in launcher / `ipconfig`, select **Wi-Fi** in app, enter IP, tap **Connect**
5. For USB (no Wi-Fi): plug USB cable, on phone enable Settings > Hotspot & tethering > **USB tethering**, use Remote NDIS IPv4 shown in launcher / `ipconfig` (e.g. 192.168.42.x), select **USB** in app, enter IP, tap **Connect**
6. Open `joy.cpl` on Windows to see the virtual controller respond. Keep launcher window open while playing. Close it to disconnect.

No ADB or developer mode needed. See USER_GUIDE.md for full steps and troubleshooting.

## Vibration

Games that use Xbox rumble will vibrate the phone. Use the **Vibration** switch in the connection bar (also floating button on gamepad page) to turn it ON/OFF. When OFF rumble packets are ignored. Strength of large/small motors is preserved as much as Android allows.

## Downloads

- APK: `releases/VirtualGamepad-v1.0.apk` (install on phone)
- Launcher: `Start-Gamepad.bat` + `VirtualControllerServer.exe` (keep together on PC, double-click .bat every time)
- ViGEmBus auto-handled by launcher; manual: https://github.com/nefarius/ViGEmBus/releases

Full setup for a friend: download apk + bat + exe from GitHub, run bat on PC, install apk on phone, enter IP shown in bat window.

## Build From Source

See [BUILD.md](BUILD.md) for server and APK build instructions.

```
Server: g++ -g -I ./include VirtualControllerServer.cpp src/ViGEmClient.cpp -o VirtualControllerServer.exe -lsetupapi -lws2_32
App:    cd android_app && flutter build apk --release
```

## Documentation

- [USER_GUIDE.md](USER_GUIDE.md) - Detailed Wi-Fi/USB/vibration guide
- [BUILD.md](BUILD.md) - Build instructions

## Status

Core UDP -> Virtual Controller working. Rumble and USB tethering modes implemented.
