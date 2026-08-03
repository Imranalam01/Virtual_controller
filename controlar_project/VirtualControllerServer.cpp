#include <iostream>
#include <cstdint>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <ViGEm/Client.h>

// Link Winsock library
#pragma comment(lib, "ws2_32.lib")

#define PORT 8888
#define BUFFER_SIZE 1024

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
    SOCKET serverSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (serverSocket == INVALID_SOCKET) {
        std::cerr << "[!] Socket creation failed." << std::endl;
        WSACleanup();
        return -1;
    }

    // 3. Bind Socket to Port 8888
    sockaddr_in serverAddr{};
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_addr.s_addr = INADDR_ANY;
    serverAddr.sin_port = htons(PORT);

    if (bind(serverSocket, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
        std::cerr << "[!] Bind failed on port " << PORT << std::endl;
        closesocket(serverSocket);
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

    std::cout << "[+] Virtual Xbox 360 Controller connected to Windows!" << std::endl;
    std::cout << "[*] Ready to receive mobile controller inputs...\n" << std::endl;

    // 5. Main UDP Receiving Loop
    sockaddr_in clientAddr{};
    int clientAddrSize = sizeof(clientAddr);
    char buffer[BUFFER_SIZE];

    XUSB_REPORT controllerReport;
    XUSB_REPORT_INIT(&controllerReport);

    while (true) {
        int bytesReceived = recvfrom(serverSocket, buffer, BUFFER_SIZE, 0, (sockaddr*)&clientAddr, &clientAddrSize);
        
        if (bytesReceived == sizeof(ControllerPacket)) {
            ControllerPacket* packet = reinterpret_cast<ControllerPacket*>(buffer);

            // Map incoming network values to Xbox 360 Report
            controllerReport.wButtons = packet->buttons;
            controllerReport.sThumbLX = packet->lx;
            controllerReport.sThumbLY = packet->ly;
            controllerReport.sThumbRX = packet->rx;
            controllerReport.sThumbRY = packet->ry;
            controllerReport.bLeftTrigger = packet->lt;
            controllerReport.bRightTrigger = packet->rt;

            // Send hardware report to Windows Kernel via ViGEmBus
            vigem_target_x360_update(client, target, controllerReport);
        }
    }

    // Cleanup Resources
    vigem_target_remove(client, target);
    vigem_target_free(target);
    vigem_disconnect(client);
    vigem_free(client);
    closesocket(serverSocket);
    WSACleanup();

    return 0;
}