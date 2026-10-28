#include <Arduino.h>
#include "io_service.h"
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/queue.h>

namespace {
constexpr int MODE_PIN=BUTTON_MODE_PIN, OK_PIN=BUTTON_OK_PIN,
              SELECT_PIN=BUTTON_SELECT_PIN, BUZZER_PIN=23;
constexpr int BUZZER_CHANNEL=4, BUZZER_RESOLUTION=10, BUZZER_DUTY=512;
struct BeepCommand { int count, onMs, frequency; };
QueueHandle_t keyQueue=nullptr, beepQueue=nullptr;
volatile uint8_t buttonLevels=7;

void ioTask(void*) {
  NavigationButtons buttons;
  BeepSequence beep;
  bool pwmOn=false;
  bool buzzerReady=true;
  int frequency=2700;
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  buzzerReady=ledcAttach(BUZZER_PIN,frequency,BUZZER_RESOLUTION);
#else
  buzzerReady=ledcSetup(BUZZER_CHANNEL,frequency,BUZZER_RESOLUTION)>0;
  if (buzzerReady) ledcAttachPin(BUZZER_PIN,BUZZER_CHANNEL);
#endif
  if (!buzzerReady) Serial.println("[IO] ERROR: buzzer PWM init failed");
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  if (buzzerReady) ledcWrite(BUZZER_PIN,0);
#else
  if (buzzerReady) ledcWrite(BUZZER_CHANNEL,0);
#endif
  Serial.printf("[IO] READY MODE36=%d OK34=%d SELECT35=%d PWM23=%s (released=1)\n",
                digitalRead(MODE_PIN),digitalRead(OK_PIN),digitalRead(SELECT_PIN),
                buzzerReady?"OK":"FAILED");
  TickType_t wake=xTaskGetTickCount();
  for (;;) {
    const uint32_t now=millis();
    buttonLevels=(digitalRead(MODE_PIN)?1:0) | (digitalRead(OK_PIN)?2:0) |
                 (digitalRead(SELECT_PIN)?4:0);
    KeyEvent events[3]={KeyEvent::None,KeyEvent::None,KeyEvent::None};
    for (uint8_t i=0;i<3;++i)
      events[i]=buttons.update(i,!(buttonLevels&(1<<i)),now);
    for (KeyEvent event:events) {
      if (event!=KeyEvent::None)
        Serial.printf("[IO] key=%u at=%lu raw=0x%X\n", unsigned(event),
                      (unsigned long)now, buttonLevels);
      if (event!=KeyEvent::None && xQueueSend(keyQueue,&event,0)!=pdTRUE)
        Serial.println("[IO] WARNING: key event queue full");
    }
    BeepCommand command;
    bool changedFrequency=false;
    if (xQueueReceive(beepQueue,&command,0)==pdTRUE) {
      if (command.count<=0) beep.stop();
      else {
        changedFrequency=frequency!=command.frequency;
        frequency=command.frequency;
        beep.start(command.count,command.onMs,now);
      }
    }
    if (changedFrequency && buzzerReady) {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
      ledcWriteTone(BUZZER_PIN,frequency);
#else
      ledcWriteTone(BUZZER_CHANNEL,frequency);
#endif
    }
    bool on=beep.tick(now);
    if (buzzerReady && (on!=pwmOn || changedFrequency)) {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
      ledcWrite(BUZZER_PIN,on?BUZZER_DUTY:0);
#else
      ledcWrite(BUZZER_CHANNEL,on?BUZZER_DUTY:0);
#endif
    }
    pwmOn=on;
    vTaskDelayUntil(&wake,pdMS_TO_TICKS(5));
  }
}
}

bool beginIoService() {
  pinMode(MODE_PIN,INPUT); pinMode(OK_PIN,INPUT); pinMode(SELECT_PIN,INPUT);
  pinMode(BUZZER_PIN,OUTPUT); digitalWrite(BUZZER_PIN,LOW);
  keyQueue=xQueueCreate(16,sizeof(KeyEvent));
  beepQueue=xQueueCreate(1,sizeof(BeepCommand));
  if (!keyQueue || !beepQueue) {
    if (keyQueue) { vQueueDelete(keyQueue); keyQueue=nullptr; }
    if (beepQueue) { vQueueDelete(beepQueue); beepQueue=nullptr; }
    return false;
  }
  if (xTaskCreate(ioTask,"smarttime_io",3072,nullptr,2,nullptr)!=pdPASS) {
    vQueueDelete(keyQueue); vQueueDelete(beepQueue);
    keyQueue=nullptr; beepQueue=nullptr;
    return false;
  }
  return true;
}
bool readKeyEvent(KeyEvent& event) {
  return keyQueue && xQueueReceive(keyQueue,&event,0)==pdTRUE;
}
void discardKeyEvents() { if (keyQueue) xQueueReset(keyQueue); }
void requestBeep(int count,int onMs,int frequency) {
  if (!beepQueue) return;
  BeepCommand command={constrain(count,0,20),constrain(onMs,10,5000),
                       constrain(frequency,100,10000)};
  xQueueOverwrite(beepQueue,&command);
}
void silenceBuzzer() { requestBeep(0,10,2000); }
uint8_t rawButtonLevels() { return buttonLevels; }
