import socket
import struct
import time

# Target server configuration
UDP_IP = "127.0.0.1"
UDP_PORT = 8888

# Xbox 360 Button Bitmasks
XUSB_GAMEPAD_DPAD_UP    = 0x0001
XUSB_GAMEPAD_DPAD_DOWN  = 0x0002
XUSB_GAMEPAD_A          = 0x1000
XUSB_GAMEPAD_B          = 0x2000
XUSB_GAMEPAD_X          = 0x4000
XUSB_GAMEPAD_Y          = 0x8000

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print(f"[*] Sending test UDP controller packets to {UDP_IP}:{UDP_PORT}...")
print("[*] Open 'joy.cpl' in Windows to watch the controller respond in real time!\n")

def send_packet(buttons, lx, ly, rx, ry, lt, rt):
    # Pack data into C++ struct format:
    # uint16 (H), int16 (h), int16 (h), int16 (h), int16 (h), uint8 (B), uint8 (B)
    packet = struct.pack("<HhhhhBB", buttons, lx, ly, rx, ry, lt, rt)
    sock.sendto(packet, (UDP_IP, UDP_PORT))

try:
    while True:
        # Step 1: Press 'A' button
        print("[->] Pressing 'A' Button")
        send_packet(XUSB_GAMEPAD_A, 0, 0, 0, 0, 0, 0)
        time.sleep(1)

        # Step 2: Push Left Stick all the way UP
        print("[->] Left Stick UP")
        send_packet(0, 0, 32767, 0, 0, 0, 0)
        time.sleep(1)

        # Step 3: Pull Right Trigger fully (255)
        print("[->] Full Right Trigger")
        send_packet(0, 0, 0, 0, 0, 0, 255)
        time.sleep(1)

        # Step 4: Reset all inputs to center/neutral
        print("[->] Resetting inputs to Neutral\n")
        send_packet(0, 0, 0, 0, 0, 0, 0)
        time.sleep(1)

except KeyboardInterrupt:
    print("\n[*] Stopping sender script.")