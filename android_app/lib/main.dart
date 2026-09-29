import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const GamepadApp());
}

class GamepadApp extends StatelessWidget {
  const GamepadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Virtual Gamepad',
      theme: ThemeData.dark(),
      home: const GamepadPage(),
    );
  }
}

// ============================================================
// USB CONNECTION MODES
// ============================================================
// Wi-Fi : phone + PC on same Wi-Fi, use Wi-Fi IPv4 (e.g. 192.168.1.x)
// USB   : phone shares internet via USB tethering (RNDIS). On Android
//         enable Settings > Hotspot & tethering > USB tethering, then
//         on PC run ipconfig and look for "Remote NDIS" adapter
//         (e.g. 192.168.42.x / 192.168.137.x). Enter that IP below.
// Auto  : tries saved IP automatically on start / connect.
// ============================================================
enum ConnectionMode { wifi, usb, auto }

class GamepadPage extends StatefulWidget {
  const GamepadPage({super.key});

  @override
  State<GamepadPage> createState() => _GamepadPageState();
}

class _GamepadPageState extends State<GamepadPage> {
  RawDatagramSocket? socket;

  String serverIp = '192.168.1.10';
  final int serverPort = 8888;

  // Current controller state
  int buttonsState = 0;
  int lxState = 0;
  int lyState = 0;
  int rxState = 0;
  int ryState = 0;
  int ltState = 0;
  int rtState = 0;

  // ----- connection / prefs -----
  ConnectionMode mode = ConnectionMode.wifi;
  final TextEditingController ipController =
      TextEditingController(text: '192.168.1.10');
  bool isConnected = false;
  String statusText = 'Disconnected';
  bool vibrationEnabled = true;
  // ignore: unused_field
  bool _prefsLoaded = false;

  // true = show controller, false = show settings/connect page
  bool _showController = false;

  // ----- RUMBLE: rate limiting -----
  DateTime _lastVibration = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _vibrationThrottle = Duration(milliseconds: 30);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('serverIp');
      final savedVib = prefs.getBool('vibrationEnabled');
      final savedModeIndex = prefs.getInt('connectionMode');
      final savedShowController = prefs.getBool('showController');
      setState(() {
        if (savedIp != null && savedIp.isNotEmpty) {
          serverIp = savedIp;
          ipController.text = savedIp;
        }
        if (savedVib != null) vibrationEnabled = savedVib;
        if (savedModeIndex != null &&
            savedModeIndex >= 0 &&
            savedModeIndex < ConnectionMode.values.length) {
          mode = ConnectionMode.values[savedModeIndex];
        }
        if (savedShowController != null) _showController = savedShowController;
        _prefsLoaded = true;
      });
      if (mode == ConnectionMode.auto && savedIp != null) {
        await _connect(autoNavigate: false);
      }
    } catch (_) {
      setState(() => _prefsLoaded = true);
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('serverIp', serverIp);
      await prefs.setBool('vibrationEnabled', vibrationEnabled);
      await prefs.setInt('connectionMode', mode.index);
      await prefs.setBool('showController', _showController);
    } catch (_) {}
  }

  // ============================================================
  // RUMBLE: socket bind + listen
  // Same RawDatagramSocket used for sends also listens for incoming
  // Datagram events. Server sends 3-byte rumble packet:
  //   byte0 == 0x52 ('R' = 82), byte1 = large 0-255, byte2 = small 0-255
  // ============================================================
  Future<void> _ensureSocket() async {
    if (socket != null) return;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      setState(() {
        isConnected = true;
        statusText = 'Listening on ${socket!.address.address}:${socket!.port}';
      });
      socket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            Datagram? dg = socket?.receive();
            while (dg != null) {
              _handleIncoming(dg.data);
              dg = socket?.receive();
            }
          }
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() => statusText = 'Socket error: $e');
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            isConnected = false;
            statusText = 'Socket closed';
          });
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => statusText = 'Bind failed: $e');
      socket = null;
      isConnected = false;
    }
  }

  void _handleIncoming(Uint8List data) {
    // RUMBLE packet: 3 bytes, first == 0x52
    if (data.length == 3 && data[0] == 0x52) {
      final int large = data[1];
      final int small = data[2];
      _triggerRumble(large, small);
    }
  }

  // ============================================================
  // RUMBLE: haptics with relative strength + throttling
  // ============================================================
  // ignore_for_file: unnecessary_nullable_for_final_variable_declarations

  Future<void> _triggerRumble(int large, int small) async {
    if (!vibrationEnabled) return;
    final now = DateTime.now();
    if (now.difference(_lastVibration) < _vibrationThrottle) return;
    _lastVibration = now;
    final int maxMotor = large > small ? large : small;
    if (maxMotor == 0) return;
    int durationMs;
    int amplitude;
    if (large > 0) {
      durationMs = 100 + (large * 200 ~/ 255);
      amplitude = large.clamp(1, 255);
    } else {
      durationMs = 30 + (small * 50 ~/ 255);
      amplitude = (small ~/ 2).clamp(1, 255);
    }
    try {
      final bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        final bool? hasAmp = await Vibration.hasAmplitudeControl();
        if (hasAmp == true) {
          await Vibration.vibrate(duration: durationMs, amplitude: amplitude);
        } else {
          await Vibration.vibrate(duration: durationMs);
        }
        return;
      }
    } catch (_) {}
    try {
      if (maxMotor > 180) {
        HapticFeedback.heavyImpact();
      } else if (maxMotor > 80) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  Future<void> _connect({bool autoNavigate = true}) async {
    final String ip = ipController.text.trim();
    if (ip.isEmpty) {
      setState(() => statusText = 'Enter PC IP address');
      return;
    }
    try {
      InternetAddress(ip);
    } catch (_) {
      setState(() => statusText = 'Invalid IP: $ip');
      return;
    }
    setState(() {
      serverIp = ip;
      statusText = 'Connecting to $ip:$serverPort...';
    });
    await _savePrefs();
    await _ensureSocket();
    if (socket != null) {
      await sendPacket();
      if (!mounted) return;
      setState(() => statusText = 'Connected to $ip:$serverPort');
      if (autoNavigate) {
        setState(() => _showController = true);
        await _savePrefs();
      }
    }
  }

  void _disconnect() {
    try {
      socket?.close();
    } catch (_) {}
    socket = null;
    if (!mounted) return;
    setState(() {
      isConnected = false;
      statusText = 'Disconnected';
    });
  }

  Future<void> sendPacket() async {
    try {
      await _ensureSocket();
      if (socket == null) return;
      final data = ByteData(12);
      data.setUint16(0, buttonsState, Endian.little);
      data.setInt16(2, lxState, Endian.little);
      data.setInt16(4, lyState, Endian.little);
      data.setInt16(6, rxState, Endian.little);
      data.setInt16(8, ryState, Endian.little);
      data.setUint8(10, ltState);
      data.setUint8(11, rtState);
      socket!.send(
        data.buffer.asUint8List(),
        InternetAddress(serverIp),
        serverPort,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => statusText = 'Send failed: $e');
    }
  }

  @override
  void dispose() {
    try {
      socket?.close();
    } catch (_) {}
    ipController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // Xbox button helper
  Widget controllerButton(
    String label,
    int buttonCode, {
    double size = 62,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        buttonsState |= buttonCode;
        sendPacket();
      },
      onTapUp: (_) {
        buttonsState &= ~buttonCode;
        sendPacket();
      },
      onTapCancel: () {
        buttonsState &= ~buttonCode;
        sendPacket();
      },
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade800,
          border: Border.all(
            color: Colors.grey.shade600,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Small center buttons
  Widget smallButton(String label, int buttonCode) {
    return GestureDetector(
      onTapDown: (_) {
        buttonsState |= buttonCode;
        sendPacket();
      },
      onTapUp: (_) {
        buttonsState &= ~buttonCode;
        sendPacket();
      },
      onTapCancel: () {
        buttonsState &= ~buttonCode;
        sendPacket();
      },
      child: Container(
        width: 55,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.grey.shade800,
          border: Border.all(
            color: Colors.grey.shade600,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget triggerButton(String label, {required bool left}) {
    return GestureDetector(
      onPanStart: (details) {
        _updateTrigger(details.localPosition, left);
      },
      onPanUpdate: (details) {
        _updateTrigger(details.localPosition, left);
      },
      onPanEnd: (_) {
        if (left) {
          ltState = 0;
        } else {
          rtState = 0;
        }
        sendPacket();
      },
      onPanCancel: () {
        if (left) {
          ltState = 0;
        } else {
          rtState = 0;
        }
        sendPacket();
      },
      child: Container(
        width: 80,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade600,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _updateTrigger(Offset position, bool left) {
    double value = 1.0 - (position.dy / 55.0);
    value = value.clamp(0.0, 1.0);
    final int triggerValue = (value * 255).round();
    if (left) {
      ltState = triggerValue;
    } else {
      rtState = triggerValue;
    }
    sendPacket();
  }

  Widget shoulderButton(String label, int buttonCode) {
    return GestureDetector(
      onTapDown: (_) {
        buttonsState |= buttonCode;
        sendPacket();
      },
      onTapUp: (_) {
        buttonsState &= ~buttonCode;
        sendPacket();
      },
      onTapCancel: () {
        buttonsState &= ~buttonCode;
        sendPacket();
      },
      child: Container(
        width: 80,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade600,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget dpadButton(String label, int buttonCode) {
    return GestureDetector(
      onTapDown: (_) {
        buttonsState |= buttonCode;
        sendPacket();
      },
      onTapUp: (_) {
        buttonsState &= ~buttonCode;
        sendPacket();
      },
      onTapCancel: () {
        buttonsState &= ~buttonCode;
        sendPacket();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade600,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget dpad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dpadButton('\u25B2', 0x0001),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dpadButton('\u25C0', 0x0004),
            const SizedBox(width: 4),
            dpadButton('\u25CF', 0),
            const SizedBox(width: 4),
            dpadButton('\u25B6', 0x0008),
          ],
        ),
        dpadButton('\u25BC', 0x0002),
      ],
    );
  }

  Widget analogStick({
    required bool left,
  }) {
    return _AnalogStick(
      onMove: (x, y) {
        if (left) {
          lxState = x;
          lyState = y;
        } else {
          rxState = x;
          ryState = y;
        }
        sendPacket();
      },
      onRelease: () {
        if (left) {
          lxState = 0;
          lyState = 0;
        } else {
          rxState = 0;
          ryState = 0;
        }
        sendPacket();
      },
    );
  }

  // ============================================================
  // SETTINGS PAGE - dedicated connection + vibration screen
  // ============================================================
  Widget _buildSettingsPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Connection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (isConnected)
            TextButton.icon(
              onPressed: () async {
                setState(() => _showController = true);
                await _savePrefs();
              },
              icon: const Icon(Icons.gamepad, size: 18, color: Colors.white),
              label: const Text('Controller', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<ConnectionMode>(
                segments: const [
                  ButtonSegment(value: ConnectionMode.wifi, label: Text('Wi-Fi'), icon: Icon(Icons.wifi, size: 18)),
                  ButtonSegment(value: ConnectionMode.usb, label: Text('USB'), icon: Icon(Icons.usb, size: 18)),
                  ButtonSegment(value: ConnectionMode.auto, label: Text('Auto'), icon: Icon(Icons.autorenew, size: 18)),
                ],
                selected: <ConnectionMode>{mode},
                onSelectionChanged: (Set<ConnectionMode> s) {
                  setState(() => mode = s.first);
                  _savePrefs();
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ipController,
                      decoration: const InputDecoration(
                        labelText: 'PC IP Address',
                        hintText: '192.168.1.10',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) => _connect(),
                      onChanged: (v) => serverIp = v.trim(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: isConnected ? _disconnect : _connect,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                    child: Text(isConnected ? 'Disconnect' : 'Connect'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isConnected ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(isConnected ? Icons.circle : Icons.circle_outlined, size: 10, color: isConnected ? Colors.greenAccent : Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(statusText, style: TextStyle(fontSize: 12, color: isConnected ? Colors.greenAccent : Colors.orangeAccent)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vibration, size: 20),
                        const SizedBox(width: 8),
                        const Text('Vibration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(vibrationEnabled ? 'ON' : 'OFF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: vibrationEnabled ? Colors.greenAccent : Colors.grey)),
                        const SizedBox(width: 8),
                        Switch(
                          value: vibrationEnabled,
                          onChanged: (v) {
                            setState(() => vibrationEnabled = v);
                            _savePrefs();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      vibrationEnabled
                          ? 'Phone will vibrate on game rumble. Strength of large/small motors is preserved.'
                          : 'Rumble packets are ignored. Phone will not vibrate.',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (mode == ConnectionMode.wifi)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.lightBlue.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Wi-Fi mode: No cable needed. Connect phone and PC to the same Wi-Fi.\nOn PC run Start-Gamepad.bat or ipconfig, find Wireless LAN adapter Wi-Fi -> IPv4 (e.g. 192.168.1.10) and enter it above.',
                    style: TextStyle(fontSize: 12, color: Colors.lightBlueAccent),
                  ),
                ),
              if (mode == ConnectionMode.usb)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'USB mode: Plug phone to PC with USB cable, then on phone enable Settings > Hotspot & tethering > USB tethering.\nThen on PC run Start-Gamepad.bat or ipconfig and find Remote NDIS adapter IP (e.g. 192.168.42.x or 192.168.137.x) and enter it above. Keep cable plugged in.',
                    style: TextStyle(fontSize: 12, color: Colors.amberAccent),
                  ),
                ),
              if (mode == ConnectionMode.auto)
                const Text('Auto: connects to saved IP on start. Edit IP if needed then tap Connect.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: isConnected
                    ? () async {
                        setState(() => _showController = true);
                        await _savePrefs();
                      }
                    : _connect,
                icon: Icon(isConnected ? Icons.sports_esports : Icons.link),
                label: Text(isConnected ? 'Open Controller' : 'Connect and Play'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              if (!isConnected) const SizedBox(height: 8),
              if (!isConnected)
                OutlinedButton(
                  onPressed: () async {
                    setState(() => _showController = true);
                    await _savePrefs();
                  },
                  child: const Text('Open Controller Anyway'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTROLLER PAGE - pure gamepad, no connection bar
  // ============================================================
  Widget _buildControllerPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 55,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            shoulderButton('LB', 0x0100),
                            const SizedBox(width: 6),
                            triggerButton('LT', left: true),
                          ],
                        ),
                        Row(
                          children: [
                            triggerButton('RT', left: false),
                            const SizedBox(width: 6),
                            shoulderButton('RB', 0x0200),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              dpad(),
                              const SizedBox(height: 10),
                              analogStick(left: true),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  smallButton('VIEW', 0x0020),
                                  smallButton('MENU', 0x0010),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'VIRTUAL GAMEPAD',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  color: Colors.grey,
                                ),
                              ),
                              if (!isConnected)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Not connected', style: TextStyle(fontSize: 9, color: Colors.orangeAccent)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              controllerButton('Y', 0x8000),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  controllerButton('X', 0x4000),
                                  controllerButton('B', 0x2000),
                                ],
                              ),
                              controllerButton('A', 0x1000),
                              const SizedBox(height: 8),
                              analogStick(left: false),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isConnected ? Icons.circle : Icons.circle_outlined, size: 8, color: isConnected ? Colors.greenAccent : Colors.orangeAccent),
                        const SizedBox(width: 4),
                        Icon(vibrationEnabled ? Icons.vibration : Icons.vibration_outlined, size: 12, color: vibrationEnabled ? Colors.greenAccent : Colors.grey),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        setState(() => _showController = false);
                        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
                        await _savePrefs();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.settings, size: 20, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showController) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return _buildControllerPage();
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      return _buildSettingsPage();
    }
  }
}

class _AnalogStick extends StatefulWidget {
  final void Function(int x, int y) onMove;
  final VoidCallback onRelease;

  const _AnalogStick({
    required this.onMove,
    required this.onRelease,
  });

  @override
  State<_AnalogStick> createState() => _AnalogStickState();
}

class _AnalogStickState extends State<_AnalogStick> {
  Offset knobPosition = Offset.zero;

  static const double size = 120;
  static const double knobSize = 65;
  static const double maxTravel = (size - knobSize) / 2;

  void updateStick(Offset position) {
    const center = Offset(size / 2, size / 2);
    Offset offset = position - center;
    if (offset.distance > maxTravel) {
      offset = Offset.fromDirection(
        offset.direction,
        maxTravel,
      );
    }
    setState(() {
      knobPosition = offset;
    });
    final x = (offset.dx / maxTravel * 32767).round();
    final y = (-offset.dy / maxTravel * 32767).round();
    widget.onMove(x, y);
  }

  void releaseStick() {
    setState(() {
      knobPosition = Offset.zero;
    });
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        updateStick(details.localPosition);
      },
      onPanUpdate: (details) {
        updateStick(details.localPosition);
      },
      onPanEnd: (_) {
        releaseStick();
      },
      onPanCancel: () {
        releaseStick();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade900,
          border: Border.all(
            color: Colors.grey.shade600,
            width: 3,
          ),
        ),
        child: Center(
          child: Transform.translate(
            offset: knobPosition,
            child: Container(
              width: knobSize,
              height: knobSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade700,
                border: Border.all(
                  color: Colors.grey.shade500,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
