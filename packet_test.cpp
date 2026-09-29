#include <iostream>
#include <cstdint>

struct ControllerPacket {
    uint16_t buttons;
    int16_t lx, ly, rx, ry;
    uint8_t lt, rt;
};

int main() {
    std::cout << sizeof(ControllerPacket) << std::endl;
}
