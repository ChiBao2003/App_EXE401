#include <Arduino.h>
#include "io_service.h"
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/queue.h>

namespace {
constexpr int NEXT_PIN=36, OK_PIN=34, BACK_PIN=35, BUZZER_PIN=23;
constexpr int BUZZER_CHANNEL=1, BUZZER_DUTY=128;
struct BeepCommand { int count, onMs, frequency; };
QueueHandle_t keyQueue=nullptr, beepQueue=nullptr;
volatile uint8_t buttonLevels=7;

void ioTask(void*) {
  PressLatch next(25,25), ok(25,25);
  BackKey back;
  BeepSequence beep;
  bool pwmOn=false;
  bool buzzerReady=true;
  int frequency=2700;
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  buzzerReady=ledcAttach(BUZZER_PIN,frequency,8);
#else
  buzzerReady=ledcSetup(BUZZER_CHANNEL,frequency,8)>0;
  if (buzzerReady) ledcAttachPin(BUZZER_PIN,BUZZER_CHANNEL);
#endif
  if (!buzzerReady) Serial.println("[IO] ERROR: buzzer PWM init failed");
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  if (buzzerReady) ledcWrite(BUZZER_PIN,0);
#else
  if (buzzerReady) ledcWrite(BUZZER_CHANNEL,0);
#endif
  Serial.printf("[IO] READY next36=%d ok34=%d back35=%d PWM23=%s (released=1)\n",
                digitalRead(NEXT_PIN),digitalRead(OK_PIN),digitalRead(BACK_PIN),
                buzzerReady?"OK":"FAILED");
  TickType_t wake=xTaskGetTickCount();
  for (;;) {
    const uint32_t now=millis();
    buttonLevels=(digitalRead(NEXT_PIN)?1:0) | (digitalRead(OK_PIN)?2:0) |
                 (digitalRead(BACK_PIN)?4:0);
    KeyEvent events[3]={KeyEvent::None,KeyEvent::None,KeyEvent::None};
    if (next.update(!(buttonLevels&1),now)) events[0]=KeyEvent::Next;
    if (ok.update(!(buttonLevels&2),now)) events[1]=KeyEvent::Ok;
    events[2]=back.update(!(buttonLevels&4),now);
    for (KeyEvent event:events) {
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
      ledcChangeFrequency(BUZZER_PIN,frequency,8);
#else
      ledcChangeFrequency(BUZZER_CHANNEL,frequency,8);
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
  pinMode(NEXT_PIN,INPUT); pinMode(OK_PIN,INPUT); pinMode(BACK_PIN,INPUT);
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
void requestBeep(int count,int onMs,int frequency) {
  if (!beepQueue) return;
  BeepCommand command={constrain(count,0,20),constrain(onMs,10,5000),
                       constrain(frequency,100,10000)};
  xQueueOverwrite(beepQueue,&command);
}
void silenceBuzzer() { requestBeep(0,10,2000); }
uint8_t rawButtonLevels() { return buttonLevels; }
