# Build Instructions

## Prerequisites

1. **ViGEmBus Driver** - Install ViGEmBus 1.22.0 from:
   - https://github.com/nefarius/ViGEmBus/releases

2. **MinGW-w64 GCC Compiler** (if not installed):
   - MSYS2/UCRT64 recommended
   - Or any MinGW-w64 distribution with g++

3. **Python 3.x** (for testing)

## Building from Source

### Using VSCode
Press `Ctrl+Shift+B` to run the default build task.

### Using Command Line
```bash
g++ -g -I ./include VirtualControllerServer.cpp src/ViGEmClient.cpp -o VirtualControllerServer.exe -lsetupapi -lws2_32
```

## Running the Server

1. Ensure ViGEmBus driver is installed
2. Run the compiled executable:
   ```bash
   ./VirtualControllerServer.exe
   ```
3. Server will listen on UDP port 8888

## Testing

Run the Python test client to simulate controller input:
```bash
python test_sender.py
```

Open Windows Game Controllers (`joy.cpl`) to see the virtual Xbox 360 controller respond in real-time.

## Troubleshooting

- **"ViGEmBus driver connection failed"**: Install ViGEmBus driver
- **Compilation errors**: Ensure MinGW-w64 g++ is in PATH
- **UDP connection issues**: Check firewall settings for port 8888
