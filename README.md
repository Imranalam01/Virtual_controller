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

## Quick Start (Wi-Fi)

1. Install [ViGEmBus 1.22.0](https://github.com/nefarius/ViGEmBus/releases) on PC and restart
2. Run `./VirtualControllerServer.exe` on PC (keep open, allow UDP 8888)
3. On PC run `ipconfig` to get Wi-Fi IPv4 (e.g. 192.168.1.10)
4. Install `releases/VirtualGamepad-v1.0.apk` on phone, open app
5. Select **Wi-Fi** mode, enter PC IP, tap **Connect**
6. Open `joy.cpl` on Windows to see the virtual controller respond

## USB Cable Mode (No Wi-Fi)

Just plugging the USB cable is not enough - you must enable USB tethering so the cable carries a network (RNDIS):

1. Plug phone to PC with USB Type-C cable
2. On phone: Settings > Network & Internet > Hotspot & tethering > Enable **USB tethering**
3. On PC: `ipconfig` -> find `Remote NDIS based Internet Sharing Device` -> note IPv4 (e.g. `192.168.42.129` or `192.168.137.1`)
4. In app select **USB** mode, enter that IP, tap **Connect**. Keep cable and tethering ON.

No ADB or developer mode needed. See USER_GUIDE.md for full steps and troubleshooting.

## Vibration

Games that use Xbox rumble will vibrate the phone. Use the **Vibration** switch in the connection bar (also floating button on gamepad page) to turn it ON/OFF. When OFF rumble packets are ignored. Strength of large/small motors is preserved as much as Android allows.

## Downloads

- APK: `releases/VirtualGamepad-v1.0.apk` (install on phone)
- Server: `VirtualControllerServer.exe` (run on PC)
- ViGEmBus driver: https://github.com/nefarius/ViGEmBus/releases

Full setup for a friend: install ViGEmBus once, copy APK + exe, follow USER_GUIDE.md.

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
