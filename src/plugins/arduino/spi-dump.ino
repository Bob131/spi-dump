#include <SPI.h>

#define CS_PIN 10

#define CMD_PREFIX 0xff
#define CS_PULL_LOW  0x1
#define CS_PULL_HIGH 0x2

void setup() {
    Serial.begin(57600);

    pinMode(CS_PIN, OUTPUT);
    digitalWrite(CS_PIN, HIGH);
    SPI.begin();
}

void loop() {
    if (Serial.available()) {
        byte input = Serial.read();
        if (input == CMD_PREFIX) {
            while (Serial.available() == 0) {}
            byte cmd = Serial.read();
            switch (cmd) {
                case CS_PULL_LOW:
                    digitalWrite(CS_PIN, LOW);
                    break;
                case CS_PULL_HIGH:
                    digitalWrite(CS_PIN, HIGH);
                    break;
            }
            if (cmd != CMD_PREFIX) {
                Serial.write(cmd xor 0xff);
                return;
            }
        }
        Serial.write(SPI.transfer(input));
    }
}
