#pragma once
#include "io_logic.h"
constexpr uint8_t BUTTON_MODE_PIN=36, BUTTON_OK_PIN=34, BUTTON_SELECT_PIN=35;
bool beginIoService();
bool readKeyEvent(KeyEvent& event);
void serviceInputDiagnostics();
void discardKeyEvents();
void requestBeep(int count, int onMs, int frequency);
void silenceBuzzer();
uint8_t rawButtonLevels(); // bit0=MODE36, bit1=OK34, bit2=SELECT35; released=1
