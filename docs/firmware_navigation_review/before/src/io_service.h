#pragma once
#include "io_logic.h"
bool beginIoService();
bool readKeyEvent(KeyEvent& event);
void requestBeep(int count, int onMs, int frequency);
void silenceBuzzer();
uint8_t rawButtonLevels(); // bit0=NEXT36, bit1=OK34, bit2=BACK35; released=1
