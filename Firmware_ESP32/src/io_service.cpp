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
struct QueuedKey { KeyEvent event; uint32_t sequence, pressedAt; };
enum class TraceStage : uint8_t { Raw, Stable, Enqueue, QueueFull };
struct InputTrace {
  TraceStage stage;
  uint32_t at, sequence;
  KeyEvent event;
  uint8_t gpio, level;
};
QueueHandle_t keyQueue=nullptr, beepQueue=nullptr, traceQueue=nullptr;
volatile uint8_t buttonLevels=7;
volatile uint32_t traceDropped=0;
uint32_t keySequence=0;

// The 5 ms sampler never waits for UART output. Diagnostics use a separate
// bounded queue, so even raw contact chatter cannot block key delivery.
void traceInput(TraceStage stage,uint32_t at,uint32_t sequence,
                KeyEvent event,uint8_t gpio,uint8_t level) {
  const InputTrace trace={stage,at,sequence,event,gpio,level};
  if (traceQueue && xQueueSend(traceQueue,&trace,0)!=pdTRUE) ++traceDropped;
}

void sampleButtons(NavigationButtons& buttons,uint32_t now) {
  static bool sampled=false;
  static uint8_t previousLevels=7;
  buttonLevels=(digitalRead(MODE_PIN)?1:0) | (digitalRead(OK_PIN)?2:0) |
               (digitalRead(SELECT_PIN)?4:0);
  const uint8_t pins[3]={MODE_PIN,OK_PIN,SELECT_PIN};
  for (uint8_t i=0;i<3;++i) {
    const bool down=!(buttonLevels&(1<<i));
    const bool wasDown=buttons.down(i);
    if (i==1 && (!sampled || ((previousLevels^buttonLevels)&2)))
      traceInput(TraceStage::Raw,now,0,KeyEvent::None,OK_PIN,!down);
    const KeyEvent event=buttons.update(i,down,now);
    if (i==1 && (!sampled || wasDown!=buttons.down(i)))
      traceInput(TraceStage::Stable,now,0,event,OK_PIN,!buttons.down(i));
    if (event==KeyEvent::None) continue;
    const QueuedKey key={event,++keySequence,now};
    const bool sent=xQueueSend(keyQueue,&key,0)==pdTRUE;
    traceInput(sent?TraceStage::Enqueue:TraceStage::QueueFull,
               now,key.sequence,event,pins[i],!down);
  }
  previousLevels=buttonLevels;
  sampled=true;
}

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
    sampleButtons(buttons,now);
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
  keyQueue=xQueueCreate(16,sizeof(QueuedKey));
  beepQueue=xQueueCreate(1,sizeof(BeepCommand));
  if (!keyQueue || !beepQueue) {
    if (keyQueue) { vQueueDelete(keyQueue); keyQueue=nullptr; }
    if (beepQueue) { vQueueDelete(beepQueue); beepQueue=nullptr; }
    return false;
  }
  traceQueue=xQueueCreate(48,sizeof(InputTrace));
  if (!traceQueue) Serial.println("[INPUT] WARNING: diagnostics queue unavailable");
  if (xTaskCreate(ioTask,"smarttime_io",3072,nullptr,2,nullptr)!=pdPASS) {
    vQueueDelete(keyQueue); vQueueDelete(beepQueue);
    keyQueue=nullptr; beepQueue=nullptr;
    if (traceQueue) { vQueueDelete(traceQueue); traceQueue=nullptr; }
    return false;
  }
  return true;
}
bool readKeyEvent(KeyEvent& event) {
  QueuedKey key;
  if (!keyQueue || xQueueReceive(keyQueue,&key,0)!=pdTRUE) return false;
  event=key.event;
  Serial.printf("[KEY DEQUEUE] id=%lu event=%s pressedAt=%lu age=%lu ms\n",
                (unsigned long)key.sequence,keyEventName(event),
                (unsigned long)key.pressedAt,(unsigned long)(millis()-key.pressedAt));
  return true;
}
void serviceInputDiagnostics() {
  InputTrace trace;
  for (int budget=0;budget<6 && traceQueue && xQueueReceive(traceQueue,&trace,0)==pdTRUE;++budget) {
    if (trace.stage==TraceStage::Raw || trace.stage==TraceStage::Stable) {
      Serial.printf("[GPIO34 %s] at=%lu level=%u %s event=%s\n",
                    trace.stage==TraceStage::Raw?"RAW":"STABLE",
                    (unsigned long)trace.at,trace.level,trace.level?"RELEASED":"PRESSED",
                    keyEventName(trace.event));
    } else {
      Serial.printf("[KEY %s] id=%lu at=%lu gpio=%u event=%s\n",
                    trace.stage==TraceStage::Enqueue?"ENQUEUE":"QUEUE_FULL",
                    (unsigned long)trace.sequence,(unsigned long)trace.at,
                    trace.gpio,keyEventName(trace.event));
    }
  }
  static uint32_t reportedDropped=0;
  const uint32_t dropped=traceDropped;
  if (dropped!=reportedDropped) {
    reportedDropped=dropped;
    Serial.printf("[INPUT] Diagnostic records dropped=%lu (key queue is separate)\n",
                  (unsigned long)dropped);
  }
}
void discardKeyEvents() {
  if (!keyQueue) return;
  Serial.printf("[KEY DISCARD] pending=%u reason=alert-dismiss\n",
                unsigned(uxQueueMessagesWaiting(keyQueue)));
  xQueueReset(keyQueue);
}
void requestBeep(int count,int onMs,int frequency) {
  if (!beepQueue) return;
  BeepCommand command={constrain(count,0,20),constrain(onMs,10,5000),
                       constrain(frequency,100,10000)};
  xQueueOverwrite(beepQueue,&command);
}
void silenceBuzzer() { requestBeep(0,10,2000); }
uint8_t rawButtonLevels() { return buttonLevels; }
