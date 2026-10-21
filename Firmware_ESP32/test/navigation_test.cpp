#include "../src/io_service.h"
#include <algorithm>
#include <cstdio>
#include <cstring>
#include <deque>
#include <string>
#include <vector>

// Hardware boundary only: navigation and drawing handlers are extracted
// verbatim from Esp32Pj.ino by extract_navigation.ps1.
enum AppState { MODE_CLOCK, MODE_POMODORO, MODE_TIMER, MODE_BLUETOOTH };
enum PomoPhase { PHASE_WORK, PHASE_BREAK, PHASE_LONG_BREAK };
const int NUM_MODES=4, NUM_TASK_TYPES=4, NUM_PRESETS=8;
const int C_BLACK=0, C_WHITE=0xffff, C_DARK_GRAY=0x2104, C_CYAN=0x7ff,
          C_GREEN=0x7e0, C_RED=0xf800, C_ORANGE=0xfd20, C_MID_GRAY=0x4a49, C_PURPLE=0x780f;
AppState currentState=MODE_CLOCK;
PomoPhase pomoPhase=PHASE_WORK;
bool stateChanged=true, isBluetoothConnected=false, isAlarmActive=false, notifActive=false;
bool pomoSelectingTask=true, pomoRunning=false, timerSelecting=true,
     timerRunning=false, timerFinished=false, rtcFound=false;
int controlFocus=0, currentThemeId=0, lastMinute=-1, selectedTaskTypeIndex=3,
    selectedTimerPreset=0, pomoWorkDuration=1500, pomoTime=1500, pomoInitialTime=1500,
    pauseCount=0, pomoSessionCount=0, lastPomoDraw=-2, timerSeconds=0,
    timerInitial=0, lastTimerDraw=-2;
uint32_t lastBtnPress=0, pomoLastTick=0, timerLastTick=0, nowMs=100;
uint32_t pomoRemainderMs=0, timerRemainderMs=0;
int focusByScreen[6]={-1,3,2,0,0,0};
int pomoBreakDuration=300,pomoLongBreakDuration=900,lastPomoSessionDraw=-2;
PomoPhase lastPomoPhaseDraw=PHASE_WORK;
PressLatch touchLatch(80,150);
const char* taskTypeLabels[]={"Coding","Reading","Study","General"};
const uint16_t taskTypeColors[]={C_CYAN,C_GREEN,C_WHITE,C_ORANGE};
const int timerPresets[]={10,15,30,60,300,600,900,1500};
const char* timerLabels[]={"10s","15s","30s","1m","5m","10m","15m","25m"};
std::string current_pomo_task_type="General";
char pomoStartTimeStr[25]={0};
struct DateTime {
  int year(){return 2026;} int month(){return 1;} int day(){return 1;}
  int hour(){return 12;} int minute(){return 0;} int second(){return 0;}
};
struct Rtc { bool lostPower(){return false;} DateTime now(){return {};} } rtc;
struct SerialMock {
  std::string log;
  template<class... T> void printf(const char* format,T... args) {
    char line[512]; std::snprintf(line,sizeof(line),format,args...); log+=line;
  }
  void println(const char* line){log+=line; log+='\n';}
} Serial;
struct Prefs { int writes=0; void putInt(const char*,int){++writes;} } prefs;
struct Audio {
  bool connected=false;
  int prevCalls=0, playCalls=0, nextCalls=0;
  bool is_connected(){return connected;}
  void previous(){++prevCalls;} void play(){++playCalls;} void next(){++nextCalls;}
} a2dp_sink;
struct Rect { int x,y,w,h; };
struct Display {
  int fullClears=0;
  std::vector<Rect> fills;
  std::string text;
  void clearLog(){fullClears=0; fills.clear(); text.clear();}
  void fillScreen(int){++fullClears;}
  void fillRect(int x,int y,int w,int h,int){fills.push_back({x,y,w,h});}
  void fillRoundRect(int,int,int,int,int,int){}
  std::vector<Rect> outlines;
  void drawRoundRect(int x,int y,int w,int h,int,int){outlines.push_back({x,y,w,h});}
  void setTextSize(int){} void setTextColor(int,int=0){} void setCursor(int,int){}
  void print(const char* s){text+=s;}
  void print(int n){text+=std::to_string(n);}
} tft;
uint32_t millis(){return nowMs;}
int constrain(int n,int low,int high){return std::max(low,std::min(high,n));}
// Simulate FreeRTOS's byte-copy queue, not readKeyEvent or the GPIO sampler.
struct FakeQueue { size_t capacity,itemSize; std::deque<std::vector<uint8_t>> items; };
using QueueHandle_t=FakeQueue*;
const int pdTRUE=1;
QueueHandle_t xQueueCreate(size_t capacity,size_t itemSize){return new FakeQueue{capacity,itemSize,{}};}
int xQueueSend(QueueHandle_t q,const void* item,int){
  if(!q || q->items.size()>=q->capacity)return 0;
  const auto bytes=static_cast<const uint8_t*>(item);
  q->items.emplace_back(bytes,bytes+q->itemSize);return pdTRUE;
}
int xQueueReceive(QueueHandle_t q,void* item,int){
  if(!q || q->items.empty())return 0;
  memcpy(item,q->items.front().data(),q->itemSize);q->items.pop_front();return pdTRUE;
}
void xQueueReset(QueueHandle_t q){q->items.clear();}
unsigned uxQueueMessagesWaiting(QueueHandle_t q){return unsigned(q->items.size());}
int gpioLevels[40]={0};
int digitalRead(int pin){return gpioLevels[pin];}
#include "../.pio/io_under_test.inc"
int silenceCalls=0, beepCalls=0, completedSends=0, cancelledSends=0;
void stopBuzzer(){++silenceCalls;}
void startBeep(int,int,int){++beepCalls;}
void sendPomodoroData(bool completed){if(completed)++completedSends;else ++cancelledSends;}
void resetPomodoro(); void resetTimerToSelection();
void drawTimerStartPauseButton(bool); void updateSelectionOutline(bool,int,int);
void syncControlFocus();
#include "../.pio/navigation_under_test.inc"

int failures=0,checks=0;
void check(bool ok,const char* name){++checks;printf("%s: %s\n",ok?"PASS":"FAIL",name);if(!ok)++failures;}
void queueKey(KeyEvent e){const QueuedKey key={e,++keySequence,nowMs};xQueueSend(keyQueue,&key,0);}
void press(KeyEvent e){queueKey(e);handleButtons();}
void render(){syncControlFocus();drawControlFocus(stateChanged);stateChanged=false;}
void resetFixture() {
  currentState=MODE_CLOCK;pomoPhase=PHASE_WORK;stateChanged=true;
  isBluetoothConnected=false;isAlarmActive=false;notifActive=false;
  pomoSelectingTask=true;pomoRunning=false;timerSelecting=true;
  timerRunning=false;timerFinished=false;rtcFound=false;
  controlFocus=0;currentThemeId=0;selectedTaskTypeIndex=3;selectedTimerPreset=0;
  pomoWorkDuration=1500;pomoTime=pomoInitialTime=1500;
  pomoBreakDuration=300;pomoLongBreakDuration=900;
  pauseCount=pomoSessionCount=0;lastPomoDraw=lastTimerDraw=-2;
  timerSeconds=timerInitial=0;pomoRemainderMs=timerRemainderMs=0;
  nowMs=1000;pomoLastTick=timerLastTick=nowMs;
  const int focus[6]={-1,3,2,0,0,0};std::copy(focus,focus+6,focusByScreen);
  current_pomo_task_type="General";pomoStartTimeStr[0]=0;
  a2dp_sink.connected=false;a2dp_sink.prevCalls=a2dp_sink.playCalls=a2dp_sink.nextCalls=0;
  silenceCalls=beepCalls=completedSends=cancelledSends=prefs.writes=0;
  if(!keyQueue)keyQueue=xQueueCreate(16,sizeof(QueuedKey));
  if(!traceQueue)traceQueue=xQueueCreate(48,sizeof(InputTrace));
  xQueueReset(keyQueue);xQueueReset(traceQueue);traceDropped=0;
  gpioLevels[36]=gpioLevels[34]=gpioLevels[35]=1;buttonLevels=7;
  tft.clearLog();tft.outlines.clear();
  Serial.log.clear();
}
void enter(AppState screen) {currentState=screen;stateChanged=true;syncControlFocus();}
void clockRoundTrip() {for(int i=0;i<4;++i)press(KeyEvent::Mode);}
int main(){
  // GPIO34's second press must START the task selected by the first OK.
  resetFixture();enter(MODE_POMODORO);press(KeyEvent::Select);
  check(controlFocus==0 && pomoSelectingTask && current_pomo_task_type=="General",
        "SELECT focuses Coding without confirming");
  press(KeyEvent::Ok);
  check(!pomoSelectingTask && current_pomo_task_type=="Coding" && selectedTaskTypeIndex==0 &&
        controlFocus==2 && !pomoRunning,"first OK confirms Coding and focuses START/PAUSE");
  press(KeyEvent::Ok);
  check(pomoRunning && !pomoSelectingTask && current_pomo_task_type=="Coding",
        "second OK starts Coding Pomodoro");
  nowMs+=1000;updateBackgroundTimers();
  check(pomoTime==1499,"Coding countdown advances after second OK");
  check(Serial.log.find("screen=TASK_SELECT controlFocus=0(Coding)")!=std::string::npos &&
        Serial.log.find("[NAV ACTIVATE]")!=std::string::npos &&
        Serial.log.find("screen=POMODORO_CONTROLS controlFocus=2(START/PAUSE) task=Coding running=1")!=std::string::npos,
        "OK trace includes received screen/focus, activation and resulting running state");
  resetFixture();
  press(KeyEvent::Select);render();
  check(controlFocus==1 && currentThemeId==0 && prefs.writes==0,
        "first SELECT changes theme focus only");
  press(KeyEvent::Ok);
  check(currentThemeId==1 && prefs.writes==1,"OK confirms focused theme and saves NVS once");
  press(KeyEvent::Select);clockRoundTrip();
  check(currentState==MODE_CLOCK && controlFocus==2 && currentThemeId==1,
        "MODE round trip preserves pending theme and confirmed theme separately");
  const int focusBefore=controlFocus;drawControlFocus(true);
  check(controlFocus==focusBefore,"drawing never changes focus");
  for(int theme: {0,2}) {
    currentThemeId=theme;tft.clearLog();drawControlFocus(true);
    bool coversDate=false;for(auto r:tft.fills) if(r.y<22)coversDate=true;
    check(!coversDate,"theme focus does not cover date/temperature");
  }
  tft.clearLog();drawNavigationHelp();
  check(tft.text=="MODE: MAN HINH | SELECT: DI CHUYEN | OK: CHON","navigation help matches required labels");

  // MODE is independent of every sub-screen and does not cancel sessions.
  resetFixture();
  for(bool selecting: {true,false}) {
    for(int i=0;i<4;++i) {
      pomoSelectingTask=timerSelecting=selecting;
      pomoRunning=timerRunning=!selecting;pomoTime=123;timerSeconds=45;
      enter(static_cast<AppState>(i));press(KeyEvent::Mode);
      check(currentState==static_cast<AppState>((i+1)%4) && pomoTime==123 && timerSeconds==45 &&
            pomoRunning==!selecting && timerRunning==!selecting && cancelledSends==0,
            "MODE cycles screens without resetting or stopping sessions");
    }
  }

  resetFixture();enter(MODE_POMODORO);press(KeyEvent::Ok);render();
  check(!pomoSelectingTask && selectedTaskTypeIndex==3 && current_pomo_task_type=="General",
        "OK on initial General confirms General");
  resetFixture();enter(MODE_POMODORO);tft.clearLog();press(KeyEvent::Select);render();
  check(controlFocus==0 && selectedTaskTypeIndex==3 && current_pomo_task_type=="General" &&
        pomoSelectingTask && tft.fullClears==0,"General -> Coding focus does not confirm or clear screen");
  press(KeyEvent::Select);clockRoundTrip();
  check(controlFocus==1 && pomoSelectingTask,"task focus survives MODE round trip");
  press(KeyEvent::Ok);render();
  check(current_pomo_task_type=="Reading" && selectedTaskTypeIndex==1 && controlFocus==2,
        "OK confirms Reading and opens Pomodoro at Start");
  press(KeyEvent::Ok);check(pomoRunning,"OK on Start starts");
  press(KeyEvent::Select);
  check(controlFocus==3 && pomoRunning && cancelledSends==0,"SELECT on running Pomodoro only focuses Reset");
  press(KeyEvent::Select);press(KeyEvent::Ok);
  check(controlFocus==0 && pomoRunning && pomoWorkDuration==1800 && pomoTime==1500,
        "OK on +5m never toggles Start/Pause");
  press(KeyEvent::Select);press(KeyEvent::Ok);
  check(pomoWorkDuration==1500 && pomoRunning,"OK on -5m acts on duration only");
  press(KeyEvent::Select);press(KeyEvent::Ok);
  check(!pomoRunning && pauseCount==1,"OK on Pause pauses once");
  setControlFocus(0);pomoWorkDuration=5400;press(KeyEvent::Ok);
  check(pomoWorkDuration==5400,"+5m has a 90 minute limit");
  setControlFocus(1);pomoWorkDuration=300;press(KeyEvent::Ok);
  check(pomoWorkDuration==300,"-5m has a 5 minute limit");
  pomoTime=250;setControlFocus(3);press(KeyEvent::Ok);render();
  check(pomoSelectingTask && !pomoRunning && cancelledSends==1 && controlFocus==1,
        "Reset ends session once and preserves previous task focus");

  resetFixture();enter(MODE_TIMER);setControlFocus(7);press(KeyEvent::Select);
  check(controlFocus==0 && timerSelecting && !timerRunning,"preset SELECT wraps without starting");
  setControlFocus(2);clockRoundTrip();
  check(controlFocus==2 && timerSelecting,"preset focus survives screen changes");
  press(KeyEvent::Ok);render();
  check(timerSeconds==30 && selectedTimerPreset==2 && timerRunning && controlFocus==0,
        "OK starts the focused preset");
  check(Serial.log.find("timerRunning=1 timerRemaining=30 timerSelecting=0")!=std::string::npos,
        "Timer trace reports its own running/remaining/selection state");
  press(KeyEvent::Ok);check(!timerRunning,"timer Pause pauses");
  press(KeyEvent::Ok);check(timerRunning,"timer Resume resumes");
  press(KeyEvent::Select);clockRoundTrip();
  check(controlFocus==1 && timerRunning,"timer Stop focus and running state survive round trip");
  press(KeyEvent::Ok);render();
  check(timerSelecting && !timerRunning && controlFocus==2,"Stop returns to the same preset focus");

  resetFixture();enter(MODE_BLUETOOTH);press(KeyEvent::Select);
  check(controlFocus==-1 && focusByScreen[5]==0 && beepCalls==0,"SELECT is inert on disconnected Bluetooth");
  press(KeyEvent::Ok);check(a2dp_sink.playCalls==0,"OK is inert on disconnected Bluetooth");
  a2dp_sink.connected=true;press(KeyEvent::Ok);press(KeyEvent::Select);press(KeyEvent::Ok);
  press(KeyEvent::Select);press(KeyEvent::Ok);clockRoundTrip();
  check(a2dp_sink.prevCalls==1 && a2dp_sink.playCalls==1 && a2dp_sink.nextCalls==1 && controlFocus==2,
        "Bluetooth PREV/PLAY/NEXT execute only on OK and keep focus");
  press(KeyEvent::Select);check(controlFocus==0,"Bluetooth SELECT wraps");

  // Actual touch hit testing and physical keys share action implementations.
  resetFixture();enter(MODE_POMODORO);handleTouchAt(240,180);render();
  check(current_pomo_task_type=="General" && controlFocus==2,"touch General uses the confirmation action");
  handleTouchAt(250,35);check(pomoWorkDuration==1800 && controlFocus==0 && !pomoRunning,
                           "touch +5m updates focus and duration without starting");
  handleTouchAt(250,90);check(pomoWorkDuration==1500 && controlFocus==1,"touch -5m matches OK");
  handleTouchAt(250,150);check(pomoRunning && controlFocus==2,"touch Start matches OK");
  handleTouchAt(250,205);render();
  check(pomoSelectingTask && cancelledSends==1,"touch Reset matches OK and queues cancellation");
  enter(MODE_TIMER);handleTouchAt(180,70);render();
  check(selectedTimerPreset==2 && timerSeconds==30 && timerLastTick==nowMs && timerRunning,
        "touch preset matches OK including timestamp and confirmed index");
  handleTouchAt(70,180);check(!timerRunning && controlFocus==0,"touch Pause matches OK");
  handleTouchAt(70,180);check(timerRunning,"touch Resume matches OK");
  handleTouchAt(220,180);render();check(timerSelecting && controlFocus==2,"touch Stop preserves preset focus");
  enter(MODE_BLUETOOTH);a2dp_sink.connected=true;handleButtons();
  handleTouchAt(40,180);handleTouchAt(150,180);handleTouchAt(260,180);
  check(a2dp_sink.prevCalls==1 && a2dp_sink.playCalls==1 && a2dp_sink.nextCalls==1,
        "touch Bluetooth actions match OK");
  handleTouchAt(20,235);check(currentState==MODE_CLOCK,"touch MODE footer uses same navigation");
  handleTouchAt(150,235);check(controlFocus==1 && currentThemeId==0,"touch SELECT footer only moves focus");
  handleTouchAt(280,235);check(currentThemeId==1,"touch OK footer confirms focus");

  // Both clocks continue even when only Clock or Bluetooth is rendered.
  resetFixture();pomoSelectingTask=timerSelecting=false;pomoRunning=timerRunning=true;
  pomoTime=timerSeconds=10;pomoInitialTime=timerInitial=10;
  nowMs=4500;updateBackgroundTimers();
  check(pomoTime==7 && timerSeconds==7 && currentState==MODE_CLOCK &&
        pomoLastTick==4000 && timerLastTick==4000,"both counters run in background with millisecond remainder");
  enter(MODE_BLUETOOTH);nowMs=7000;updateBackgroundTimers();
  check(pomoTime==4 && timerSeconds==4,"both counters catch up while viewing Bluetooth");
  const int beforeDraw=pomoTime;enter(MODE_POMODORO);runPomodoroMode();
  enter(MODE_TIMER);runTimerMode();
  check(pomoTime==beforeDraw && timerSeconds==4,"renderers never tick counters twice");
  pomoRunning=false;nowMs=11000;updateBackgroundTimers();
  const int beepsAtFinish=beepCalls;
  check(timerFinished && !timerRunning && timerSeconds==0,"timer finishes at zero in background, without extra second");
  nowMs=12000;updateBackgroundTimers();
  check(beepCalls==beepsAtFinish,"timer completion beep is emitted once");
  stateChanged=true;runTimerMode();tft.clearLog();runTimerMode();
  check(tft.fills.empty(),"finished timer does not flicker by repainting every loop");

  resetFixture();pomoSelectingTask=false;pomoRunning=true;pomoTime=pomoInitialTime=2;
  pomoWorkDuration=4;pomoBreakDuration=3;nowMs=7000;updateBackgroundTimers();
  check(pomoPhase==PHASE_WORK && pomoTime==3 && pomoSessionCount==1 && completedSends==1 &&
        currentState==MODE_CLOCK,"background catch-up crosses work/break boundaries and sends one completed session");
  resetFixture();pomoSelectingTask=false;pomoRunning=true;pomoTime=1;pomoSessionCount=3;
  pomoLongBreakDuration=7;nowMs=2000;updateBackgroundTimers();
  check(pomoPhase==PHASE_LONG_BREAK && pomoTime==7 && completedSends==1,"fourth background session enters long break");

  resetFixture();enter(MODE_POMODORO);press(KeyEvent::Ok);press(KeyEvent::Ok);
  nowMs=1400;press(KeyEvent::Ok);nowMs=6400;updateBackgroundTimers();
  check(pomoTime==1500 && !pomoRunning,"paused Pomodoro stays paused in background");
  press(KeyEvent::Ok);nowMs=7000;updateBackgroundTimers();
  check(pomoTime==1499,"Pomodoro resume preserves 400 ms elapsed before pause");
  resetFixture();enter(MODE_TIMER);press(KeyEvent::Ok);nowMs=1400;press(KeyEvent::Ok);
  nowMs=6400;updateBackgroundTimers();check(timerSeconds==10,"paused Timer does not tick");
  press(KeyEvent::Ok);nowMs=7000;updateBackgroundTimers();
  check(timerSeconds==9,"Timer resume preserves partial second");
  resetFixture();pomoSelectingTask=timerSelecting=false;pomoRunning=timerRunning=true;
  pomoTime=timerSeconds=5;pomoLastTick=timerLastTick=0xffffff00u;nowMs=0xab8u;
  updateBackgroundTimers();check(pomoTime==2 && timerSeconds==2,"both background clocks handle millis rollover");

  for(KeyEvent event: {KeyEvent::Mode,KeyEvent::Select,KeyEvent::Ok}) {
    resetFixture();syncControlFocus();setControlFocus(1);isAlarmActive=notifActive=true;
    queueKey(event);queueKey(KeyEvent::Ok);handleButtons();
    check(currentState==MODE_CLOCK && currentThemeId==0 && controlFocus==1 &&
          !isAlarmActive && !notifActive && silenceCalls==1 && beepCalls==0 && uxQueueMessagesWaiting(keyQueue)==0,
          "first physical contact only dismisses alert and silences buzzer");
  }
  resetFixture();notifActive=true;handleTouchAt(20,235);
  check(currentState==MODE_CLOCK && !notifActive && silenceCalls==1,"first touch only dismisses notification");
  handleTouchAt(20,235);check(currentState==MODE_POMODORO,"next touch can change screen after dismissal");
  resetFixture();pomoSelectingTask=timerSelecting=false;pomoRunning=timerRunning=true;
  pomoTime=timerSeconds=5;notifActive=true;nowMs=3000;updateBackgroundTimers();
  check(pomoTime==3 && timerSeconds==3 && notifActive,"notifications do not pause background timers");

  // Full production route: digitalRead -> 25 ms debounce -> xQueueSend ->
  // readKeyEvent -> handleNavigationEvent -> activateFocusedControl.
  resetFixture();enter(MODE_POMODORO);
  NavigationButtons physical;
  auto sample=[&](uint32_t ms){
    nowMs=ms;sampleButtons(physical,nowMs);updateBackgroundTimers();handleButtons();
  };
  sample(1000);
  gpioLevels[35]=0;sample(1010);sample(1034);
  check(controlFocus==3,"GPIO35 chatter under 25 ms does not change focus");
  sample(1035);gpioLevels[35]=1;sample(1040);sample(1065);
  check(controlFocus==0 && pomoSelectingTask,"physical SELECT35 focuses Coding");
  gpioLevels[34]=0;sample(1070);gpioLevels[34]=1;sample(1080);
  gpioLevels[34]=0;sample(1090);sample(1114);
  check(pomoSelectingTask,"GPIO34 bounce does not confirm before 25 ms stable");
  sample(1115);
  check(!pomoSelectingTask && current_pomo_task_type=="Coding" && !pomoRunning && controlFocus==2,
        "GPIO34 -> debounce -> real queue/readKeyEvent -> confirms Coding");
  sample(4000);
  check(!pomoRunning,"holding first OK does not also start Pomodoro");
  gpioLevels[34]=1;sample(4010);sample(4035);
  check(!pomoRunning,"releasing first OK does not start Pomodoro");
  gpioLevels[34]=0;sample(4040);sample(4065);
  check(pomoRunning,"second physical GPIO34 press starts Coding");
  gpioLevels[34]=1;sample(4070);sample(4095);sample(5065);
  check(pomoTime==1499 && pomoRunning,"release produces no extra action and countdown advances");
  check(Serial.log.find("[GPIO34 RAW]")!=std::string::npos &&
        Serial.log.find("[GPIO34 STABLE]")!=std::string::npos &&
        Serial.log.find("[KEY ENQUEUE]")!=std::string::npos &&
        Serial.log.find("[KEY DEQUEUE]")!=std::string::npos &&
        Serial.log.find("event=OK")!=std::string::npos,
        "raw/stable/queue/consumer OK diagnostics cover entire physical route");
  // A full diagnostic queue must never prevent an OK from reaching the UI.
  xQueueReset(traceQueue);
  for(int i=0;i<60;++i)traceInput(TraceStage::Raw,nowMs,0,KeyEvent::None,34,1);
  gpioLevels[34]=0;nowMs=5100;sampleButtons(physical,nowMs);
  nowMs=5125;sampleButtons(physical,nowMs);
  check(uxQueueMessagesWaiting(keyQueue)==1 && traceDropped>0,
        "diagnostics overflow cannot block the independent OK event queue");
  handleButtons();check(!pomoRunning,"OK still pauses when diagnostics overflow");
  xQueueReset(keyQueue);xQueueReset(traceQueue);
  for(int i=0;i<16;++i)queueKey(KeyEvent::Select);
  gpioLevels[34]=1;nowMs=5200;sampleButtons(physical,nowMs);
  nowMs=5225;sampleButtons(physical,nowMs);
  gpioLevels[34]=0;nowMs=5300;sampleButtons(physical,nowMs);
  nowMs=5325;sampleButtons(physical,nowMs);serviceInputDiagnostics();
  check(Serial.log.find("[KEY QUEUE_FULL]")!=std::string::npos,
        "actual key queue overflow is explicitly reported");
  printf("Navigation checks: %d, failures: %d\n",checks,failures);
  return failures?1:0;
}
