#include <iostream>
#include <cstdint>
#include <mutex>
#include <atomic>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <ViGEm/Client.h>

// Link Winsock library
#pragma comment(lib, "ws2_32.lib")

#define PORT 8888
#define BUFFER_SIZE 1024

// RUMBLE: global storage for last client address with thread safety
static SOCKET g_serverSocket = INVALID_SOCKET;
static sockaddr_in g_lastClientAddr{};
static std::mutex g_clientAddrMutex;
static std::atomic<bool> g_hasClient{false};

// RUMBLE: X360 notification callback for vibration/rumble feedback
VOID CALLBACK X360Notification(PVIGEM_CLIENT Client, PVIGEM_TARGET Target, UCHAR LargeMotor, UCHAR SmallMotor, UCHAR LedNumber, LPVOID UserData)
{
    (void)Client;
    (void)Target;
    (void)LedNumber;
    (void)UserData;

    // RUMBLE: skip if no client has connected yet
    if (!g_hasClient.load()) {
        return;
    }

    // RUMBLE: copy last client address under lock
    sockaddr_in clientCopy{};
    {
        std::lock_guard<std::mutex> lock(g_clientAddrMutex);
        clientCopy = g_lastClientAddr;
    }

    // RUMBLE: build 3-byte rumble packet [0x52, largeMotor, smallMotor]
    unsigned char rumblePacket[3];
    rumblePacket[0] = 0x52;
    rumblePacket[1] = LargeMotor;
    rumblePacket[2] = SmallMotor;

    // RUMBLE: send rumble packet back to last known client, ignore send errors silently
    sendto(g_serverSocket, reinterpret_cast<const char*>(rumblePacket), sizeof(rumblePacket), 0, (sockaddr*)&clientCopy, sizeof(clientCopy));
}

// Packet structure matching mobile client input data
struct ControllerPacket {
    uint16_t buttons; // Bitmask for buttons (A, B, X, Y, D-Pad, etc.)
    int16_t lx;       // Left Stick X (-32768 to 32767)
    int16_t ly;       // Left Stick Y (-32768 to 32767)
    int16_t rx;       // Right Stick X (-32768 to 32767)
    int16_t ry;       // Right Stick Y (-32768 to 32767)
    uint8_t lt;       // Left Trigger (0 to 255)
    uint8_t rt;       // Right Trigger (0 to 255)
};

int main() {
    std::cout << "=========================================" << std::endl;
    std::cout << "   Mobile Controller C++ UDP Server      " << std::endl;
    std::cout << "=========================================" << std::endl;

    // 1. Initialize Winsock
    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        std::cerr << "[!] WSAStartup failed." << std::endl;
        return -1;
    }

    // 2. Create UDP Socket
    g_serverSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (g_serverSocket == INVALID_SOCKET) {
        std::cerr << "[!] Socket creation failed." << std::endl;
        WSACleanup();
        return -1;
    }

    // 3. Bind Socket to Port 8888
    sockaddr_in serverAddr{};
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_addr.s_addr = INADDR_ANY;
    serverAddr.sin_port = htons(PORT);

    if (bind(g_serverSocket, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
        std::cerr << "[!] Bind failed on port " << PORT << std::endl;
        closesocket(g_serverSocket);
        WSACleanup();
        return -1;
    }

    std::cout << "[+] UDP Socket listening on port " << PORT << std::endl;

    // 4. Initialize ViGEm Client & Target
    PVIGEM_CLIENT client = vigem_alloc();
    if (client == NULL) {
        std::cerr << "[!] Failed to allocate ViGEm client." << std::endl;
        return -1;
    }

    if (!VIGEM_SUCCESS(vigem_connect(client))) {
        std::cerr << "[!] ViGEmBus driver connection failed. Is ViGEmBus installed?" << std::endl;
        vigem_free(client);
        return -1;
    }

    PVIGEM_TARGET target = vigem_target_x360_alloc();
    if (!VIGEM_SUCCESS(vigem_target_add(client, target))) {
        std::cerr << "[!] Failed to plugin virtual Xbox 360 controller." << std::endl;
        vigem_disconnect(client);
        vigem_free(client);
        return -1;
    }

    // RUMBLE: register notification callback for rumble feedback
    vigem_target_x360_register_notification(client, target, X360Notification, nullptr);

    std::cout << "[+] Virtual Xbox 360 Controller connected to Windows!" << std::endl;
    std::cout << "[*] Ready to receive mobile controller inputs...\n" << std::endl;

    // 5. Main UDP Receiving Loop
    sockaddr_in clientAddr{};
    int clientAddrSize = sizeof(clientAddr);
    char buffer[BUFFER_SIZE];

    XUSB_REPORT controllerReport;
    XUSB_REPORT_INIT(&controllerReport);

    while (true) {
        int bytesReceived = recvfrom(g_serverSocket, buffer, BUFFER_SIZE, 0, (sockaddr*)&clientAddr, &clientAddrSize);
        
        if (bytesReceived == sizeof(ControllerPacket)) {
            // RUMBLE: update stored client address under lock for rumble replies
            {
                std::lock_guard<std::mutex> lock(g_clientAddrMutex);
                g_lastClientAddr = clientAddr;
                g_hasClient.store(true);
            }

            ControllerPacket* packet = reinterpret_cast<ControllerPacket*>(buffer);
            std::cout << "Packet: Buttons=" << packet->buttons
          << " LX=" << packet->lx
          << " LY=" << packet->ly
          << " RX=" << packet->rx
          << " RY=" << packet->ry
          << " LT=" << static_cast<int>(packet->lt)
          << " RT=" << static_cast<int>(packet->rt)
          << std::endl;

            // Map incoming network values to Xbox 360 Report
            controllerReport.wButtons = packet->buttons;
            controllerReport.sThumbLX = packet->lx;
            controllerReport.sThumbLY = packet->ly;
            controllerReport.sThumbRX = packet->rx;
            controllerReport.sThumbRY = packet->ry;
            controllerReport.bLeftTrigger = packet->lt;
            controllerReport.bRightTrigger = packet->rt;

            // Send hardware report to Windows Kernel via ViGEmBus
            VIGEM_ERROR result =
    vigem_target_x360_update(client, target, controllerReport);

if (!VIGEM_SUCCESS(result)) {
    std::cout << "ViGEm update failed: "
              << result << std::endl;
}
        }
        // RUMBLE: invalid packets (bytes != 12) are silently ignored
    }

    // Cleanup Resources
    // RUMBLE: unregister notification before removing target
    vigem_target_x360_unregister_notification(target);
    vigem_target_remove(client, target);
    vigem_target_free(target);
    vigem_disconnect(client);
    vigem_free(client);
    closesocket(g_serverSocket);
    WSACleanup();

    return 0;
}