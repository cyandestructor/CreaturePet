#include <Wire.h>
#include <SPI.h>
#include <Adafruit_PN532.h>

#define DEBUG 0
#if DEBUG
#define DebugPrint(...) Serial.print(__VA_ARGS__)
#define DebugPrintLn(...) Serial.println(__VA_ARGS__)
#else
#define DebugPrint(...) \
  do { \
  } while (0)
#define DebugPrintLn(...) \
  do { \
  } while (0)
#endif

// Using the breakout with SPI, define the pins for SPI communication.
#define PN532_SCK (13)
#define PN532_MOSI (11) //11
#define PN532_SS (10)
#define PN532_MISO (12) //12

Adafruit_PN532 nfc(PN532_SCK, PN532_MISO, PN532_MOSI, PN532_SS);

bool cardDetected = false;
bool cardRead = false;
uint8_t lastDetectedUid[] = { 0, 0, 0, 0, 0, 0, 0 };

void setup(void) {
  Serial.begin(115200);
  while (!Serial) delay(10);  // for Leonardo/Micro/Zero

  InitNFC();
}

void loop(void) {
  uint8_t success;
  uint8_t uid[] = { 0, 0, 0, 0, 0, 0, 0 };  // Buffer to store the returned UID
  uint8_t uidLength;                        // Length of the UID (4 or 7 bytes depending on ISO14443A card type)

  // Wait for an ISO14443A type cards (Mifare, etc.).  When one is found
  // 'uid' will be populated with the UID, and uidLength will indicate
  // if the uid is 4 bytes (Mifare Classic) or 7 bytes (Mifare Ultralight)
  cardDetected = nfc.startPassiveTargetIDDetection(PN532_MIFARE_ISO14443A);

  if (cardDetected) {
    if (!cardRead) {
      cardRead = nfc.readDetectedPassiveTargetID(uid, &uidLength);

      if (cardRead) {
        bool cardRepetition = CompareUIDs(uid, lastDetectedUid, uidLength);

        if (!cardRepetition) {
          // Save the uid as the last one detected
          CopyUID(uid, lastDetectedUid, uidLength);
          DebugPrintLn("New card detected");
        } else {
          DebugPrintLn("Repeated card detected");
        }

        if (uidLength == 4) {
          MifareClassicReadBlock4(uid, uidLength);
        }

        if (uidLength == 7) {
          MifareUltralightReadBlock4();
        }
      }
    }
  } else if (cardRead) {
    cardRead = false;
  }
}

void InitNFC() {
  nfc.begin();

  uint32_t versiondata = nfc.getFirmwareVersion();
  if (!versiondata) {
    DebugPrint("Didn't find PN53x board");
    while (1)
      ;  // halt
  }

  // Got ok data, print it out!
  DebugPrint("Found chip PN5");
  DebugPrintLn((versiondata >> 24) & 0xFF, HEX);
  DebugPrint("Firmware ver. ");
  DebugPrint((versiondata >> 16) & 0xFF, DEC);
  DebugPrint('.');
  DebugPrintLn((versiondata >> 8) & 0xFF, DEC);

  DebugPrintLn("Waiting for an ISO14443A Card ...");
}

void CopyUID(uint8_t uid[], uint8_t uidReturn[], uint8_t uidLength) {
  for (uint8_t i = 0; i < uidLength; i++) {
    uidReturn[i] = uid[i];
  }
}

bool CompareUIDs(uint8_t uidA[], uint8_t uidB[], uint8_t uidLength) {
  bool equal = true;

  for (uint8_t i = 0; i < uidLength; i++) {
    if (uidA[i] != uidB[i]) {
      equal = false;
      break;
    }
  }

  return equal;
}

void MifareClassicReadBlock4(uint8_t uid[], uint8_t uidLength) {
  // We probably have a Mifare Classic card ...
  DebugPrintLn("Seems to be a Mifare Classic card (4 byte UID)");

  // Now we need to try to authenticate it for read/write access
  // Try with the factory default KeyA: 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
  DebugPrintLn("Trying to authenticate block 4 with default KEYA value");
  uint8_t keya[6] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

  // Start with block 4 (the first block of sector 1) since sector 0
  // contains the manufacturer data and it's probably better just
  // to leave it alone unless you know what you're doing
  if (nfc.mifareclassic_AuthenticateBlock(uid, uidLength, 4, 0, keya)) {
    DebugPrintLn("Sector 1 (Blocks 4..7) has been authenticated");
    uint8_t data[16];

    // If you want to write something to block 4 to test with, uncomment
    // the following line and this text should be read back in a minute
    //memcpy(data, (const uint8_t[]){ 'c', 'o', 'o', 'k', 'i', 'e', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, sizeof data);
    //nfc.mifareclassic_WriteDataBlock (4, data);

    // Try to read the contents of block 4
    if (nfc.mifareclassic_ReadDataBlock(4, data)) {
      // Data seems to have been read ... spit it out
      DebugPrintLn("Reading Block 4:");
      //nfc.PrintHexChar(data, 16);
      PrintDataChar(data, 16);
      DebugPrintLn("");

      // Wait a bit before reading the card again
      delay(1000);
    } else {
      DebugPrintLn("Ooops ... unable to read the requested block.  Try another key?");
    }
  } else {
    DebugPrintLn("Ooops ... authentication failed: Try another key?");
  }
}

void MifareUltralightReadBlock4() {
  // We probably have a Mifare Ultralight card ...
  DebugPrintLn("Seems to be a Mifare Ultralight tag (7 byte UID)");

  // Try to read the first general-purpose user page (#4)
  DebugPrintLn("Reading page 4");
  uint8_t data[32];
  if (nfc.mifareultralight_ReadPage(4, data)) {
    // Data seems to have been read ... spit it out
    //nfc.PrintHexChar(data, 4);
    DebugPrintLn("");

    // Wait a bit before reading the card again
    delay(1000);
  } else {
    DebugPrintLn("Ooops ... unable to read the requested page!?");
  }
}

void PrintDataChar(uint8_t data[], uint32_t numBytes) {
  for (int i = 0; i < numBytes; i++){
    if (data[i] > 0x1F) {
      Serial.print((char)data[i]);
    }
  }

  Serial.println();
}