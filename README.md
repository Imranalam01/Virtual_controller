# Mobile Virtual Gamepad for Steam & Epic Games

A network-based virtual gamepad solution that allows your mobile device to act as an Xbox 360 controller for Steam and Epic Games on Windows.

## Features

- **UDP Network Protocol** - Low-latency controller input streaming over local network
- **Xbox 360 Emulation** - Uses ViGEmBus to create a virtual Xbox 360 controller recognized by all games
- **Cross-Platform Mobile Support** - Any device that can send UDP packets can act as a controller
- **Real-time Input** - Supports buttons, analog sticks, and triggers with minimal latency

## Components

- `VirtualControllerServer.cpp` - C++ UDP server that receives controller data and feeds it to Windows via ViGEmBus
- `test_sender.py` - Python test client for simulating controller inputs
- `src/ViGEmClient.cpp` - ViGEm client library implementation

## Quick Start

1. Install [ViGEmBus 1.22.0](https://github.com/nefarius/ViGEmBus/releases)
2. Run the server: `./VirtualControllerServer.exe`
3. Test with: `python test_sender.py`
4. Open `joy.cpl` to see the virtual controller respond

See [BUILD.md](BUILD.md) for detailed build instructions.

## Status

Currently under development. Core UDP→Virtual Controller functionality is working.
