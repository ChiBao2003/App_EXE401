#include <SPI.h>
#include <Adafruit_GFX.h>
#include <Wire.h>
#include "RTClib.h"
#include <MCUFRIEND_kbv.h>
#include <TouchScreen.h>
#include "BluetoothA2DPSink.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <LittleFS.h>
#include <freertos/queue.h>
#include "input_latch.h"
#include "io_service.h"

// Data structures
constexpr int MAX_ALARMS = 8;
struct AlarmEntry {
  uint8_t hour, minute, days;
  bool enabled;
  char label[32];
};

// Forward declarations
void startBeep(int times, int onMs, int freq);
void handleBuzzer();
void triggerNotification(const char* title, const char* body);
void saveAlarmConfig();
void loadAlarmConfig();
void resetPomodoro();
void activateFocusedControl();
void syncControlFocus();
void sendPomoState(bool ok = true);
void applyRemotePomoControl();
void resetTimerToSelection();
void drawPomodoroStartPauseButton(bool running);
void drawTimerStartPauseButton(bool running);
void sendPomodoroData(bool completed);
void stopBuzzer();
void initPomodoroQueue();
bool enqueuePomodoro(const char* jsonStr, const char* sessionId);
void processPomodoroQueue();
void handlePomoAck(const char* ackSessionId);


// ==========================================
// ENABLE_WIFI_MQTT: Bo comment dong duoi de bat WiFi+MQTT
// CHU Y: Bat WiFi khi A2DP dang stream co the gay crash.
// Nen chi bat khi khong su dung Bluetooth Audio.
// ==========================================
// #define ENABLE_WIFI_MQTT
#ifdef ENABLE_WIFI_MQTT
  #include "wifi_mqtt_manager.h"
#endif

// ==========================================
// CẤU HÌNH PHẦN CỨNG 
// ==========================================
MCUFRIEND_kbv tft;
RTC_DS3231 rtc;
bool rtcFound = false;
BluetoothA2DPSink a2dp_sink;
Preferences prefs;
bool layoutFsReady = false;

// ==========================================
// HÀNG ĐỢI FIFO POMODORO BỀN VỮNG TRÊN NVS (Tối đa 5 phiên)
// ==========================================
#define MAX_POMO_QUEUE 5
int  pomoQueueCount = 0;
int  pomoQueueHead  = 0;
int  pomoQueueTail  = 0;
bool waitingForPomoAck = false;
String currentPomoAckId = "";
unsigned long lastPomoSendTime = 0;
const unsigned long POMO_ACK_TIMEOUT_MS = 8000;
String pomoTransmitJson;
size_t pomoTransmitOffset = 0;
size_t pomoFragmentBytes = 16;
uint8_t pomoTransferSequence = 0;
uint8_t pomoFragmentIndex = 0;
unsigned long lastPomoFragmentTime = 0;

// ==========================================
// BLE GATT SERVER (Kenh du lieu JSON)
// ==========================================
#define BLE_SERVICE_UUID  "0000ffe0-0000-1000-8000-00805f9b34fb"
#define BLE_RX_UUID       "0000ffe1-0000-1000-8000-00805f9b34fb"  // App -> ESP32
#define BLE_TX_UUID       "0000ffe2-0000-1000-8000-00805f9b34fb"  // ESP32 -> App

BLEServer*         pBleServer     = nullptr;
BLECharacteristic* pBleRxChar     = nullptr;
BLECharacteristic* pBleTxChar     = nullptr;
bool               bleClientConnected = false;
bool               checkPendingPomo   = false;

// JSON duoc nhan qua BLE, can xu ly trong loop()
QueueHandle_t bleCommandQueue = nullptr;


// Cấu hình chân Cảm ứng
const int XP = 27, XM = 15, YP = 4, YM = 14;
const int TS_LEFT = 920, TS_RT = 150, TS_TOP = 940, TS_BOT = 120;
TouchScreen ts = TouchScreen(XP, YP, XM, YM, 300);
bool touchEnabled = true;
PressLatch touchLatch(80,150);

// Cấu hình chân Nút bấm 
#define BTN_MODE    BUTTON_MODE_PIN
#define BTN_ACTION1 BUTTON_OK_PIN
#define BTN_ACTION2 BUTTON_SELECT_PIN

// MODE=34, OK=35, SELECT=36. External pull-ups required.
int controlFocus=0;
int focusByScreen[6]={-1,3,2,0,0,0};

// I2S wiring verified by the working hardware test: BCLK=5, DIN=19, LRC=18.
#define I2S_BCLK 5
#define I2S_LRC  18
#define I2S_DOUT 19

// Còi báo Buzzer (Chốt GPIO 23, KHUYÊN DÙNG: Nối tiếp trở 220 Ohm)
#define BUZZER_PIN 23
// PWM duty and channel are configured in io_service.cpp.

// Bảng màu giao diện
#define C_BLACK      0x0000
#define C_WHITE      0xFFFF
#define C_DARK_GRAY  0x2104
#define C_MID_GRAY   0x4A49
#define C_CYAN       0x07FF
#define C_YELLOW     0xFFE0
#define C_ORANGE     0xFD20
#define C_RED        0xF800
#define C_GREEN      0x07E0
#define C_PURPLE     0x780F
#define C_BLUE       0x051D

// ==========================================
// QUẢN LÝ TRẠNG THÁI CHUNG
// ==========================================
enum AppState {
  MODE_CLOCK = 0,
  MODE_POMODORO = 1,
  MODE_TIMER = 2,
  MODE_BLUETOOTH = 3
};
const int NUM_MODES = 4;
AppState currentState = MODE_CLOCK;
bool stateChanged = true;

// == THEME STATE ==
int currentThemeId = 0;
uint16_t currentThemeColor = C_CYAN;
bool themeHasAnim = false;

// Layout sent by the Flutter designer. The TFT is 320x240 in rotation 1.
// Keep the transfer small enough for one BLE ATT write per element.
constexpr int MAX_LAYOUT_ITEMS = 12;
struct LayoutItem {
  char type[12];
  char text[260];
  char shape[12];
  int16_t x, y, w, h;
  uint8_t size;
  uint16_t color;
  bool invert;
  bool fill;
  bool autoFit;
  bool chunked;
  uint16_t byteLength;
};
LayoutItem layoutItems[MAX_LAYOUT_ITEMS];
LayoutItem stagedLayoutItems[MAX_LAYOUT_ITEMS];
int layoutCount = 0;
int pendingLayoutCount = 0;
int layoutRefreshSeconds = 60;
int pendingLayoutRefreshSeconds = 60;
bool customLayoutActive = false;
uint16_t layoutBackground = 0, pendingLayoutBackground = 0;
constexpr size_t LAYOUT_BACKGROUND_BYTES = 9600;
uint8_t layoutBitmapBackground[LAYOUT_BACKGROUND_BYTES];
uint8_t stagedBitmapBackground[LAYOUT_BACKGROUND_BYTES];
bool layoutBitmapBackgroundActive = false;
bool layoutBitmapBackgroundReady = false;
bool stagedLayoutBitmapBackgroundReady = false;
bool pendingLayoutBitmapBackground = false;
bool bitmapTransferActive = false;
size_t bitmapTransferBytes = 0;
uint16_t bitmapExpectedCrc = 0;
uint8_t stagedItemBitmap[LAYOUT_BACKGROUND_BYTES];
size_t itemBitmapBytes = 0, itemBitmapExpected = 0;
int itemBitmapIndex = -1;
bool itemBitmapTransferActive = false;
uint16_t itemBitmapExpectedCrc = 0;
String commandRequestId;
StaticJsonDocument<4096> stagedSchedule;
String stagedScheduleDay;
bool scheduleTransferActive = false;
bool layoutTransferActive = false;

void sendReply(JsonDocument& reply) {
  if (!bleClientConnected || !pBleTxChar) return;
  reply["rid"] = commandRequestId;
  String wire; serializeJson(reply, wire);
  pBleTxChar->setValue(wire.c_str());
  pBleTxChar->notify();
}
void sendDisplayState(bool ok = true) {
  StaticJsonDocument<384> reply;
  reply["type"] = "display_state"; reply["ok"] = ok;
  reply["mode"] = (int)currentState; reply["theme_id"] = currentThemeId;
  reply["color"] = currentThemeColor; reply["custom"] = customLayoutActive;
  reply["layout_count"] = layoutCount;
  sendReply(reply);
}
bool validScheduleDay(const char* day) {
  const char* days[] = {"Mon","Tue","Wed","Thu","Fri","Sat","Sun"};
  for (const char* code : days) if (!strcmp(day, code)) return true;
  return false;
}
bool validScheduleItem(JsonObjectConst item) {
  const int hour = item["hour"] | -1, minute = item["minute"] | -1;
  const char* label = item["label"] | "";
  return item["hour"].is<int>() && item["minute"].is<int>() &&
    hour >= 0 && hour < 24 && minute >= 0 && minute < 60 && strlen(label) <= 48;
}
void sendScheduleAck(const char* day, int count, bool ok) {
  StaticJsonDocument<256> reply;
  reply["type"] = "schedule_ack"; reply["day"] = day;
  reply["count"] = count; reply["ok"] = ok; sendReply(reply);
}
bool storeSchedule(const char* day, JsonArrayConst items) {
  if (!validScheduleDay(day) || items.isNull() || items.size() > 16) return false;
  for (JsonObjectConst item : items) if (!validScheduleItem(item)) return false;
  String data; serializeJson(items, data);
  if (data.length() > 2048) return false;
  String key = String("sch_") + day;
  const bool ok = prefs.putString(key.c_str(), data) == data.length();
  Serial.printf("[BLE] SYNC_SCHEDULE day=%s count=%d stored key=%s ok=%d\n", day, (int)items.size(), key.c_str(), ok);
  return ok;
}
void checkWeeklySchedule() {
  static uint32_t lastPoll = 0, lastMinute = UINT32_MAX;
  if (!rtcFound || uint32_t(millis() - lastPoll) < 250) return;
  lastPoll = millis();
  if (rtc.lostPower()) return;
  DateTime now = rtc.now();
  if (!now.isValid()) return;
  const uint32_t minute = now.unixtime() / 60;
  if (minute == lastMinute) return;
  lastMinute = minute;
  const char* days[] = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"};
  String key = String("sch_") + days[now.dayOfTheWeek()];
  String data = prefs.getString(key.c_str(), "[]");
  StaticJsonDocument<4096> saved;
  if (deserializeJson(saved, data)) return;
  String labels;
  bool matched = false;
  for (JsonObjectConst item : saved.as<JsonArrayConst>()) {
    if (validScheduleItem(item) && (item["hour"] | -1) == now.hour() && (item["minute"] | -1) == now.minute()) {
      matched = true;
      if (labels.length()) labels += " / ";
      labels += item["label"].as<const char*>();
    }
  }
  if (matched) { triggerNotification("LICH TRINH", labels.c_str()); startBeep(3, 100, 3000); }
}


String todayScheduleText(const DateTime& now) {
  const char* days[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
  String key = String("sch_") + days[now.dayOfTheWeek()];
  String data = prefs.getString(key.c_str(), "[]");
  StaticJsonDocument<4096> saved;
  if (deserializeJson(saved, data)) return "CHUA CO LICH HOM NAY";
  String result;
  for (JsonObjectConst task : saved.as<JsonArrayConst>()) {
    if (!validScheduleItem(task)) continue;
    if (result.length()) result += '\n';
    char time[8];
    snprintf(time, sizeof(time), "%02d:%02d", task["hour"].as<int>(), task["minute"].as<int>());
    result += time;
    result += ' ';
    result += task["label"].as<const char*>();
  }
  return result.length() ? result : "CHUA CO LICH HOM NAY";
}

int layoutTextScale(const LayoutItem& item, const String& value) {
  if (!item.autoFit) return item.size;
  for (int scale = item.size; scale >= 1; --scale) {
    const int columns = item.w / (6 * scale), rows = item.h / (8 * scale);
    if (columns < 1 || rows < 1) continue;
    int usedRows = 1, usedColumns = 0;
    for (size_t n = 0; n < value.length(); ++n) {
      if (value[n] == '\n') { ++usedRows; usedColumns = 0; }
      else { if (usedColumns == columns) { ++usedRows; usedColumns = 0; } ++usedColumns; }
    }
    if (usedRows <= rows) return scale;
  }
  return 1;
}

int rtcTempC();

void sendLayoutAck(const char* phase, int index, bool ok) {
  StaticJsonDocument<256> reply;
  reply["type"] = "layout_ack"; reply["phase"] = phase;
  reply["index"] = index; reply["ok"] = ok; sendReply(reply);
}

void sendLayoutBackgroundAck(int index, bool ok, const char* error = nullptr) {
  StaticJsonDocument<192> reply;
  reply["type"] = "layout_bg_ack"; reply["index"] = index;
  if (!ok && error) reply["error"] = error;
  reply["ok"] = ok; sendReply(reply);
}

void sendLayoutBitmapAck(int index, bool ok) {
  StaticJsonDocument<128> reply;
  reply["type"] = "layout_bitmap_ack"; reply["index"] = index;
  reply["ok"] = ok; sendReply(reply);
}

String layoutBitmapPath(int index, bool staged) {
  return String(staged ? "/face_stage_" : "/face_live_") + index + ".bin";
}

size_t layoutFileSize(const char* path) {
  if (!layoutFsReady) return 0;
  File file = LittleFS.open(path, "r");
  if (!file) return 0;
  size_t bytes = file.size();
  file.close();
  return bytes;
}

bool readLayoutFile(const char* path, uint8_t* data, size_t count) {
  if (layoutFileSize(path) != count) return false;
  File file = LittleFS.open(path, "r");
  if (!file) return false;
  bool ok = file.read(data, count) == count;
  file.close();
  return ok;
}

bool writeLayoutFile(const char* path, const uint8_t* data, size_t count) {
  if (!layoutFsReady) return false;
  File file = LittleFS.open(path, "w");
  if (!file) return false;
  const bool ok = file.write(data, count) == count;
  file.flush();
  file.close();
  return ok && layoutFileSize(path) == count;
}

uint16_t layoutCrc16(const uint8_t* bytes, size_t count) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < count; ++i) {
    crc ^= uint16_t(bytes[i]) << 8;
    for (int bit = 0; bit < 8; ++bit)
      crc = (crc & 0x8000) ? uint16_t((crc << 1) ^ 0x1021) : uint16_t(crc << 1);
  }
  return crc;
}

bool validHexCrc(const char* hex, size_t length, int expected) {
  if (expected < 0 || expected > 65535 || length % 2) return false;
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < length; i += 2) {
    if (!isxdigit((unsigned char)hex[i]) || !isxdigit((unsigned char)hex[i + 1])) return false;
    char pair[3] = {hex[i], hex[i + 1], 0};
    uint8_t byte = (uint8_t)strtoul(pair, nullptr, 16);
    crc ^= uint16_t(byte) << 8;
    for (int bit = 0; bit < 8; ++bit)
      crc = (crc & 0x8000) ? uint16_t((crc << 1) ^ 0x1021) : uint16_t(crc << 1);
  }
  return crc == expected;
}

bool decodeLayoutItem(JsonObjectConst data, LayoutItem& item) {
  const char* type = data["t"] | "";
  const char* value = data["v"] | "";
  const char* shape = data["g"] | "rect";
  if (strlen(type) >= sizeof(item.type) || strlen(value) >= sizeof(item.text) ||
      strlen(shape) >= sizeof(item.shape)) return false;
  if (strcmp(type, "clock") && strcmp(type, "text") &&
      strcmp(type, "geometry") && strcmp(type, "calendar") &&
      strcmp(type, "superText") && strcmp(type, "bitmap")) return false;
  strlcpy(item.type, type, sizeof(item.type));
  strlcpy(item.text, value, sizeof(item.text));
  strlcpy(item.shape, shape, sizeof(item.shape));
  item.x = constrain((int)(data["x"] | 0), 0, 319);
  item.y = constrain((int)(data["y"] | 0), 0, 239);
  item.w = constrain((int)(data["w"] | 20), 1, 320 - item.x);
  item.h = constrain((int)(data["h"] | 20), 1, 240 - item.y);
  item.size = constrain((int)(data["s"] | 2), 1, 20);
  item.color = (uint16_t)(data["c"] | 0xFFFF);
  item.invert = data["i"] | false;
  item.fill = data["f"] | false;
  item.autoFit = data["a"] | false;
  item.chunked = data["chunked"] | false;
  item.byteLength = 0;
  if (!strcmp(type, "bitmap")) {
    const int bytes = ((item.w + 7) / 8) * item.h;
    if (bytes > (int)LAYOUT_BACKGROUND_BYTES) return false;
    if (item.chunked) {
      const int declared = data["bytes"] | -1;
      const int index = data["n"] | -1;
      const bool stored = data["stored"] | false;
      if (index < 0 || index >= MAX_LAYOUT_ITEMS) return false;
      char key[16]; snprintf(key, sizeof(key), (data["stored"] | false) ? "bmp_%d" : "bmp_s_%d", (int)(data["n"] | -1));
      const String path = layoutBitmapPath(index, !stored);
      if (value[0] || declared != bytes ||
          (layoutFileSize(path.c_str()) != size_t(bytes) &&
           prefs.getBytesLength(key) != size_t(bytes))) return false;
      item.byteLength = bytes;
      return true;
    }
    if (bytes > 128 || strlen(value) != size_t(bytes * 2)) return false;
    for (const char* p = value; *p; ++p) if (!isxdigit((unsigned char)*p)) return false;
  } else if (strlen(value) > 64) return false;
  else if (item.chunked) return false;
  return true;
}

void loadCustomLayout() {
  customLayoutActive = prefs.getBool("layout_on", false);
  layoutBitmapBackgroundReady = layoutFileSize("/face_bg.bin") == LAYOUT_BACKGROUND_BYTES ||
                                prefs.getBytesLength("layout_img") == LAYOUT_BACKGROUND_BYTES;
  layoutBitmapBackgroundActive = prefs.getBool("layout_img_on", false) && layoutBitmapBackgroundReady;
  if (layoutBitmapBackgroundActive) {
    layoutBitmapBackgroundReady =
        readLayoutFile("/face_bg.bin", layoutBitmapBackground, LAYOUT_BACKGROUND_BYTES) ||
        prefs.getBytes("layout_img", layoutBitmapBackground,
                       LAYOUT_BACKGROUND_BYTES) == LAYOUT_BACKGROUND_BYTES;
    layoutBitmapBackgroundActive = layoutBitmapBackgroundReady;
  }
  layoutBackground = prefs.getUInt("layout_bg", 0);
  layoutRefreshSeconds = prefs.getInt("layout_hz", 60) == 1 ? 1 : 60;
  layoutCount = constrain(prefs.getInt("layout_n", 0), 0, MAX_LAYOUT_ITEMS);
  for (int i = 0; i < layoutCount; ++i) {
    String key = "layout_" + String(i);
    String saved = prefs.getString(key.c_str(), "");
    StaticJsonDocument<768> doc;
    if (deserializeJson(doc, saved) || !decodeLayoutItem(doc.as<JsonObjectConst>(), layoutItems[i])) {
      layoutCount = i;
      customLayoutActive = false;
      break;
    }
  }
}

void drawCustomLayout(const DateTime& now) {
  if (layoutBitmapBackgroundActive)
    tft.drawBitmap(0, 0, layoutBitmapBackground, 320, 240, C_WHITE, layoutBackground);
  else tft.fillScreen(layoutBackground);
  char timeBuffer[24];
  snprintf(timeBuffer, sizeof(timeBuffer), "%02d:%02d", now.hour(), now.minute());
  for (int i = 0; i < layoutCount; ++i) {
    const LayoutItem& item = layoutItems[i];
    uint16_t fg = item.invert ? C_BLACK : item.color;
    uint16_t bg = item.invert ? C_WHITE : layoutBackground;
    if (!strcmp(item.type, "bitmap")) {
      const int bytes = ((item.w + 7) / 8) * item.h;
      if (item.chunked) {
        char key[16]; snprintf(key, sizeof(key), "bmp_%d", i);
        const String path = layoutBitmapPath(i, false);
        if (bytes == item.byteLength &&
            (readLayoutFile(path.c_str(), stagedItemBitmap, bytes) ||
             prefs.getBytes(key, stagedItemBitmap, bytes) == size_t(bytes)))
          tft.drawBitmap(item.x, item.y, stagedItemBitmap, item.w, item.h, fg, bg);
        continue;
      }
      uint8_t bitmap[128] = {};
      if (bytes > 128 || strlen(item.text) != size_t(bytes * 2)) continue;
      for (int b = 0; b < bytes; ++b) {
        char pair[3] = {item.text[b * 2], item.text[b * 2 + 1], 0};
        bitmap[b] = (uint8_t)strtoul(pair, nullptr, 16);
      }
      tft.drawBitmap(item.x, item.y, bitmap, item.w, item.h, fg, bg);
      continue;
    }
    if (!strcmp(item.type, "geometry")) {
      if (!strcmp(item.shape, "circle")) {
        int r = min(item.w, item.h) / 2;
        if (item.fill) tft.fillCircle(item.x + r, item.y + r, r, fg);
        else tft.drawCircle(item.x + r, item.y + r, r, fg);
      } else if (!strcmp(item.shape, "line")) {
        tft.drawLine(item.x, item.y, item.x + item.w - 1, item.y + item.h - 1, fg);
      } else if (!strcmp(item.shape, "triangle")) {
        const int x2 = item.x + item.w - 1, y2 = item.y + item.h - 1;
        if (item.fill) tft.fillTriangle(item.x + item.w / 2, item.y, item.x, y2, x2, y2, fg);
        else tft.drawTriangle(item.x + item.w / 2, item.y, item.x, y2, x2, y2, fg);
      } else if (!strcmp(item.shape, "ellipse")) {
        const float rx = item.w / 2.0f, ry = item.h / 2.0f;
        for (int px = 0; px < item.w; ++px) {
          const float nx = (px + 0.5f - rx) / rx;
          const int dy = int(ry * sqrtf(max(0.0f, 1.0f - nx * nx)));
          const int cx = item.x + px, cy = item.y + item.h / 2;
          if (item.fill) tft.drawFastVLine(cx, cy - dy, max(1, 2 * dy), fg);
          else { tft.drawPixel(cx, cy - dy, fg); tft.drawPixel(cx, cy + dy, fg); }
        }
      } else if (!strcmp(item.shape, "diamond")) {
        const int cx = item.x + item.w / 2, cy = item.y + item.h / 2;
        const int right = item.x + item.w - 1, bottom = item.y + item.h - 1;
        if (item.fill) {
          tft.fillTriangle(cx, item.y, item.x, cy, right, cy, fg);
          tft.fillTriangle(item.x, cy, right, cy, cx, bottom, fg);
        } else {
          tft.drawLine(cx, item.y, right, cy, fg); tft.drawLine(right, cy, cx, bottom, fg);
          tft.drawLine(cx, bottom, item.x, cy, fg); tft.drawLine(item.x, cy, cx, item.y, fg);
        }
      } else if (!strcmp(item.shape, "cross")) {
        const int bar = max(1, min(item.w, item.h) / 3);
        const int vx = item.x + (item.w - bar) / 2, hy = item.y + (item.h - bar) / 2;
        if (item.fill) { tft.fillRect(vx, item.y, bar, item.h, fg); tft.fillRect(item.x, hy, item.w, bar, fg); }
        else { tft.drawRect(vx, item.y, bar, item.h, fg); tft.drawRect(item.x, hy, item.w, bar, fg); }
      } else if (!strcmp(item.shape, "star")) {
        int sx[10], sy[10];
        const int cx = item.x + item.w / 2, cy = item.y + item.h / 2;
        for (int p = 0; p < 10; ++p) {
          const float angle = -PI / 2 + p * PI / 5;
          const float radius = p % 2 ? 0.22f : 0.5f;
          sx[p] = cx + int(cosf(angle) * item.w * radius);
          sy[p] = cy + int(sinf(angle) * item.h * radius);
        }
        for (int p = 0; p < 10; ++p) {
          const int q = (p + 1) % 10;
          if (item.fill) tft.fillTriangle(cx, cy, sx[p], sy[p], sx[q], sy[q], fg);
          else tft.drawLine(sx[p], sy[p], sx[q], sy[q], fg);
        }
      } else if (!strcmp(item.shape, "cube")) {
        const int d = max(1, min(item.w, item.h) / 4);
        tft.drawRect(item.x, item.y + d, item.w - d, item.h - d, fg);
        tft.drawRect(item.x + d, item.y, item.w - d, item.h - d, fg);
        tft.drawLine(item.x, item.y + d, item.x + d, item.y, fg);
        tft.drawLine(item.x + item.w - d - 1, item.y + d, item.x + item.w - 1, item.y, fg);
        tft.drawLine(item.x, item.y + item.h - 1, item.x + d, item.y + item.h - d - 1, fg);
        tft.drawLine(item.x + item.w - d - 1, item.y + item.h - 1, item.x + item.w - 1, item.y + item.h - d - 1, fg);
      } else if (!strcmp(item.shape, "roundrect")) {
        if (item.fill) tft.fillRoundRect(item.x, item.y, item.w, item.h, 8, fg);
        else tft.drawRoundRect(item.x, item.y, item.w, item.h, 8, fg);
      } else {
        if (item.fill) tft.fillRect(item.x, item.y, item.w, item.h, fg);
        else tft.drawRect(item.x, item.y, item.w, item.h, fg);
      }
      continue;
    }
    if (item.invert) tft.fillRect(item.x, item.y, item.w, item.h, bg);
    String value = !strcmp(item.type, "clock") ? String(timeBuffer) :
                   !strcmp(item.type, "calendar") ? todayScheduleText(now) :
                   !strcmp(item.type, "superText") ?
                      (rtcFound ? String(rtcTempC()) + "C" : String("--C")) : String(item.text);
    value.replace("@T", timeBuffer);
    value.replace("@h", String(now.hour()));
    value.replace("@m", String(now.minute()));
    value.replace("@s", String(now.second()));
    value.replace("@d", String(now.day()));
    value.replace("@M", String(now.month()));
    value.replace("@y", String(now.year()));
    const int textScale = layoutTextScale(item, value);
    tft.setTextSize(textScale);
    if (layoutBitmapBackgroundActive && !item.invert) tft.setTextColor(fg);
    else tft.setTextColor(fg, bg);
    tft.setCursor(item.x, item.y);
    // Respect element bounds using the GFX 6x8 fixed font cell.
    int dx = 0, dy = 0;
    tft.setTextWrap(false);
    for (size_t n = 0; n < value.length(); ++n) {
      if (value[n] == '\n') { dx = 0; dy += 8 * textScale; continue; }
      if (dx + 6 * textScale > item.w) { dx = 0; dy += 8 * textScale; }
      if (dy + 8 * textScale > item.h) break;
      tft.setCursor(item.x + dx, item.y + dy); tft.write(value[n]); dx += 6 * textScale;
    }
    tft.setTextWrap(true);
  }
}

unsigned long lastBtnPress = 0;
int lastMinute = -1;
bool isBluetoothConnected = false;
bool lastBluetoothState = false;

// ==========================================
// BIẾN CHO HỆ THỐNG CÒI NON-BLOCKING
// ==========================================

// ==========================================
// POMODORO THEO PHIÊN 
// ==========================================
enum PomoPhase { PHASE_WORK, PHASE_BREAK, PHASE_LONG_BREAK };
const char* phaseLabel(PomoPhase ph);
uint16_t phaseColor(PomoPhase ph);
PomoPhase pomoPhase = PHASE_WORK;

int pomoWorkDuration      = 25 * 60;   
int pomoBreakDuration     = 5 * 60;    
int pomoLongBreakDuration = 15 * 60;   
int pomoSessionCount      = 0;         
int pauseCount            = 0;         // Đếm số lần người dùng bấm PAUSE trong phiên

// Lưu thời gian bắt đầu phiên Pomodoro (từ RTC DS3231)
char pomoStartTimeStr[25] = "";

int pomoTime        = pomoWorkDuration;
int pomoInitialTime = pomoWorkDuration;
bool pomoRunning    = false;
unsigned long pomoLastTick = 0;
uint32_t pomoRemainderMs = 0;
int lastPomoDraw = -2;
int lastPomoSessionDraw = -2;
PomoPhase lastPomoPhaseDraw = PHASE_WORK;

// ==========================================
// TASK TYPE SELECTION (Quản lý nội dung công việc cho AI)
// Giải quyết vấn đề: "Dữ liệu đầu vô khi train không quản lý được nội dung"
// ==========================================
const char* taskTypeLabels[] = {"Coding", "Reading", "Study", "General"};
const uint16_t taskTypeColors[] = {C_CYAN, C_GREEN, C_YELLOW, C_ORANGE};
const int NUM_TASK_TYPES = 4;
int selectedTaskTypeIndex = 3;  // Mặc định = General
String current_pomo_task_type = "General";
bool pomoSelectingTask = true;  // Hiện màn hình chọn Task trước khi đếm giờ

// ==========================================
// ĐẾM NGƯỢC (Countdown Timer)
// ==========================================
const int timerPresets[] = {10, 15, 30, 60, 300, 600, 900, 1500};
const char* timerLabels[] = {"10s", "15s", "30s", "1m", "5m", "10m", "15m", "25m"};
const int NUM_PRESETS = 8;

int selectedTimerPreset = 0;
bool timerSelecting = true;   
int  timerSeconds   = 0;
int  timerInitial   = 0;
bool timerRunning   = false;
bool timerFinished  = false;
unsigned long timerLastTick = 0;
uint32_t timerRemainderMs = 0;
int lastTimerDraw = -2;

// ==========================================
// SETUP HỆ THỐNG
// ==========================================
// ==========================================
// QUAN LY BAO THUC (ALARM SCHEDULER & NVS)
// ==========================================
bool alarmEnabled = false;
uint8_t alarmDays = 0x7f; // bit 0=Mon ... bit 6=Sun
int  alarmHour = -1;
int  alarmMinute = -1;
char alarmLabel[32] = "BAO THUC";
bool isAlarmActive = false;
unsigned long alarmStartTime = 0;
int  lastAlarmMinuteFired = -1;
AlarmEntry alarms[MAX_ALARMS], stagedAlarms[MAX_ALARMS];
int alarmCount = 0, stagedAlarmCount = 0;
bool alarmTransferActive = false;

bool decodeAlarm(JsonObjectConst data, AlarmEntry& alarm) {
  if (!data["hour"].is<int>() || !data["minute"].is<int>() ||
      !data["days"].is<int>() || !data["enabled"].is<bool>()) return false;
  const int hour = data["hour"], minute = data["minute"], days = data["days"];
  const char* label = data["label"] | "";
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59 ||
      days < 1 || days > 127 || !label[0] || strlen(label) > 31) return false;
  alarm.hour = hour; alarm.minute = minute; alarm.days = days;
  alarm.enabled = data["enabled"];
  strlcpy(alarm.label, label, sizeof(alarm.label));
  return true;
}

void sendAlarmsAck(int index, int count, bool ok) {
  StaticJsonDocument<128> reply;
  reply["type"] = "alarms_ack"; reply["index"] = index;
  reply["count"] = count; reply["ok"] = ok; sendReply(reply);
}

bool storeAlarms(const AlarmEntry* entries, int count) {
  if (count < 0 || count > MAX_ALARMS) return false;
  StaticJsonDocument<1536> doc;
  JsonArray array = doc.to<JsonArray>();
  for (int i = 0; i < count; ++i) {
    JsonObject item = array.createNestedObject();
    item["hour"] = entries[i].hour; item["minute"] = entries[i].minute;
    item["days"] = entries[i].days; item["enabled"] = entries[i].enabled;
    item["label"] = entries[i].label;
  }
  String serialized; serializeJson(doc, serialized);
  if (serialized.length() > 1024 || prefs.putString("alarms_v2", serialized) != serialized.length()) return false;
  memcpy(alarms, entries, sizeof(AlarmEntry) * count);
  alarmCount = count;
  return true;
}

void loadAlarms() {
  String saved = prefs.getString("alarms_v2", "");
  if (saved.length()) {
    StaticJsonDocument<1536> doc;
    if (!deserializeJson(doc, saved) && doc.is<JsonArray>() && doc.as<JsonArray>().size() <= MAX_ALARMS) {
      int count = 0;
      bool valid = true;
      for (JsonObjectConst item : doc.as<JsonArrayConst>()) {
        if (!decodeAlarm(item, alarms[count++])) { valid = false; break; }
      }
      if (valid) { alarmCount = count; return; }
    }
    Serial.println("[ALARM] Invalid NVS alarm list; legacy fallback");
  }
  // Existing single alarm remains available until the first successful list commit.
  if (alarmHour >= 0 && alarmHour < 24 && alarmMinute >= 0 && alarmMinute < 60) {
    alarms[0].hour = alarmHour; alarms[0].minute = alarmMinute;
    alarms[0].days = alarmDays ? alarmDays : 0x7f;
    alarms[0].enabled = alarmEnabled;
    strlcpy(alarms[0].label, alarmLabel, sizeof(alarms[0].label));
    alarmCount = 1;
  }
}

void saveAlarmConfig() {
  prefs.putBool("alm_en", alarmEnabled);
  prefs.putUChar("alm_days", alarmDays);
  prefs.putInt("alm_hr", alarmHour);
  prefs.putInt("alm_mn", alarmMinute);
  prefs.putString("alm_lb", alarmLabel);
}

void loadAlarmConfig() {
  alarmEnabled = prefs.getBool("alm_en", false);
  alarmDays = prefs.getUChar("alm_days", 0x7f);
  alarmHour = prefs.getInt("alm_hr", -1);
  alarmMinute = prefs.getInt("alm_mn", -1);
  String lb = prefs.getString("alm_lb", "BAO THUC");
  strncpy(alarmLabel, lb.c_str(), sizeof(alarmLabel) - 1);
  alarmLabel[sizeof(alarmLabel) - 1] = '\0';
}

// ==========================================
// QUAN LY THONG BAO NON-BLOCKING (An toan voi millis overflow)
// ==========================================
bool notifActive = false;
unsigned long notifStartTime = 0;
const unsigned long NOTIF_DURATION_MS = 2500;
char notifTitle[32] = "";
char notifBody[64] = "";

void triggerNotification(const char* title, const char* body) {
  strncpy(notifTitle, title, sizeof(notifTitle) - 1);
  notifTitle[sizeof(notifTitle) - 1] = '\0';
  strncpy(notifBody, body, sizeof(notifBody) - 1);
  notifBody[sizeof(notifBody) - 1] = '\0';

  notifActive = true;
  notifStartTime = millis();

  tft.fillRoundRect(20, 40, 280, 160, 10, C_BLUE);
  tft.drawRoundRect(20, 40, 280, 160, 10, C_WHITE);
  tft.setTextColor(C_YELLOW); tft.setTextSize(2);
  tft.setCursor(35, 55); tft.print(notifTitle);
  tft.setTextColor(C_WHITE); tft.setTextSize(2);
  tft.setCursor(35, 95); tft.print(notifBody);

  if (!isAlarmActive) startBeep(3, 80, 2800);
}

void displayScrollText(const char* title, const char* message) {
  triggerNotification(title, message);
}

// ==========================================
// TRIEN KHAI HÀNG ĐỢI FIFO POMODORO NVS
// ==========================================
void initPomodoroQueue() {
  pomoQueueCount = prefs.getInt("pq_cnt", 0);
  pomoQueueHead  = prefs.getInt("pq_head", 0);
  pomoQueueTail  = prefs.getInt("pq_tail", 0);

  if (pomoQueueCount < 0 || pomoQueueCount > MAX_POMO_QUEUE) pomoQueueCount = 0;
  if (pomoQueueHead < 0 || pomoQueueHead >= MAX_POMO_QUEUE) pomoQueueHead = 0;
  // Count is the commit marker; derive tail after an interrupted metadata write.
  pomoQueueTail = (pomoQueueHead + pomoQueueCount) % MAX_POMO_QUEUE;

  // Migration tu ban cu "pomo_pending" neu co
  String oldPomo = prefs.getString("pomo_pending", "");
  if (oldPomo.length() > 0 && pomoQueueCount < MAX_POMO_QUEUE) {
    char slotKey[16], idKey[16];
    snprintf(slotKey, sizeof(slotKey), "pq_item_%d", pomoQueueTail);
    snprintf(idKey, sizeof(idKey), "pq_id_%d", pomoQueueTail);
    prefs.putString(slotKey, oldPomo);
    prefs.putString(idKey, "legacy_pending");
    pomoQueueTail = (pomoQueueTail + 1) % MAX_POMO_QUEUE;
    pomoQueueCount++;
    prefs.putInt("pq_cnt", pomoQueueCount);
    prefs.putInt("pq_tail", pomoQueueTail);
    prefs.remove("pomo_pending");
    Serial.println("[POMO_QUEUE] Da migrate pending cu sang FIFO");
  }

  Serial.printf("[POMO_QUEUE] Init FIFO: count=%d, head=%d, tail=%d\n",
    pomoQueueCount, pomoQueueHead, pomoQueueTail);
}

bool enqueuePomodoro(const char* jsonStr, const char* sessionId) {
  if (pomoQueueCount >= MAX_POMO_QUEUE) {
    Serial.printf("[POMO_QUEUE] CANH BAO: Hang doi day (%d/%d). Khong the ghi them phien chua ACK!\n",
      pomoQueueCount, MAX_POMO_QUEUE);
    return false;
  }

  char slotKey[16], idKey[16];
  snprintf(slotKey, sizeof(slotKey), "pq_item_%d", pomoQueueTail);
  snprintf(idKey, sizeof(idKey), "pq_id_%d", pomoQueueTail);

  if (prefs.putString(slotKey, jsonStr) != strlen(jsonStr) ||
      prefs.putString(idKey, sessionId) != strlen(sessionId)) {
    Serial.println("[POMO_QUEUE] NVS payload write failed; not committed");
    return false;
  }
  const int nextTail = (pomoQueueTail + 1) % MAX_POMO_QUEUE;
  if (prefs.putInt("pq_tail", nextTail) != sizeof(int32_t) ||
      prefs.putInt("pq_cnt", pomoQueueCount + 1) != sizeof(int32_t)) {
    Serial.println("[POMO_QUEUE] NVS metadata write failed; not accepted");
    return false;
  }
  pomoQueueTail = nextTail;
  ++pomoQueueCount;

  Serial.printf("[POMO_QUEUE] Da them phien %s vao FIFO. Count=%d, Tail=%d\n",
    sessionId, pomoQueueCount, pomoQueueTail);
  return true;
}

void processPomodoroQueue() {
  if (!bleClientConnected || pBleTxChar == nullptr) {
    waitingForPomoAck = false;
    pomoTransmitJson = "";
    return;
  }

  if (pomoQueueCount <= 0) return;

  // One fragment per loop tick: do not stall buttons, audio, or countdowns.
  if (pomoTransmitJson.length() > 0) {
    if (millis() - lastPomoFragmentTime < 15) return;
    lastPomoFragmentTime = millis();
    const size_t remaining = pomoTransmitJson.length() - pomoTransmitOffset;
    const size_t length = remaining < pomoFragmentBytes ? remaining : pomoFragmentBytes;
    uint8_t packet[184];
    packet[0] = 0x1e;
    packet[1] = pomoTransferSequence;
    packet[2] = pomoFragmentIndex++;
    packet[3] = (pomoTransmitJson.length() + pomoFragmentBytes - 1) / pomoFragmentBytes;
    memcpy(packet + 4, pomoTransmitJson.c_str() + pomoTransmitOffset, length);
    pBleTxChar->setValue(packet, length + 4);
    pBleTxChar->notify();
    pomoTransmitOffset += length;
    if (pomoTransmitOffset == pomoTransmitJson.length()) {
      pomoTransmitJson = "";
      waitingForPomoAck = true;
      lastPomoSendTime = millis();
    }
    return;
  }

  if (waitingForPomoAck) {
    if (millis() - lastPomoSendTime > POMO_ACK_TIMEOUT_MS) {
      Serial.printf("[POMO_QUEUE] Timeout ACK session %s. Dang gui lai...\n", currentPomoAckId.c_str());
      waitingForPomoAck = false;
    } else {
      return;
    }
  }

  char slotKey[16], idKey[16];
  snprintf(slotKey, sizeof(slotKey), "pq_item_%d", pomoQueueHead);
  snprintf(idKey, sizeof(idKey), "pq_id_%d", pomoQueueHead);

  String itemJson = prefs.getString(slotKey, "");
  String itemId   = prefs.getString(idKey, "");

  if (itemJson.length() == 0) {
    pomoQueueHead = (pomoQueueHead + 1) % MAX_POMO_QUEUE;
    pomoQueueCount--;
    prefs.putInt("pq_cnt", pomoQueueCount);
    prefs.putInt("pq_head", pomoQueueHead);
    return;
  }

  currentPomoAckId = itemId;
  uint16_t peerMtu = 517;
  const auto peers = pBleServer->getPeerDevices(false);
  if (peers.empty()) return;
  for (const auto& peer : peers) {
    if (peer.second.mtu < peerMtu) peerMtu = peer.second.mtu;
  }
  if (peerMtu < 23) peerMtu = 23;
  if (itemJson.length() <= peerMtu - 3) {
    pBleTxChar->setValue(itemJson.c_str());
    pBleTxChar->notify();
    waitingForPomoAck = true;
    lastPomoSendTime = millis();
  } else {
    // Four-byte framing header, leaving ATT's three-byte overhead intact.
    pomoFragmentBytes = min((int)peerMtu - 7, 180);
    pomoTransmitJson = itemJson;
    pomoTransmitOffset = 0;
    pomoFragmentIndex = 0;
    ++pomoTransferSequence;
    lastPomoFragmentTime = millis() - 15;
    waitingForPomoAck = false;
  }
  Serial.printf("[POMO_QUEUE] Da gui session %s (count=%d). Cho ACK...\n",
    currentPomoAckId.c_str(), pomoQueueCount);
}

void handlePomoAck(const char* ackSessionId) {
  if (pomoQueueCount <= 0) return;

  char idKey[16], slotKey[16];
  snprintf(idKey, sizeof(idKey), "pq_id_%d", pomoQueueHead);
  snprintf(slotKey, sizeof(slotKey), "pq_item_%d", pomoQueueHead);

  String expectedId = prefs.getString(idKey, "");
  if (strlen(ackSessionId) > 0 && (expectedId == ackSessionId || expectedId == "legacy_pending")) {
    pomoTransmitJson = "";
    prefs.remove(slotKey);
    prefs.remove(idKey);
    pomoQueueHead = (pomoQueueHead + 1) % MAX_POMO_QUEUE;
    pomoQueueCount--;
    prefs.putInt("pq_cnt", pomoQueueCount);
    prefs.putInt("pq_head", pomoQueueHead);
    waitingForPomoAck = false;
    currentPomoAckId = "";
    Serial.printf("[POMO_QUEUE] ACK hop le cho %s. Con lai: %d phien\n",
      ackSessionId, pomoQueueCount);

    if (pomoQueueCount > 0 && bleClientConnected) {
      processPomodoroQueue();
    }
  } else {
    Serial.printf("[POMO_QUEUE] ACK khong khop: nhan '%s', cho '%s'. Bo qua.\n",
      ackSessionId, expectedId.c_str());
  }
}
  DateTime nowRtc() { return rtcFound ? rtc.now() : DateTime(2026,1,1,0,0,0); }
  int rtcTempC() {
  static int t=25; static uint32_t tl=0; static bool first=true;
  if (!rtcFound) return 25;
  if (first || millis()-tl>10000) { first=false; tl=millis(); t=(int)rtc.getTemperature(); }
  return t;
  }


#define LOG_BUTTONS(tag) Serial.printf("[BTN] %-8s MODE%d=%d OK%d=%d SELECT%d=%d\n", tag, \
                  BTN_MODE, digitalRead(BTN_MODE), BTN_ACTION1, digitalRead(BTN_ACTION1), BTN_ACTION2, digitalRead(BTN_ACTION2))

void setup() {
  Serial.begin(115200);
  pinMode(BTN_MODE, INPUT); pinMode(BTN_ACTION1, INPUT); pinMode(BTN_ACTION2, INPUT);
  LOG_BUTTONS("boot");

  Serial.printf("[BUILD] NAV_MODE34_OK35_SELECT36 | %s %s\n",__DATE__,__TIME__);
  Serial.printf("[BUILD] Source: %s\n",__FILE__);

  // Khoi tao Preferences NVS de luu tru ben vung
  prefs.begin("smarttime", false);
  layoutFsReady = LittleFS.begin(true);
  Serial.printf("[LAYOUT_FS] mount=%d total=%u used=%u\n", layoutFsReady,
                layoutFsReady ? (unsigned)LittleFS.totalBytes() : 0,
                layoutFsReady ? (unsigned)LittleFS.usedBytes() : 0);
  touchEnabled = prefs.getBool("touch_en", true);
  currentThemeId = prefs.getInt("theme", 0);
  currentThemeColor = prefs.getUInt("theme_color", C_CYAN);
  if (currentThemeId < 0 || currentThemeId > 2) currentThemeId = 0;
  loadCustomLayout();
  loadAlarmConfig();
  loadAlarms();

  // Fixed hardware: ILI9341, parallel 8-bit. Do not reuse old lcd_idx NVS.
  // TFT D0..D7 = 12,13,26,25,16,17,27,14 in the project-local library.
  tft.reset();
  delay(150);
  const uint16_t lcdID = 0x9341;
  const uint16_t detectedID = tft.readID();
  Serial.printf("[TFT] readID=0x%04X, fixed ILI9341=0x%04X\n", detectedID, lcdID);
  tft.begin(lcdID);
  tft.setRotation(1);

  // ── TEST PATTERN: Xóa màn hình đen và vẽ logo SmartTime khởi động ──
  tft.fillScreen(C_BLACK);
  tft.fillRoundRect(15, 15, 290, 210, 10, C_DARK_GRAY);
  tft.drawRoundRect(15, 15, 290, 210, 10, C_CYAN);
  tft.setTextColor(C_CYAN, C_DARK_GRAY);
  tft.setTextSize(3);
  tft.setCursor(45, 75);
  tft.print("SMARTTIME");
  tft.setTextColor(C_WHITE, C_DARK_GRAY);
  tft.setTextSize(2);
  tft.setCursor(65, 120);
  tft.print("TFT LCD 320x240");
  char idStr[32];
  snprintf(idStr, sizeof(idStr), "READ ID: 0x%04X", detectedID);
  tft.setCursor(75, 160);
  tft.setTextSize(1);
  tft.setTextColor(detectedID == lcdID ? C_YELLOW : C_RED, C_DARK_GRAY);
  tft.print(idStr);

  delay(1200); // Hiển thị màn hình khởi động 1.2s để xác nhận màn hình hoạt động

  Wire.begin(21, 22, 400000);
  rtcFound = rtc.begin();
  if (!rtcFound) {
    Serial.println("Khong tim thay RTC!");
  }
  initPomodoroQueue();

  // Khởi tạo còi tắt mặc định
  // Buzzer pin and PWM are owned by the IO service. 
  
  i2s_config_t i2s_config = {
      .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
      .sample_rate = 44100,
      .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
      .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
      .communication_format = I2S_COMM_FORMAT_STAND_I2S,
      .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
      .dma_buf_count = 8,
      .dma_buf_len = 256,
      .use_apll = false,
      .tx_desc_auto_clear = true,
      .fixed_mclk = 0
  };
  a2dp_sink.set_i2s_config(i2s_config);

  i2s_pin_config_t my_pin_config = {
      .bck_io_num = I2S_BCLK,
      .ws_io_num = I2S_LRC,
      .data_out_num = I2S_DOUT,
      .data_in_num = I2S_PIN_NO_CHANGE
  };
  a2dp_sink.set_pin_config(my_pin_config);
  // Khoi tao Bluetooth Serial (SPP) truoc A2DP de tranh loi socket tren Android
  // === KHOI TAO BLE GATT SERVER ===
  bleCommandQueue = xQueueCreate(4, 513);
  BLEDevice::init("ESP32_Pomodoro_Data");
  BLEDevice::setMTU(517); // Ten hien thi khi quet BLE
  pBleServer = BLEDevice::createServer();

  // Callback xu ly ket noi/ngat ket noi BLE
  class BleServerCb : public BLEServerCallbacks {
    void onConnect(BLEServer* s)    override {
      bleClientConnected = true;
      waitingForPomoAck   = false;
    }
    void onDisconnect(BLEServer* s) override {
      bleClientConnected = false;
      waitingForPomoAck   = false;
      // Bat lai advertising sau khi client ngat ket noi
      BLEDevice::startAdvertising();
    }
  };
  pBleServer->setCallbacks(new BleServerCb());

  BLEService* pService = pBleServer->createService(BLE_SERVICE_UUID);

  // RX Characteristic: App ghi lenh JSON vao day
  pBleRxChar = pService->createCharacteristic(
    BLE_RX_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  class RxCb : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* c) override {
      const std::string value = c->getValue();
      if (!bleCommandQueue || value.empty() || value.size() > 512) return;
      char packet[513] = {};
      memcpy(packet, value.data(), value.size());
      if (xQueueSend(bleCommandQueue, packet, 0) != pdTRUE) {
        Serial.println("[BLE] Command queue full; client must retry after ACK timeout");
      }
    }
  };
  pBleRxChar->setCallbacks(new RxCb());

  // TX Characteristic: ESP32 gui du lieu Pomodoro ve App
  pBleTxChar = pService->createCharacteristic(
    BLE_TX_UUID,
    BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ
  );
  pBleTxChar->addDescriptor(new BLE2902());

  pService->start();
  BLEAdvertising* pAdv = BLEDevice::getAdvertising();
  pAdv->addServiceUUID(BLE_SERVICE_UUID);
  pAdv->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("BLE GATT started: ESP32_Pomodoro_Data");

  a2dp_sink.set_auto_reconnect(true);
  a2dp_sink.set_volume(75);
  a2dp_sink.start("ESP32_Pomodoro_Speaker");

  pinMode(BTN_MODE, INPUT);
  pinMode(BTN_ACTION1, INPUT);
  pinMode(BTN_ACTION2, INPUT);
  Serial.printf("[INPUT] Idle raw MODE%d=%d OK%d=%d SELECT%d=%d (released=1; external pull-ups required)\n",
                BTN_MODE, digitalRead(BTN_MODE), BTN_ACTION1, digitalRead(BTN_ACTION1), BTN_ACTION2, digitalRead(BTN_ACTION2));

  // Khoi dong WiFi + MQTT (chi khi bat ENABLE_WIFI_MQTT)
  // Goi sau Bluetooth init, cho BT on dinh truoc
  delay(500);
  #ifdef ENABLE_WIFI_MQTT
    setupWifiMQTT();
  #endif
  // Start accepting contacts only once the UI and peripherals are ready.
  if (!beginIoService()) Serial.println("[IO] ERROR: input/buzzer service not started");
}

// ==========================================
// XU LY LENH BLE TU APP (goi trong loop)
// ==========================================
void handleBLECommands() {
  char packet[513];
  if (!bleCommandQueue || xQueueReceive(bleCommandQueue, packet, 0) != pdTRUE) return;
  String incoming(packet);
  incoming.trim();

  StaticJsonDocument<2048> doc;  // 2048 needed for SYNC_SCHEDULE with multiple items
  DeserializationError err = deserializeJson(doc, incoming);
  if (err) {
    Serial.print("[BLE] JSON parse error: "); Serial.println(err.c_str());
    return;
  }

  const char* cmd = doc["cmd"] | "";
  JsonObject params = doc["params"];
  commandRequestId = doc["rid"] | "";

  if (strcmp(cmd, "LAYOUT_BG_BEGIN") == 0) {
    bitmapTransferBytes = 0;
    stagedLayoutBitmapBackgroundReady = false;
    const int crc = params["crc"] | -1;
    bitmapExpectedCrc = uint16_t(crc);
    bitmapTransferActive = (params["bytes"] | 0) == (int)LAYOUT_BACKGROUND_BYTES &&
                           crc >= 0 && crc <= 65535;
    sendLayoutBackgroundAck(-1, bitmapTransferActive);
  } else if (strcmp(cmd, "LAYOUT_BG_CHUNK") == 0) {
    const int index = params["n"] | -1;
    const char* hex = params["v"] | "";
    bool ok = bitmapTransferActive && index >= 0 &&
              bitmapTransferBytes == size_t(index) * 128 && strlen(hex) == 256 &&
              bitmapTransferBytes + 128 <= LAYOUT_BACKGROUND_BYTES;
    if (ok) ok = validHexCrc(hex, 256, params["crc"] | -1);
    if (ok) {
      for (int i = 0; i < 128; ++i) {
        char pair[3] = {hex[i * 2], hex[i * 2 + 1], 0};
        stagedBitmapBackground[bitmapTransferBytes + i] = (uint8_t)strtoul(pair, nullptr, 16);
      }
      bitmapTransferBytes += 128;
    }
    sendLayoutBackgroundAck(index, ok);
  } else if (strcmp(cmd, "LAYOUT_BG_COMMIT") == 0) {
    const bool complete = bitmapTransferActive && bitmapTransferBytes == LAYOUT_BACKGROUND_BYTES &&
                          (params["bytes"] | 0) == (int)LAYOUT_BACKGROUND_BYTES;
    const bool crcOk = complete &&
                       layoutCrc16(stagedBitmapBackground, bitmapTransferBytes) == bitmapExpectedCrc;
    const bool ok = crcOk && writeLayoutFile("/face_bg.stage", stagedBitmapBackground,
                                            LAYOUT_BACKGROUND_BYTES);
    bitmapTransferActive = false;
    stagedLayoutBitmapBackgroundReady = ok;
    Serial.printf("[LAYOUT_BG] commit bytes=%u complete=%d crc=%d fs=%d ok=%d\n",
                  (unsigned)bitmapTransferBytes, complete, crcOk, layoutFsReady, ok);
    sendLayoutBackgroundAck(75, ok,
                            !complete ? "incomplete" : !crcOk ? "crc_mismatch" : "flash_write_failed");
  } else if (strcmp(cmd, "LAYOUT_BEGIN") == 0) {
    pendingLayoutCount = 0;
    itemBitmapTransferActive = false;
    layoutTransferActive = true;
    pendingLayoutBackground = params["background"] | 0;
    pendingLayoutBitmapBackground = params["bitmap_bg"] | false;
    pendingLayoutRefreshSeconds = (params["refresh"] | 60) == 1 ? 1 : 60;
    sendLayoutAck("begin", 0, true);
  } else if (strcmp(cmd, "LAYOUT_BITMAP_BEGIN") == 0) {
    const int index = params["n"] | -1;
    const int bytes = params["bytes"] | -1;
    const int crc = params["crc"] | -1;
    itemBitmapTransferActive = layoutTransferActive && index == pendingLayoutCount &&
                               index >= 0 && index < MAX_LAYOUT_ITEMS &&
                               bytes > 128 && bytes <= (int)LAYOUT_BACKGROUND_BYTES &&
                               crc >= 0 && crc <= 65535;
    itemBitmapExpectedCrc = uint16_t(crc);
    itemBitmapIndex = index; itemBitmapExpected = itemBitmapTransferActive ? bytes : 0;
    itemBitmapBytes = 0;
    sendLayoutBitmapAck(-1, itemBitmapTransferActive);
  } else if (strcmp(cmd, "LAYOUT_BITMAP_CHUNK") == 0) {
    const int index = params["n"] | -1;
    const int chunk = params["chunk"] | -1;
    const char* hex = params["v"] | "";
    const size_t len = strlen(hex);
    bool ok = itemBitmapTransferActive && index == itemBitmapIndex &&
              chunk >= 0 && itemBitmapBytes == size_t(chunk) * 128 &&
              len > 0 && len <= 256 && len % 2 == 0 &&
              itemBitmapBytes + len / 2 <= itemBitmapExpected;
    if (ok) ok = validHexCrc(hex, len, params["crc"] | -1);
    if (ok) {
      for (size_t j = 0; j < len / 2; ++j) {
        char pair[3] = {hex[j * 2], hex[j * 2 + 1], 0};
        stagedItemBitmap[itemBitmapBytes + j] = (uint8_t)strtoul(pair, nullptr, 16);
      }
      itemBitmapBytes += len / 2;
    }
    sendLayoutBitmapAck(chunk, ok);
  } else if (strcmp(cmd, "LAYOUT_BITMAP_COMMIT") == 0) {
    const int index = params["n"] | -1;
    const int bytes = params["bytes"] | -1;
    char key[16]; snprintf(key, sizeof(key), "bmp_s_%d", index);
    const String stagePath = layoutBitmapPath(index, true);
    const bool ok = itemBitmapTransferActive && index == itemBitmapIndex &&
                    bytes == (int)itemBitmapExpected &&
                    itemBitmapBytes == itemBitmapExpected &&
                    layoutCrc16(stagedItemBitmap, itemBitmapBytes) == itemBitmapExpectedCrc &&
                    writeLayoutFile(stagePath.c_str(), stagedItemBitmap, itemBitmapExpected);
    itemBitmapTransferActive = false;
    sendLayoutBitmapAck(-1, ok);
  } else if (strcmp(cmd, "LAYOUT_ITEM") == 0) {
    int index = params["n"] | -1;
    bool ok = layoutTransferActive && index >= 0 && index == pendingLayoutCount && index < MAX_LAYOUT_ITEMS &&
              decodeLayoutItem(params, stagedLayoutItems[index]);
    if (ok) ++pendingLayoutCount;
    sendLayoutAck("item", index, ok);
  } else if (strcmp(cmd, "LAYOUT_COMMIT") == 0) {
    int expected = params["count"] | -1;
    bool ok = layoutTransferActive && expected == pendingLayoutCount &&
              (expected > 0 || pendingLayoutBitmapBackground) &&
              (!pendingLayoutBitmapBackground || stagedLayoutBitmapBackgroundReady);
    if (ok) {
      prefs.putBool("layout_on", false);
      if (pendingLayoutBitmapBackground) {
        ok = readLayoutFile("/face_bg.stage", stagedBitmapBackground,
                            LAYOUT_BACKGROUND_BYTES) &&
             writeLayoutFile("/face_bg.bin", stagedBitmapBackground,
                             LAYOUT_BACKGROUND_BYTES);
      }
      for (int i = 0; i < pendingLayoutCount; ++i) {
        if (!ok) break;
        if (stagedLayoutItems[i].chunked) {
          const String stagePath = layoutBitmapPath(i, true);
          const String livePath = layoutBitmapPath(i, false);
          const size_t bytes = stagedLayoutItems[i].byteLength;
          if (!readLayoutFile(stagePath.c_str(), stagedItemBitmap, bytes) ||
              !writeLayoutFile(livePath.c_str(), stagedItemBitmap, bytes)) { ok = false; break; }
        }
        StaticJsonDocument<768> saved;
        const LayoutItem& item = stagedLayoutItems[i];
        saved["t"] = item.type; saved["v"] = item.text; saved["g"] = item.shape;
        saved["x"] = item.x; saved["y"] = item.y;
        saved["w"] = item.w; saved["h"] = item.h;
        saved["s"] = item.size; saved["c"] = item.color;
        saved["i"] = item.invert; saved["f"] = item.fill; saved["a"] = item.autoFit;
        saved["chunked"] = item.chunked; saved["bytes"] = item.byteLength;
        saved["n"] = i; saved["stored"] = true;
        String key = "layout_" + String(i);
        String data; serializeJson(saved, data);
        if (prefs.putString(key.c_str(), data) == 0) { ok = false; break; }
      }
    }
    if (ok) {
      if (pendingLayoutBitmapBackground) {
        memcpy(layoutBitmapBackground, stagedBitmapBackground, LAYOUT_BACKGROUND_BYTES);
        layoutBitmapBackgroundReady = true;
        LittleFS.remove("/face_bg.stage");
        prefs.remove("layout_img");
      }
      for (int i = 0; i < pendingLayoutCount; ++i) {
        if (!stagedLayoutItems[i].chunked) continue;
        const String stagePath = layoutBitmapPath(i, true);
        LittleFS.remove(stagePath.c_str());
        char key[16]; snprintf(key, sizeof(key), "bmp_%d", i);
        prefs.remove(key);
      }
      layoutBackground = pendingLayoutBackground;
      prefs.putUInt("layout_bg", layoutBackground);
      layoutCount = pendingLayoutCount;
      memcpy(layoutItems, stagedLayoutItems, sizeof(LayoutItem) * layoutCount);
      prefs.putInt("layout_n", layoutCount);
      layoutRefreshSeconds = pendingLayoutRefreshSeconds;
      prefs.putInt("layout_hz", layoutRefreshSeconds);
      prefs.putBool("layout_on", true);
      prefs.putBool("layout_img_on", pendingLayoutBitmapBackground);
      layoutBitmapBackgroundActive = pendingLayoutBitmapBackground;
      customLayoutActive = true;
      currentState = MODE_CLOCK;
      stateChanged = true;
    }
    layoutTransferActive = false;
    sendLayoutAck("commit", expected, ok);
  } else if (strcmp(cmd, "SET_LCD_ID") == 0) {
    Serial.println("[TFT] Hardware fixed to ILI9341 (0x9341); driver switching disabled.");
  } else if (strcmp(cmd, "REFRESH") == 0) {
    stateChanged = true;
  } else if (strcmp(cmd, "ACK_POMO") == 0) {
    const char* ackSessionId = params["session_id"] | "";
    handlePomoAck(ackSessionId);
  } else if (strcmp(cmd, "SET_TIME") == 0) {
    int yr = params["year"] | 2026;
    int mo = params["month"] | 1;
    int dy = params["day"] | 1;
    int hr = params["hour"] | 0;
    int mn = params["minute"] | 0;
    int sc = params["second"] | 0;
    if (rtcFound) {
      rtc.adjust(DateTime(yr, mo, dy, hr, mn, sc));
    }
    startBeep(1, 50, 2000);
    stateChanged = true;
  } else if (strcmp(cmd, "SET_POMO") == 0) {
    int w = params["work_min"] | 25;
    int b = params["break_min"] | 5;
    if (pomoRunning || w < 1 || w > 90 || b < 1 || b > 60) { sendPomoState(false); return; }
    pomoWorkDuration = w * 60;
    pomoBreakDuration = b * 60;
    if (!pomoRunning && pomoPhase == PHASE_WORK) {
      pomoTime = pomoWorkDuration;
      pomoInitialTime = pomoWorkDuration;
    }
    // Nhận task_type từ App (nếu App gửi kèm)
    const char* appTask = params["task_type"] | "";
    if (strlen(appTask) > 0) {
      current_pomo_task_type = String(appTask);
      pomoSelectingTask = false;  // Bỏ qua màn hình chọn task vì App đã gửi
    }
    startBeep(2, 60, 2500);
    stateChanged = true;
    sendPomoState();
  } else if (strcmp(cmd, "GET_POMO_STATE") == 0) {
    sendPomoState();
  } else if (strcmp(cmd, "POMO_CONTROL") == 0) {
    const char* action = params["action"] | "";
    bool ok = true;
    if (!strcmp(action, "reset")) { resetPomodoro(); }
    else if (!strcmp(action, "start") || !strcmp(action, "pause")) {
      const bool start = !strcmp(action, "start");
      if (pomoSelectingTask) ok = false;
      else if (pomoRunning != start) {
        currentState = MODE_POMODORO;
        applyRemotePomoControl();
      }
    } else ok = false;
    sendPomoState(ok);
  } else if (strcmp(cmd, "ALARMS_BEGIN") == 0) {
    const int count = params["count"] | -1;
    stagedAlarmCount = 0;
    alarmTransferActive = count >= 0 && count <= MAX_ALARMS;
    sendAlarmsAck(-1, count, alarmTransferActive);
  } else if (strcmp(cmd, "ALARMS_ITEM") == 0) {
    const int index = params["n"] | -1;
    const bool ok = alarmTransferActive && index == stagedAlarmCount &&
                    index >= 0 && index < MAX_ALARMS &&
                    decodeAlarm(params, stagedAlarms[index]);
    if (ok) ++stagedAlarmCount;
    sendAlarmsAck(index, stagedAlarmCount, ok);
  } else if (strcmp(cmd, "ALARMS_COMMIT") == 0) {
    const int expected = params["count"] | -1;
    const bool ok = alarmTransferActive && expected == stagedAlarmCount &&
                    storeAlarms(stagedAlarms, stagedAlarmCount);
    alarmTransferActive = false;
    sendAlarmsAck(-1, expected, ok);
  } else if (strcmp(cmd, "SET_ALARM") == 0) {
    const char* label = params["label"] | "BAO THUC";
    strncpy(alarmLabel, label, sizeof(alarmLabel) - 1);
    alarmLabel[sizeof(alarmLabel) - 1] = '\0';
    alarmDays = (uint8_t)constrain((int)(params["days"] | 0x7f), 1, 0x7f);

    if (params.containsKey("hour")) {
      alarmHour = params["hour"];
      alarmMinute = params["minute"] | 0;
      alarmEnabled = params["enabled"] | true;
    } else if (params.containsKey("time")) {
      const char* tStr = params["time"] | "";
      int h = -1, m = -1;
      if (sscanf(tStr, "%d:%d", &h, &m) >= 2) {
        alarmHour = h;
        alarmMinute = m;
        alarmEnabled = true;
      }
    }
    saveAlarmConfig();
    if (alarmHour >= 0 && alarmHour < 24 && alarmMinute >= 0 && alarmMinute < 60) {
      AlarmEntry legacy = {(uint8_t)alarmHour, (uint8_t)alarmMinute, alarmDays, alarmEnabled, ""};
      strlcpy(legacy.label, alarmLabel, sizeof(legacy.label));
      AlarmEntry updated[MAX_ALARMS];
      memcpy(updated, alarms, sizeof(AlarmEntry) * alarmCount);
      updated[0] = legacy;
      storeAlarms(updated, max(1, alarmCount));
    }
    startBeep(2, 60, 2500);

    char timeBuf[32];
    if (alarmEnabled && alarmHour >= 0 && alarmMinute >= 0) {
      snprintf(timeBuf, sizeof(timeBuf), "Hen luc %02d:%02d", alarmHour, alarmMinute);
      triggerNotification("DAT BAO THUC", timeBuf);
    } else {
      triggerNotification("BAO THUC", "Da tat bao thuc");
    }
  } else if (strcmp(cmd, "SHOW_NOTIF") == 0) {
    const char* title = params["title"] | "THONG BAO";
    const char* body  = params["body"]  | "";
    triggerNotification(title, body);
  } else if (strcmp(cmd, "MEDIA_CMD") == 0) {
    const char* act = params["action"] | "";
    if      (strcmp(act, "PLAY")  == 0) a2dp_sink.play();
    else if (strcmp(act, "PAUSE") == 0) a2dp_sink.pause();
    else if (strcmp(act, "NEXT")  == 0) a2dp_sink.next();
    else if (strcmp(act, "PREV")  == 0) a2dp_sink.previous();
  } else if (strcmp(cmd, "SET_MODE") == 0) {
    // App gui lenh chuyen giao dien: 0=Clock, 1=Pomodoro, 2=Timer, 3=Bluetooth
    int mode = params["mode"] | -1;
    if (mode >= 0 && mode < NUM_MODES) {
      Serial.printf("[MODE] BLE -> %d\n", mode);
      currentState = (AppState)mode;
      stateChanged = true;
      startBeep(1, 80, 2000);
    }
    sendDisplayState(mode >= 0 && mode < NUM_MODES);
  } else if (strcmp(cmd, "SET_THEME") == 0) {
    const int requestedTheme = params["theme_id"] | -1;
    if (requestedTheme < 0 || requestedTheme > 2) { sendDisplayState(false); return; }
    customLayoutActive = false;
    prefs.putBool("layout_on", false);
    currentThemeId = params["theme_id"] | 0;
    if (currentThemeId < 0 || currentThemeId > 2) currentThemeId = 0;
    focusByScreen[0] = currentThemeId;
    if (currentState == MODE_CLOCK) syncControlFocus();
    prefs.putInt("theme", currentThemeId);
    Serial.print("[BLE] SET_THEME id="); Serial.println(currentThemeId);

    // Color is sent as hex string "RRGGBB" from Flutter (avoids int32 overflow)
    const char* hexColor = params["color"] | "00E5FF";
    long colorVal = strtol(hexColor, nullptr, 16);
    uint8_t r = (colorVal >> 16) & 0xFF;
    uint8_t g = (colorVal >> 8)  & 0xFF;
    uint8_t b =  colorVal        & 0xFF;
    currentThemeColor = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
    Serial.printf("[BLE] color hex=%s => r=%d g=%d b=%d rgb565=%04X\n", hexColor, r, g, b, currentThemeColor);

    prefs.putUInt("theme_color", currentThemeColor);
    themeHasAnim = params["anim"] | false;
    stateChanged = true;
    sendDisplayState();
  } else if (strcmp(cmd, "GET_DISPLAY_STATE") == 0) {
    sendDisplayState();
  } else if (strcmp(cmd, "SYNC_SCHEDULE") == 0) {
    const char* day = params.containsKey("day") ? (params["day"] | "") : (doc["day"] | "");
    JsonArrayConst items = params.containsKey("items") ? params["items"].as<JsonArrayConst>() : doc["items"].as<JsonArrayConst>();
    bool ok = storeSchedule(day, items);
    sendScheduleAck(day, items.size(), ok);
  } else if (strcmp(cmd, "SCHEDULE_BEGIN") == 0) {
    const char* day = params["day"] | "";
    stagedSchedule.clear(); stagedSchedule.to<JsonArray>(); stagedScheduleDay = day;
    scheduleTransferActive = validScheduleDay(day);
    sendScheduleAck(day, 0, scheduleTransferActive);
  } else if (strcmp(cmd, "SCHEDULE_ITEM") == 0) {
    const char* day = params["day"] | "";
    const int index = params["n"] | -1;
    JsonArray items = stagedSchedule.as<JsonArray>();
    bool ok = scheduleTransferActive && stagedScheduleDay == day && index == (int)items.size() && index < 16 && validScheduleItem(params);
    if (ok) {
      JsonObject item = items.createNestedObject();
      item["hour"] = params["hour"]; item["minute"] = params["minute"]; item["label"] = params["label"];
      ok = !stagedSchedule.overflowed();
      if (!ok) scheduleTransferActive = false;
    }
    sendScheduleAck(day, items.size(), ok);
  } else if (strcmp(cmd, "SCHEDULE_COMMIT") == 0) {
    const char* day = params["day"] | "";
    JsonArrayConst items = stagedSchedule.as<JsonArrayConst>();
    bool ok = scheduleTransferActive && stagedScheduleDay == day && (params["count"] | -1) == (int)items.size() && storeSchedule(day, items);
    scheduleTransferActive = false;
    sendScheduleAck(day, items.size(), ok);
  }

}


// ==========================================
// VONG LAP CHINH
// ==========================================
void processSerialCommand(String sCmd) {
    sCmd.trim();
    if (sCmd == "INPUTS") {
      Serial.printf("[BUILD] NAV_MODE34_OK35_SELECT36 | %s %s | %s\n",__DATE__,__TIME__,__FILE__);
      Serial.printf("[INPUT] MODE%d=%d OK%d=%d SELECT%d=%d touch=%d mode=%d\n",
                    BTN_MODE, digitalRead(BTN_MODE), BTN_ACTION1, digitalRead(BTN_ACTION1), BTN_ACTION2, digitalRead(BTN_ACTION2),
                    touchEnabled, (int)currentState);
      logControlState("SNAPSHOT",KeyEvent::None);
    } else if (sCmd == "BEEP") {
      startBeep(3,100,2000);
      Serial.println("[IO] BEEP: 3 x 100 ms, GPIO23, 2000 Hz");
    } else if (sCmd == "STOP") {
      stopBuzzer();
      Serial.println("[IO] Buzzer stopped");
    } else if (sCmd == "TOUCH OFF" || sCmd == "TOUCH ON") {
      touchEnabled = (sCmd == "TOUCH ON");
      prefs.putBool("touch_en", touchEnabled);
      Serial.printf("[INPUT] touch=%d (saved)\n", touchEnabled);
    } else if (sCmd.startsWith("ID ") || sCmd.startsWith("id ")) {
      Serial.println("[TFT] Hardware fixed to ILI9341 (0x9341); driver switching disabled.");
    }
}
void serviceSerialInput() {
  static char line[64];
  static uint8_t length=0;
  static bool overflow=false;
  for (int budget=0; budget<64 && Serial.available(); ++budget) {
    char ch=(char)Serial.read();
    if (ch=='\n' || ch=='\r') {
      if (length && !overflow) { line[length]=0; processSerialCommand(String(line)); }
      length=0; overflow=false;
    } else if (length<sizeof(line)-1) line[length++]=ch;
    else overflow=true;
  }
}

void loop() {
  serviceSerialInput();

  updateBackgroundTimers();
  handleBuzzer(); // Xu ly coi da luong, khong block
  handleButtons();
  handleTouch();
  handleBLECommands();
  checkWeeklySchedule();

  // Poll RTC without touching the stable GPIO input path. One activation per RTC minute.
  static uint32_t lastAlarmPoll = 0, lastAlarmMinuteStamp = UINT32_MAX;
  if (rtcFound && uint32_t(millis() - lastAlarmPoll) >= 250) {
    lastAlarmPoll = millis();
    DateTime now = rtc.now();
    if (now.isValid() && now.year() >= 2024) {
      const uint32_t stamp = now.unixtime() / 60;
      if (stamp != lastAlarmMinuteStamp) {
        lastAlarmMinuteStamp = stamp;
        const int dayBit = (now.dayOfTheWeek() + 6) % 7;
        for (int i = 0; i < alarmCount; ++i) {
          const AlarmEntry& alarm = alarms[i];
          if (alarm.enabled && (alarm.days & (1 << dayBit)) &&
              alarm.hour == now.hour() && alarm.minute == now.minute()) {
            isAlarmActive = true;
            alarmStartTime = millis();
            startBeep(20, 420, 3000); // 20 x (420 ms on + 80 ms off) = 10 s.
            triggerNotification("BAO THUC!", alarm.label);
            break;
          }
        }
      }
    }
  }

  // Tu dong tat am bao thuc sau 30 giay neu khong bam nut (tat coi dut diem)
  if (isAlarmActive && (millis() - alarmStartTime >= 10000)) {
    isAlarmActive = false;
    stopBuzzer();
  }

  // Tu dong phuc hoi man hinh sau khi thong bao het han (an toan voi millis wrap-around)
  if (notifActive && (millis() - notifStartTime >= NOTIF_DURATION_MS)) {
    notifActive = false;
    stateChanged = true;
  }

  // Xu ly truyen hang doi Pomodoro khi BLE ket noi
  if (bleClientConnected && pomoQueueCount > 0) {
    processPomodoroQueue();
  }

  if (!notifActive) {
    syncControlFocus();
    const bool repaintControls=stateChanged;
    switch (currentState) {
      case MODE_CLOCK:     runClockMode();     break;
      case MODE_POMODORO:  runPomodoroMode();  break;
      case MODE_TIMER:     runTimerMode();     break;
      case MODE_BLUETOOTH: runBluetoothMode(); break;
    }
    drawControlFocus(repaintControls);
    if (repaintControls) drawNavigationHelp();
  }

  // MQTT: Publish trang thai Pomodoro moi 10 giay
  #ifdef ENABLE_WIFI_MQTT
    loopMQTT();
    static unsigned long lastPomoPublish = 0;
    if ((pomoRunning || currentState == MODE_POMODORO) && millis() - lastPomoPublish > 10000) {
      lastPomoPublish = millis();
      const char* phaseStr = (pomoPhase == PHASE_WORK) ? "work" :
                             (pomoPhase == PHASE_BREAK) ? "break" : "long_break";
      publishPomodoroState(true, pomoTime, phaseStr);
    }
  #endif
  delay(1); // Yield to Bluetooth and the independent input/buzzer task.
}

// ==========================================
// HÀM XỬ LÝ CÒI NON-BLOCKING (ĐÃ CHUẨN HÓA 128)
// ==========================================
void beepBuzzer(int times = 1, int onMs = 100, int freq = 3000) {
  startBeep(times, onMs, freq);
}

void stopBuzzer() { silenceBuzzer(); }
void startBeep(int times, int onMs, int freq) { requestBeep(times, onMs, freq); }
void handleBuzzer() { /* Timing is handled independently of display drawing. */ }

// ==========================================
// Focus is stored separately for Clock, task grid, Pomodoro controls,
// preset grid, Timer controls and Bluetooth controls.
int currentControlScreen() {
  if (currentState==MODE_CLOCK) return 0;
  if (currentState==MODE_POMODORO) return pomoSelectingTask?1:2;
  if (currentState==MODE_TIMER) return timerSelecting?3:4;
  return 5;
}

int currentControlCount() {
  const int screen=currentControlScreen();
  if (screen==0) return 3;
  if (screen==1) return NUM_TASK_TYPES;
  if (screen==2) return 4;
  if (screen==3) return NUM_PRESETS;
  if (screen==4) return 2;
  return isBluetoothConnected?3:0;
}

void syncControlFocus() {
  const int screen=currentControlScreen(), count=currentControlCount();
  if (count==0) { controlFocus=-1; return; }
  int& saved=focusByScreen[screen];
  if (saved<0 || saved>=count) saved=screen==0?currentThemeId:0;
  controlFocus=saved;
}

void setControlFocus(int index) {
  const int count=currentControlCount();
  if (index<0 || index>=count) return;
  focusByScreen[currentControlScreen()]=index;
  controlFocus=index;
}

bool dismissInputAlert() {
  if (!isAlarmActive && !notifActive) return false;
  isAlarmActive=false;
  notifActive=false;
  stopBuzzer();
  discardKeyEvents();
  stateChanged=true;
  return true;
}

void logControlState(const char* stage,KeyEvent event) {
  const char* modes[]={"CLOCK","POMODORO","TIMER","BLUETOOTH"};
  const char* screens[]={"CLOCK","TASK_SELECT","POMODORO_CONTROLS",
                         "TIMER_PRESETS","TIMER_CONTROLS","BLUETOOTH"};
  const char* pomoControls[]={"+5m","-5m","START/PAUSE","RESET"};
  const char* timerControls[]={"PAUSE/RESUME","STOP"};
  const char* btControls[]={"PREV","PLAY","NEXT"};
  const int screen=currentControlScreen();
  const char* focus="NONE";
  if (controlFocus>=0 && controlFocus<currentControlCount()) {
    if (screen==0) focus="THEME";
    else if (screen==1) focus=taskTypeLabels[controlFocus];
    else if (screen==2) focus=pomoControls[controlFocus];
    else if (screen==3) focus=timerLabels[controlFocus];
    else if (screen==4) focus=timerControls[controlFocus];
    else focus=btControls[controlFocus];
  }
  Serial.printf("[NAV %s] at=%lu event=%s mode=%s screen=%s controlFocus=%d(%s) task=%s running=%d remaining=%d alarm=%d notif=%d work=%d timerRunning=%d timerRemaining=%d timerSelecting=%d\n",
                stage,(unsigned long)millis(),keyEventName(event),modes[int(currentState)],
                screens[screen],controlFocus,focus,current_pomo_task_type.c_str(),
                pomoRunning,pomoTime,isAlarmActive,notifActive,pomoWorkDuration,
                timerRunning,timerSeconds,timerSelecting);
}

void activateFocusedControl() {
  syncControlFocus();
  logControlState("ACTIVATE",KeyEvent::Ok);
  if (controlFocus<0) return;
  const uint32_t now=millis();
  if (currentState==MODE_CLOCK) {
    if (currentThemeId==controlFocus) controlFocus=(controlFocus+1)%3;
    customLayoutActive = false;
    prefs.putBool("layout_on", false);
    currentThemeId=controlFocus;
    focusByScreen[0]=currentThemeId;
    prefs.putInt("theme",currentThemeId);
    lastMinute=-1;
    stateChanged=true;
  } else if (currentState==MODE_POMODORO && pomoSelectingTask) {
    selectedTaskTypeIndex=controlFocus;
    current_pomo_task_type=taskTypeLabels[selectedTaskTypeIndex];
    pomoSelectingTask=false;
    focusByScreen[2]=2; // A newly confirmed task starts at START/PAUSE.
    stateChanged=true;
  } else if (currentState==MODE_TIMER && timerSelecting) {
    selectedTimerPreset=controlFocus;
    timerInitial=timerSeconds=timerPresets[selectedTimerPreset];
    timerSelecting=false;
    timerRunning=true;
    timerFinished=false;
    timerLastTick=now;
    timerRemainderMs=0;
    lastTimerDraw=-2;
    focusByScreen[4]=0;
    stateChanged=true;
  } else if (currentState==MODE_POMODORO) {
    if (controlFocus==3) { resetPomodoro(); return; }
    if (controlFocus<2) {
      pomoWorkDuration=constrain(pomoWorkDuration+(controlFocus==0?300:-300),300,5400);
      if (!pomoRunning && pomoPhase==PHASE_WORK) {
        pomoTime=pomoInitialTime=pomoWorkDuration;
        pomoRemainderMs=0;
        lastPomoDraw=-2;
      }
      char msg[32];
      snprintf(msg,sizeof(msg),"Lam viec: %d phut",pomoWorkDuration/60);
      triggerNotification("POMODORO",msg);
      return;
    }
    if (pomoRunning) {
      ++pauseCount;
      pomoRemainderMs=uint32_t(now-pomoLastTick);
      pomoRunning=false;
    } else {
      pomoLastTick=now-pomoRemainderMs;
      pomoRunning=true;
    }
    if (pomoRunning && pomoStartTimeStr[0]=='\0') {
      if (rtcFound) {
        DateTime n=rtc.now();
        snprintf(pomoStartTimeStr,sizeof(pomoStartTimeStr),"%04d-%02d-%02dT%02d:%02d:%02d",
                 n.year(),n.month(),n.day(),n.hour(),n.minute(),n.second());
      } else {
        snprintf(pomoStartTimeStr,sizeof(pomoStartTimeStr),"2026-01-01T00:00:00");
      }
    }
    if (!stateChanged) drawPomodoroStartPauseButton(pomoRunning);
  } else if (currentState==MODE_TIMER) {
    if (controlFocus==1) { resetTimerToSelection(); return; }
    if (timerFinished)   { resetTimerToSelection(); return; }
    if (timerRunning) {
      timerRemainderMs=uint32_t(now-timerLastTick);
      timerRunning=false;
    } else {
      timerLastTick=now-timerRemainderMs;
      timerRunning=true;
    }
    if (!stateChanged) drawTimerStartPauseButton(timerRunning);
  } else if (currentState==MODE_BLUETOOTH && isBluetoothConnected) {
    if (controlFocus==0) a2dp_sink.previous();
    else if (controlFocus==1) a2dp_sink.play();
    else a2dp_sink.next();
  }
  syncControlFocus();
}

// Both touch navigation and the GPIO service enter through this dispatcher.
void handleNavigationEvent(KeyEvent event) {
  if (event==KeyEvent::None) return;
  updateBackgroundTimers();
  syncControlFocus();
  lastBtnPress=millis();
  logControlState("RECEIVED",event);
  if (dismissInputAlert()) {
    logControlState("ALERT_DISMISSED",event);
    return; // First press only dismisses, including MODE.
  }
  if (event==KeyEvent::Mode) {
    startBeep(1,40,2200);
    currentState=(AppState)((currentState+1)%NUM_MODES);
    syncControlFocus();
    stateChanged=true;
  } else if (event==KeyEvent::Select) {
    const int count=currentControlCount();
    if (count==0) { triggerNotification("BLUETOOTH","Chua ket noi"); return; }
    startBeep(1,40,2200);
    setControlFocus((controlFocus+1)%count);
  } else if (event==KeyEvent::Ok) {
    if (currentControlCount()==0) { triggerNotification("BLUETOOTH","Chua ket noi"); return; }
    startBeep(1,40,2200);
    activateFocusedControl();
  }
  logControlState("DONE",event);
}

void handleButtons() {
  serviceInputDiagnostics();
  const bool connected=a2dp_sink.is_connected();
  if (connected!=isBluetoothConnected) {
    isBluetoothConnected=connected;
    if (currentState==MODE_BLUETOOTH) stateChanged=true;
  }
  syncControlFocus();
  KeyEvent event;
  if (!readKeyEvent(event)) return;
  touchLatch.suppressUntilRelease(millis());
  Serial.printf("[INPUT] event=%s raw(MODE%d,OK%d,SELECT%d)=0x%X mode=%d controlFocus=%d source=GPIO\n",
                keyEventName(event),BTN_MODE,BTN_ACTION1,BTN_ACTION2,rawButtonLevels(),int(currentState),controlFocus);
  handleNavigationEvent(event);
}

void drawNavigationHelp() {
  tft.fillRect(0,230,320,10,C_BLACK);
  tft.setTextSize(1);
  tft.setTextColor(C_WHITE,C_BLACK);
  tft.setCursor(4,231);
  tft.print("MODE: MAN HINH | SELECT: DI CHUYEN | OK: CHON");
}

// Focus drawing never changes session state or activates a control.
void drawControlFocus(bool force) {
  static int previousScreen=-1, previousFocus=-1;
  const int screen=currentControlScreen();
  if (screen!=previousScreen) force=true;
  if (!force && previousFocus==controlFocus) return;
  if (screen==0) {
    const int y=currentThemeId==0?216:currentThemeId==1?0:210;
    const uint16_t bg=currentThemeId==0?0x0841:currentThemeId==1?C_BLACK:0x2008;
    tft.fillRect(0,y,320,12,bg);
    tft.setTextSize(1); tft.setTextColor(C_CYAN,bg);
    tft.setCursor(4,y+2); tft.print("THEME FOCUS: "); tft.print(controlFocus+1);
    tft.print(" | ACTIVE: "); tft.print(currentThemeId+1);
  } else if (screen==1 || screen==3) {
    if (force) {
      // Full-screen builders draw the grid and its current focus.
      updateSelectionOutline(screen==1,controlFocus,controlFocus);
    } else {
      updateSelectionOutline(screen==1,previousFocus,controlFocus);
    }
  } else if (screen==2) {
    const int y[4]={15,70,130,190}, h[4]={45,45,50,36};
    for (int i=0;i<4;++i)
      if (force || i==previousFocus || i==controlFocus)
        tft.drawRoundRect(218,y[i]-2,94,h[i]+4,7,i==controlFocus?C_WHITE:C_BLACK);
  } else if (screen==4) {
    for (int i=0;i<2;++i)
      tft.drawRoundRect(18+150*i,153,134,59,7,i==controlFocus?C_WHITE:C_BLACK);
  } else if (screen==5 && isBluetoothConnected) {
    for (int i=0;i<3;++i)
      tft.drawRoundRect(13+105*i,153,84,54,6,i==controlFocus?C_CYAN:C_GREEN);
  }
  previousScreen=screen; previousFocus=controlFocus;
}

// Touch hit testing selects an index, then invokes the very same OK action.
void handleTouchAt(int x,int y) {
  updateBackgroundTimers();
  syncControlFocus();
  if (dismissInputAlert()) { lastBtnPress=millis(); return; }
  if (y>=230) {
    handleNavigationEvent(x<100?KeyEvent::Mode:x<214?KeyEvent::Select:KeyEvent::Ok);
    return;
  }
  if (currentState==MODE_CLOCK) {
    const int chooserY=currentThemeId==0?216:currentThemeId==1?0:210;
    if (y>=chooserY && y<chooserY+12) {
      handleNavigationEvent(x<160?KeyEvent::Select:KeyEvent::Ok);
      return;
    }
  }
  // Preserve the existing header touch shortcut for changing screen.
  if (x<150 && y<40) { handleNavigationEvent(KeyEvent::Mode); return; }
  int hit=-1;
  const int screen=currentControlScreen();
  if (screen==1 || screen==3) {
    const bool task=screen==1;
    const int cols=task?2:4, bw=task?145:70, bh=task?85:75;
    const int gap=task?10:8, sx=task?10:8, sy=task?50:45;
    for (int i=0;i<currentControlCount();++i) {
      const int left=sx+(i%cols)*(bw+gap), top=sy+(i/cols)*(bh+gap);
      if (x>=left && x<left+bw && y>=top && y<top+bh) { hit=i; break; }
    }
  } else if (screen==2 && x>=220 && x<310) {
    const int top[4]={15,70,130,190}, height[4]={45,45,50,36};
    for (int i=0;i<4;++i) if (y>=top[i] && y<top[i]+height[i]) hit=i;
  } else if (screen==4 && y>=155 && y<210) {
    if (x>=20 && x<150) hit=0;
    else if (x>=170 && x<300) hit=1;
  } else if (screen==5 && isBluetoothConnected && y>=155 && y<205) {
    for (int i=0;i<3;++i) if (x>=15+105*i && x<95+105*i) hit=i;
  }
  if (hit<0) return;
  setControlFocus(hit);
  handleNavigationEvent(KeyEvent::Ok);
}

void handleTouch() {
  if (!touchEnabled) return;
  static uint32_t lastScan=0;
  const uint32_t now=millis();
  if (rawButtonLevels()!=7) {
    touchLatch.suppressUntilRelease(now);
    return;
  }
  if (uint32_t(now-lastScan)<15) return;
  lastScan=now;
  digitalWrite(33,HIGH);
  digitalWrite(2,HIGH);
  TSPoint p=ts.getPoint();
  digitalWrite(YP,HIGH); pinMode(YP,OUTPUT);
  digitalWrite(XM,HIGH); pinMode(XM,OUTPUT);
  pinMode(XP,OUTPUT); pinMode(YM,OUTPUT);

  static int16_t previousX=0, previousY=0;
  static uint8_t stableSamples=0;
  const int x=map(p.y,TS_LEFT,TS_RT,0,320), y=map(p.x,TS_TOP,TS_BOT,0,240);
  const bool valid=p.z>100 && p.z<850 && x>=0 && x<320 && y>=0 && y<240;
  if (valid) {
    if (abs(x-previousX)<=12 && abs(y-previousY)<=12) {
      if (stableSamples<3) ++stableSamples;
    } else stableSamples=1;
    previousX=x; previousY=y;
  } else stableSamples=0;
  if (!touchLatch.update(valid,now) || stableSamples<3) return;
  Serial.printf("[INPUT] Touch x=%d y=%d z=%d\n",x,y,p.z);
  handleTouchAt(x,y);
}

// Clock updates are independent of which screen is being rendered. Retain
// fractional milliseconds and catch up after a slow LCD/BLE operation.
void updateBackgroundTimers() {
  const uint32_t now=millis();
  if (pomoRunning && !pomoSelectingTask) {
    uint32_t ticks=uint32_t(now-pomoLastTick)/1000;
    while (ticks>0) {
      const uint32_t remaining=pomoTime>0?uint32_t(pomoTime):1;
      const uint32_t consumed=ticks<remaining?ticks:remaining;
      pomoLastTick+=consumed*1000;
      ticks-=consumed;
      pomoTime=pomoTime>int(consumed)?pomoTime-int(consumed):0;
      if (pomoTime==0) advancePomoPhase();
    }
  }
  if (timerRunning && !timerSelecting && !timerFinished) {
    const uint32_t ticks=uint32_t(now-timerLastTick)/1000;
    if (ticks>0) {
      const uint32_t remaining=timerSeconds>0?uint32_t(timerSeconds):0;
      const uint32_t consumed=ticks<remaining?ticks:remaining;
      timerSeconds-=int(consumed);
      timerLastTick+=consumed*1000;
      if (timerSeconds==0) {
        timerRunning=false;
        timerFinished=true;
        timerRemainderMs=0;
        lastTimerDraw=-2;
        if (!isAlarmActive && !notifActive) startBeep(4,250,2500);
      }
    }
  }
}


// Helper: draw analog clock hands (erase old, draw new)
static int _prevHx = -1, _prevHy = -1, _prevMx = -1, _prevMy = -1, _prevSx = -1, _prevSy = -1;
// Giảm radius từ 90 xuống 85, dời tâm xuống 125 để không bị cắt viền
static int _ACX = 240, _ACY = 125, _AR = 82; // Analog Clock center & radius

void drawAnalogHands(int hr, int mn, int sc, bool erase) {
  uint16_t faceCol = 0x0841; // dark face bg
  float hA = ((hr % 12) + mn / 60.0f) * 30.0f * DEG_TO_RAD - HALF_PI;
  float mA = (mn + sc / 60.0f) * 6.0f * DEG_TO_RAD - HALF_PI;
  float sA = sc * 6.0f * DEG_TO_RAD - HALF_PI;
  int hx = _ACX + (int)((_AR * 0.50f) * cos(hA));
  int hy = _ACY + (int)((_AR * 0.50f) * sin(hA));
  int mx = _ACX + (int)((_AR * 0.72f) * cos(mA));
  int my = _ACY + (int)((_AR * 0.72f) * sin(mA));
  int sx = _ACX + (int)((_AR * 0.82f) * cos(sA));
  int sy = _ACY + (int)((_AR * 0.82f) * sin(sA));
  if (erase) {
    if (_prevHx >= 0) { tft.drawLine(_ACX, _ACY, _prevHx, _prevHy, faceCol); tft.drawLine(_ACX+1, _ACY+1, _prevHx, _prevHy, faceCol); }
    if (_prevMx >= 0) { tft.drawLine(_ACX, _ACY, _prevMx, _prevMy, faceCol); tft.drawLine(_ACX+1, _ACY, _prevMx, _prevMy, faceCol); }
    if (_prevSx >= 0) { tft.drawLine(_ACX, _ACY, _prevSx, _prevSy, faceCol); }
    // Restore tick marks that hands may have crossed
    for (int i = 0; i < 12; i++) {
      float a = i * 30.0f * DEG_TO_RAD - HALF_PI;
      int x0 = _ACX + (int)((_AR - 4) * cos(a));
      int y0 = _ACY + (int)((_AR - 4) * sin(a));
      int x1 = _ACX + (int)((_AR - 14) * cos(a));
      int y1 = _ACY + (int)((_AR - 14) * sin(a));
      uint16_t tcol = (i == 0 || i == 3 || i == 6 || i == 9) ? C_WHITE : 0x8410;
      tft.drawLine(x0, y0, x1, y1, tcol);
    }
  }
  // Draw thick hour hand
  tft.drawLine(_ACX, _ACY, hx, hy, C_WHITE);
  tft.drawLine(_ACX+1, _ACY+1, hx, hy, C_WHITE);
  tft.drawLine(_ACX-1, _ACY, hx, hy, 0xC618);
  // Draw minute hand
  tft.drawLine(_ACX, _ACY, mx, my, C_WHITE);
  tft.drawLine(_ACX+1, _ACY, mx, my, 0xC618);
  // Draw second hand (red)
  tft.drawLine(_ACX, _ACY, sx, sy, C_RED);
  // Center dot
  tft.fillCircle(_ACX, _ACY, 4, C_WHITE);
  tft.fillCircle(_ACX, _ACY, 2, C_RED);
  _prevHx = hx; _prevHy = hy;
  _prevMx = mx; _prevMy = my;
  _prevSx = sx; _prevSy = sy;
}

// Helper: vẽ nền sunset đơn giản 3 dải màu thảy vì gradient 16 băng
void drawSunsetGradient() {
  // Dải trphên: cam vàng  (y=0..79)
  tft.fillRect(0,   0, 320, 80, 0xFCC0);  // cam nhạt
  // Dải giữa: đỏ cam (y=80..159)
  tft.fillRect(0,  80, 320, 80, 0xC840);  // cam sẫm
  // Dải dưới: tím đẮm (y=160..239)
  tft.fillRect(0, 160, 320, 80, 0x2008);  // tím đẮm
}

// ==========================================
// GIAO DIỆN 1: ĐỒNG HỒ
// ==========================================
void runClockMode() {
  static uint32_t lastPoll=0;
  if (!stateChanged && uint32_t(millis()-lastPoll)<100) return;
  lastPoll=millis();
  DateTime now = nowRtc();
  if (customLayoutActive) {
    static int customMinute = -1;
    static int customSecond = -1;
    if (stateChanged || customMinute != now.minute() ||
        (layoutRefreshSeconds == 1 && customSecond != now.second())) {
      drawCustomLayout(now);
      customMinute = now.minute();
      customSecond = now.second();
      stateChanged = false;
    }
    return;
  }
  static int lastDay   = -1;
  static int lastSecond = -1;
  static int lastTemp  = -99;

  static int lastHour  = -1;

  // ── INIT: vẽ nền tĩnh khi theme đổi ──
  if (stateChanged) {
    _prevHx = _prevHy = _prevMx = _prevMy = _prevSx = _prevSy = -1;
    lastDay = -1; lastHour = -1; lastMinute = -1; lastSecond = -1; lastTemp = -99;

    if (currentThemeId == 0) {
      // ── FLIP CLOCK: nền xám tối, 2 card bo tròn ──
      tft.fillScreen(0x0841);
      uint16_t cardBg = 0x2104, cardBr = 0x4A69, shadow = 0x1082;
      // Card HH (bên trái)
      tft.fillRoundRect(5, 20, 148, 195, 12, cardBg);
      tft.drawRoundRect(5, 20, 148, 195, 12, cardBr);
      tft.fillRect(5, 108, 148, 3, shadow);   // divider
      // Card MM (bên phải)
      tft.fillRoundRect(163, 20, 150, 195, 12, cardBg);
      tft.drawRoundRect(163, 20, 150, 195, 12, cardBr);
      tft.fillRect(163, 108, 150, 3, shadow);
      // Labels nhỏ
      tft.setTextColor(0x4A69, 0x0841); tft.setTextSize(1);
      tft.setCursor(62, 217); tft.print("HOUR");
      tft.setCursor(220, 217); tft.print("MIN");
    }
    else if (currentThemeId == 1) {
      // ── ANALOG + DIGITAL: nền đen, mặt đồng hồ analog bên phải ──
      tft.fillScreen(C_BLACK);
      // Vẽ mặt analog (bên phải màn hình, nhỏ hơn)
      tft.fillCircle(_ACX, _ACY, _AR, 0x0841);
      tft.drawCircle(_ACX, _ACY, _AR, C_WHITE);
      // Tick marks
      for (int i = 0; i < 12; i++) {
        float a = i * 30.0f * DEG_TO_RAD - HALF_PI;
        int x0 = _ACX + (int)((_AR - 4) * cos(a));
        int y0 = _ACY + (int)((_AR - 4) * sin(a));
        int x1 = _ACX + (int)((_AR - 13) * cos(a));
        int y1 = _ACY + (int)((_AR - 13) * sin(a));
        tft.drawLine(x0, y0, x1, y1, C_WHITE);
      }
      // Số 4 hướng
      tft.setTextSize(1); tft.setTextColor(currentThemeColor, 0x0841);
      tft.setCursor(_ACX - 3,  _ACY - _AR + 14); tft.print("12");
      tft.setCursor(_ACX + _AR - 14, _ACY - 4);  tft.print("3");
      tft.setCursor(_ACX - 3,  _ACY + _AR - 20); tft.print("6");
      tft.setCursor(_ACX - _AR + 6, _ACY - 4);   tft.print("9");
      // Divider
      tft.drawLine(148, 0, 148, 240, 0x2945);
    }
    else {
      // ── SUNSET: gradient bầu trời ──
      drawSunsetGradient();
    }
    stateChanged = false;
  }

  DateTime n = now;
  int di = n.dayOfTheWeek() == 0 ? 6 : n.dayOfTheWeek() - 1;
  const char* daysShort[] = {"MON","TUE","WED","THU","FRI","SAT","SUN"};
  const char* daysVi[]    = {"Hai","Ba","Tu","Nam","Sau","Bay","CN"};

  // ════════════════════════════════════════════════════════
  // THEME 0 — FLIP CLOCK
  // ════════════════════════════════════════════════════════
  if (currentThemeId == 0) {
    uint16_t cardBg = 0x2104;
    // Giờ (phần trên card trái)
    if (n.hour() != lastHour) {
      tft.fillRoundRect(9, 24, 140, 80, 10, cardBg);
      tft.setTextColor(currentThemeColor, cardBg); tft.setTextSize(8);
      char hh[4]; sprintf(hh, "%02d", n.hour());
      tft.setCursor(18, 32); tft.print(hh);
      lastHour = n.hour();
    }
    // Phút (phần trên card phải)
    if (n.minute() != lastMinute) {
      tft.fillRoundRect(167, 24, 142, 80, 10, cardBg);
      tft.setTextColor(currentThemeColor, cardBg); tft.setTextSize(8);
      char mm[4]; sprintf(mm, "%02d", n.minute());
      tft.setCursor(175, 32); tft.print(mm);
      // Phần dưới card phải: giá trị phút mờ
      tft.fillRoundRect(167, 112, 142, 98, 10, cardBg);
      tft.setTextColor(0x8C51, cardBg); tft.setTextSize(8);
      tft.setCursor(175, 120); tft.print(mm);
      lastMinute = n.minute();
    }
    // Phần dưới card trái: giây lớn + AM/PM
    if (n.second() != lastSecond) {
      tft.fillRoundRect(9, 112, 140, 98, 10, cardBg);
      // AM/PM nhỏ trên cùng
      tft.setTextColor(0x6B6D, cardBg); tft.setTextSize(2);
      tft.setCursor(20, 118); tft.print(n.hour() < 12 ? "AM" : "PM");
      // Giây to giữa
      tft.setTextColor(0xFD60, cardBg); tft.setTextSize(5);
      char sc[4]; sprintf(sc, "%02d", n.second());
      tft.setCursor(25, 145); tft.print(sc);
      // Chữ ":" nhỏ
      tft.setTextColor(0x4A69, cardBg); tft.setTextSize(2);
      tft.setCursor(12, 148); tft.print("s");
      lastSecond = n.second();
    }
    // Date + nhiệt độ (thanh trên cùng)
    if (n.day() != lastDay) {
      tft.fillRect(0, 0, 320, 19, 0x0841);
      tft.setTextColor(0x6B6D, 0x0841); tft.setTextSize(1);
      tft.setCursor(4, 5);
      char ds[32]; sprintf(ds, "%s %02d/%02d/%04d", daysShort[di], n.day(), n.month(), n.year());
      tft.print(ds);
      lastDay = n.day();
    }
    // Nhiệt độ góc phải trên
    int tmp = rtcTempC();
    if (tmp != lastTemp) {
      tft.fillRect(240, 0, 80, 19, 0x0841);
      tft.setTextColor(0xFD60, 0x0841); tft.setTextSize(1);
      char ts[16]; sprintf(ts, "%d'C", tmp);
      tft.setCursor(246, 5); tft.print(ts);
      lastTemp = tmp;
    }
  }

  // ════════════════════════════════════════════════════════
  // THEME 1 — ANALOG + DIGITAL
  // ════════════════════════════════════════════════════════
  else if (currentThemeId == 1) {
    // Analog hands + Digital Seconds (cập nhật đồng bộ mỗi giây)
    if (n.second() != lastSecond) {
      drawAnalogHands(n.hour(), n.minute(), n.second(), lastSecond != -1);
      // Giây dưới số giờ phút (trái)
      tft.fillRect(0, 130, 90, 20, C_BLACK);
      tft.setTextColor(0x4208, C_BLACK); tft.setTextSize(2);
      tft.setCursor(4, 132);
      char sc2[8]; sprintf(sc2, ":%02d", n.second());
      tft.print(sc2);
      lastSecond = n.second();
    }
    // Digital time (left panel) — Size 5
    if (n.minute() != lastMinute) {
      tft.fillRect(0, 15, 145, 130, C_BLACK);
      tft.setTextColor(currentThemeColor, C_BLACK); tft.setTextSize(5);
      char hm[4];
      sprintf(hm, "%02d", n.hour());
      tft.setCursor(5, 20); tft.print(hm);
      sprintf(hm, "%02d", n.minute());
      tft.setCursor(5, 78); tft.print(hm);
      // Dấu ":" nhấp nháy giữa
      tft.setTextColor(currentThemeColor, C_BLACK); tft.setTextSize(4);
      tft.setCursor(92, 44); tft.print(":");
      lastMinute = n.minute();
    }
    // Nhiệt độ
    int tmp = rtcTempC();
    if (tmp != lastTemp) {
      tft.fillRect(0, 155, 145, 30, C_BLACK);
      tft.setTextColor(0xFD60, C_BLACK); tft.setTextSize(3);
      tft.setCursor(4, 158);
      char ts[16]; sprintf(ts, "%d'C", tmp);
      tft.print(ts);
      lastTemp = tmp;
    }
    // Ngày + thứ
    if (n.day() != lastDay) {
      tft.fillRect(0, 188, 145, 40, C_BLACK);
      tft.setTextColor(0x6B6D, C_BLACK); tft.setTextSize(2);
      tft.setCursor(4, 192);
      char ds[16]; sprintf(ds, "T.%s", daysVi[di]);
      tft.print(ds);
      tft.setCursor(4, 212);
      char d2[16]; sprintf(d2, "%02d/%02d", n.day(), n.month());
      tft.print(d2);
      lastDay = n.day();
    }
  }

  // ════════════════════════════════════════════════════════
  // THEME 2 — SUNSET GRADIENT
  // ════════════════════════════════════════════════════════
  else {
    // SUNSET — Dùng 3 màu nền đơn giản, không cần clearGradient phức tạp
    // Nền = 3 vEarth strips đã vẽ sẵn. Chỉ xóa bằng đúng màu nền tương ứng.
    // Màu 3 dải: cam nhạt (y<80), cam sẫm (y<160), tím (y>=160)

    auto clearBand = [&](int y0, int h, int x, int w) {
      // Tô lại đúng màu nền từng dải
      int y1 = y0 + h;
      if (y0 < 80)  tft.fillRect(x, y0, w, min(h, 80 - y0), 0xFCC0);
      if (y0 < 160 && y1 > 80)  tft.fillRect(x, max(y0, 80), w, min(y1, 160) - max(y0, 80), 0xC840);
      if (y1 > 160) tft.fillRect(x, max(y0, 160), w, y1 - max(y0, 160), 0x2008);
    };

    // Ngày (y=4, h=18)
    if (n.day() != lastDay) {
      clearBand(2, 20, 0, 320);
      tft.setTextColor(currentThemeColor); tft.setTextSize(2);
      tft.setCursor(6, 5);
      char ds[32]; sprintf(ds, "%s %02d/%02d/%04d", daysVi[di], n.day(), n.month(), n.year());
      tft.print(ds);
      lastDay = n.day();
    }
    // Giờ:Phút (y=30, size=7 -> h~56)
    if (n.minute() != lastMinute) {
      clearBand(28, 62, 0, 230);
      tft.setTextColor(currentThemeColor); tft.setTextSize(6);
      tft.setCursor(6, 30);
      char hm[8]; sprintf(hm, "%02d:%02d", n.hour(), n.minute());
      tft.print(hm);
      lastMinute = n.minute();
    }
    // Giây (y=30, cạnh phải)
    if (n.second() != lastSecond) {
      clearBand(33, 26, 232, 82);
      tft.setTextColor(0xFFE0); tft.setTextSize(3);
      tft.setCursor(236, 36);
      char sc2[8]; sprintf(sc2, ":%02d", n.second());
      tft.print(sc2);
      lastSecond = n.second();
    }
    // Nhiệt độ (y=100)
    int tmp = rtcTempC();
    if (tmp != lastTemp) {
      clearBand(95, 38, 0, 160);
      tft.setTextColor(currentThemeColor); tft.setTextSize(3);
      tft.setCursor(6, 98);
      char ts[16]; sprintf(ts, "* %d'C", tmp);
      tft.print(ts);
      lastTemp = tmp;
    }
  }
}




// ==========================================
// GIAO DIỆN 2: POMODORO 
// ==========================================
const char* phaseLabel(PomoPhase ph) {
  if (ph == PHASE_WORK) return "LAM VIEC";
  if (ph == PHASE_BREAK) return "NGHI NGAN";
  return "NGHI DAI";
}
uint16_t phaseColor(PomoPhase ph) {
  if (ph == PHASE_WORK) return C_CYAN;
  if (ph == PHASE_BREAK) return C_GREEN;
  return C_PURPLE;
}

// ==========================================
// GỬI DỮ LIỆU POMODORO QUA BLUETOOTH SPP
// Bao gồm task_type để AI quản lý được nội dung công việc
// ==========================================
void sendPomodoroData(bool completed) {
  // Lay thoi gian ket thuc tu RTC (hoac fallback neu RTC khong san sang)
  char endTimeStr[25] = "";
  int temp = 25;
  if (rtcFound) {
    DateTime n = rtc.now();
    snprintf(endTimeStr, sizeof(endTimeStr),
      "%04d-%02d-%02dT%02d:%02d:%02d",
      n.year(), n.month(), n.day(), n.hour(), n.minute(), n.second());
    temp = rtcTempC();
  } else {
    snprintf(endTimeStr, sizeof(endTimeStr), "2026-01-01T00:00:00");
  }

  // Persist a device-scoped sequence: resetting a session or missing RTC must
  // never reuse an ID and cause Flutter/backend to discard a new session.
  const uint64_t sequence = prefs.getULong64("pomo_seq", 0) + 1;
  if (prefs.putULong64("pomo_seq", sequence) != sizeof(uint64_t)) {
    triggerNotification("LOI LUU PHIEN", "Khong ghi duoc session ID");
    return;
  }
  char sessionId[48];
  snprintf(sessionId, sizeof(sessionId), "pomo_%012llx_%llu",
           (unsigned long long)ESP.getEfuseMac(), (unsigned long long)sequence);

  StaticJsonDocument<1024> packet;
  packet["mode"] = "pomodoro";
  packet["session_id"] = sessionId;
  packet["task_type"] = current_pomo_task_type;
  packet["work_min"] = pomoWorkDuration / 60;
  packet["break_min"] = pomoBreakDuration / 60;
  packet["pauses"] = pauseCount;
  packet["completed"] = completed;
  packet["session"] = pomoSessionCount;
  packet["start_time"] = pomoStartTimeStr[0] != '\0' ? pomoStartTimeStr : endTimeStr;
  packet["end_time"] = endTimeStr;
  packet["temperature"] = temp;
  if (packet.overflowed()) {
    triggerNotification("LOI LUU PHIEN", "Du lieu Pomodoro qua dai");
    return;
  }
  String jsonPayload;
  serializeJson(packet, jsonPayload);

  // Enqueue vao hang doi FIFO NVS (toi da 5 phien, khong ghi de phien chua ACK)
  bool enqueued = enqueuePomodoro(jsonPayload.c_str(), sessionId);
  if (!enqueued) {
    triggerNotification("BO NHO DAY", "Khong the luu them Pomodoro");
  }

  // Truyen du lieu qua BLE neu dang ket noi
  processPomodoroQueue();
}


void resetPomodoro() {
  startBeep(2, 100, 1800);

  // Gửi dữ liệu về App TRƯỚC khi reset (completed = false vì bị ngắt)
  if (pomoPhase == PHASE_WORK && (pomoRunning || pomoTime < pomoInitialTime)) {
    sendPomodoroData(false);
  }

  pomoRunning = false;
  pomoPhase = PHASE_WORK;
  pomoSessionCount = 0;
  pauseCount = 0;  // Reset đếm pause
  pomoStartTimeStr[0] = '\0';  // Clear thời gian bắt đầu cho phiên mới
  pomoTime = pomoWorkDuration;
  pomoInitialTime = pomoWorkDuration;
  pomoRemainderMs = 0;
  pomoSelectingTask = true;  // Quay lại màn hình chọn Task cho phiên mới
  // Keep the last confirmed task and the independently selected grid focus.
  stateChanged = true;
}

void advancePomoPhase() {
  if (pomoPhase == PHASE_WORK) {
    // Phiên làm việc hoàn thành! Gửi dữ liệu về App (completed = true)
    sendPomodoroData(true);
    pauseCount = 0; // Reset đếm pause cho phiên mới
    pomoStartTimeStr[0] = '\0';  // Clear thời gian bắt đầu cho phiên mới

    pomoSessionCount++;
    if (pomoSessionCount % 4 == 0) {
      pomoPhase = PHASE_LONG_BREAK;
      pomoTime = pomoLongBreakDuration;
    } else {
      pomoPhase = PHASE_BREAK;
      pomoTime = pomoBreakDuration;
    }
    if (!isAlarmActive && !notifActive) startBeep(4, 200, 4000);
  } else {
    pomoPhase = PHASE_WORK;
    pomoTime = pomoWorkDuration;
    // Ghi start_time cho phiên work mới (tự động bắt đầu sau break)
    if (rtcFound) {
      DateTime n = rtc.now();
      snprintf(pomoStartTimeStr, sizeof(pomoStartTimeStr),
        "%04d-%02d-%02dT%02d:%02d:%02d",
        n.year(), n.month(), n.day(), n.hour(), n.minute(), n.second());
    } else {
      snprintf(pomoStartTimeStr, sizeof(pomoStartTimeStr), "2026-01-01T00:00:00");
    }
    if (!isAlarmActive && !notifActive) startBeep(4, 200, 4000);
  }
  pomoInitialTime = pomoTime;
  lastPomoDraw = -2;
}

// ==========================================
// GIAO DIỆN CHỌN LOẠI CÔNG VIỆC (TASK TYPE)
// Giải quyết: "cách thức thực hiện trong đồng hồ"
// ==========================================
// Only repaint the old/new focus outlines; keep the labels and background.
void updateSelectionOutline(bool task, int previous, int selected) {
  const int cols=task?2:4, bw=task?145:70, bh=task?85:75;
  const int gx=task?10:8, gy=task?10:8;
  const int sx=task?10:8, sy=task?50:45;
  const int radius=task?6:4;
  tft.drawRoundRect(sx+(previous%cols)*(bw+gx)+2,
                    sy+(previous/cols)*(bh+gy)+2,bw-4,bh-4,radius,C_DARK_GRAY);
  tft.drawRoundRect(sx+(selected%cols)*(bw+gx)+2,
                    sy+(selected/cols)*(bh+gy)+2,bw-4,bh-4,radius,C_WHITE);
}

void drawTaskSelectGUI() {
  tft.fillScreen(C_BLACK);
  // Tiêu đề
  tft.setTextColor(C_CYAN); tft.setTextSize(2);
  tft.setCursor(30, 12); tft.print("CHON CONG VIEC");

  // Vẽ 4 nút grid 2x2
  int cols = 2, bw = 145, bh = 85, gx = 10, gy = 10, startX = 10, startY = 50;
  for (int i = 0; i < NUM_TASK_TYPES; i++) {
    int col = i % cols, row = i / cols;
    int x = startX + col * (bw + gx);
    int y = startY + row * (bh + gy);

    tft.fillRoundRect(x, y, bw, bh, 8, C_DARK_GRAY);
    tft.drawRoundRect(x, y, bw, bh, 8, taskTypeColors[i]);
    if (i == focusByScreen[1]) tft.drawRoundRect(x+2, y+2, bw-4, bh-4, 6, C_WHITE);

    // Tên task căn giữa
    tft.setTextColor(taskTypeColors[i]); tft.setTextSize(2);
    int tw = strlen(taskTypeLabels[i]) * 12;
    tft.setCursor(x + (bw - tw) / 2, y + bh / 2 - 8);
    tft.print(taskTypeLabels[i]);
  }
}

void drawPomodoroStartPauseButton(bool running) {
  if (!running) {
    tft.fillRoundRect(220, 130, 90, 50, 6, C_GREEN);
    tft.setTextColor(C_BLACK, C_GREEN);
    tft.setTextSize(2);
    tft.setCursor(235, 147);
    tft.print("START");
  } else {
    tft.fillRoundRect(220, 130, 90, 50, 6, C_ORANGE);
    tft.setTextColor(C_BLACK, C_ORANGE);
    tft.setTextSize(2);
    tft.setCursor(235, 147);
    tft.print("PAUSE");
  }
}

void drawPomodoroGUI() {
  tft.fillScreen(C_BLACK);

  // Hiển thị task đã chọn ở góc trên trái
  tft.setTextColor(taskTypeColors[selectedTaskTypeIndex]); tft.setTextSize(1);
  tft.setCursor(12, 5); tft.print("Task: ");
  tft.print(current_pomo_task_type.c_str());

  tft.drawRoundRect(10, 15, 200, 213, 8, C_DARK_GRAY);
  tft.fillRoundRect(220, 15, 90, 45, 6, C_DARK_GRAY); tft.setTextColor(C_CYAN); tft.setTextSize(2); tft.setCursor(245, 28); tft.print("+5m");
  tft.fillRoundRect(220, 70, 90, 45, 6, C_DARK_GRAY); tft.setTextColor(C_CYAN); tft.setTextSize(2); tft.setCursor(245, 83); tft.print("-5m");
  drawPomodoroStartPauseButton(pomoRunning);
  tft.fillRoundRect(220, 190, 90, 36, 6, C_RED); tft.setTextColor(C_WHITE); tft.setTextSize(2); tft.setCursor(238, 200); tft.print("RESET");
  lastPomoSessionDraw = -2; lastPomoPhaseDraw = (PomoPhase)-1;
}

void runPomodoroMode() {
  // Nếu đang chọn Task → hiển thị màn hình chọn, chưa đếm giờ
  if (pomoSelectingTask) {
    if (stateChanged) { drawTaskSelectGUI(); stateChanged = false; }
    return;
  }

  if (stateChanged) { drawPomodoroGUI(); stateChanged = false; lastPomoDraw = -2; }

  if (pomoPhase != lastPomoPhaseDraw || pomoSessionCount != lastPomoSessionDraw) {
    tft.fillRect(22, 18, 190, 18, C_BLACK);
    tft.setTextColor(phaseColor(pomoPhase)); tft.setTextSize(1);
    tft.setCursor(22, 20); tft.print(phaseLabel(pomoPhase));
    char sess[24]; sprintf(sess, "Phien: %d", pomoSessionCount);
    tft.setCursor(140, 20); tft.setTextColor(C_MID_GRAY); tft.print(sess);
    lastPomoPhaseDraw = pomoPhase; lastPomoSessionDraw = pomoSessionCount;
  }

  if (pomoTime != lastPomoDraw) {
    int m = pomoTime / 60; int s = pomoTime % 60; char pomoStr[12]; sprintf(pomoStr, "%02d:%02d", m, s);
    tft.setTextColor(phaseColor(pomoPhase), C_BLACK); tft.setTextSize(6); tft.setCursor(25, 100); tft.print(pomoStr);
    int totalSegments = 10;
    float progress = (pomoInitialTime > 0) ? ((float)pomoTime / pomoInitialTime) : 0.0f;
    int activeSegments = (int)(progress * totalSegments);
    static int lastActiveSegments = -1;
    if (activeSegments != lastActiveSegments || lastPomoDraw == -2) {
      for (int i = 0; i < totalSegments; i++) {
        int segX = 22 + (i * 18);
        uint16_t segColor = phaseColor(pomoPhase);
        if (i < activeSegments) tft.fillRect(segX, 40, 14, 15, segColor);
        else tft.fillRect(segX, 40, 14, 15, C_DARK_GRAY);
      }
      lastActiveSegments = activeSegments;
    }
    lastPomoDraw = pomoTime;
  }
}

// ==========================================
// GIAO DIỆN 3: ĐẾM NGƯỢC
// ==========================================
void resetTimerToSelection() {
  timerRunning = false;
  timerFinished = false;
  timerSelecting = true;
  timerRemainderMs = 0;
  stateChanged = true;
}

void drawTimerSelectGUI() {
  tft.fillScreen(C_BLACK);
  tft.setTextColor(C_CYAN); tft.setTextSize(2); tft.setCursor(70, 15); tft.print("CHON THOI GIAN");
  int cols = 4, bw = 70, bh = 75, gx = 8, gy = 8, startX = 8, startY = 45;
  for (int i = 0; i < NUM_PRESETS; i++) {
    int col = i % cols, row = i / cols;
int x = startX + col * (bw + gx), y = startY + row * (bh + gy);
    tft.fillRoundRect(x, y, bw, bh, 6, C_DARK_GRAY);
    tft.drawRoundRect(x, y, bw, bh, 6, C_CYAN);
    if (i == focusByScreen[3]) tft.drawRoundRect(x+2, y+2, bw-4, bh-4, 4, C_WHITE);
    tft.setTextColor(C_WHITE); tft.setTextSize(2);
    int tw = strlen(timerLabels[i]) * 12;
    tft.setCursor(x + (bw - tw) / 2, y + bh / 2 - 8);
    tft.print(timerLabels[i]);
  }
}

void drawTimerStartPauseButton(bool running) {
  tft.fillRoundRect(20, 155, 130, 55, 6, running ? C_ORANGE : C_GREEN);
  tft.setTextColor(C_BLACK, running ? C_ORANGE : C_GREEN);
  tft.setTextSize(2);
  tft.setCursor(running ? 45 : 35, 175);
  tft.print(timerFinished ? "DONE" : running ? "PAUSE" : "RESUME");
}

void drawTimerRunGUI() {
  tft.fillScreen(C_BLACK);
  tft.drawRoundRect(10, 15, 300, 213, 8, C_DARK_GRAY);
  drawTimerStartPauseButton(timerRunning);
  tft.fillRoundRect(170, 155, 130, 55, 6, C_RED); tft.setTextColor(C_WHITE); tft.setTextSize(2);
  tft.setCursor(215, 175); tft.print("STOP");
  lastTimerDraw = -2;
}

void runTimerMode() {
  const bool fullRedraw=stateChanged;
  if (stateChanged) {
    if (timerSelecting) drawTimerSelectGUI(); else drawTimerRunGUI();
    stateChanged = false;
  }

  if (timerSelecting) return;

  static int lastFinishedDraw = -1;
  if (fullRedraw || int(timerFinished) != lastFinishedDraw) {
    drawTimerStartPauseButton(timerRunning);
    tft.fillRect(20, 30, 280, 20, C_BLACK);
    tft.setTextSize(2); tft.setTextColor(timerFinished ? C_RED : C_WHITE);
    tft.setCursor(timerFinished ? 95 : 80, 30);
    tft.print(timerFinished ? "DA HET GIO!" : "DANG DEM NGUOC");
    lastFinishedDraw = timerFinished;
  }

  if (timerSeconds != lastTimerDraw) {
    int m = timerSeconds / 60; int s = timerSeconds % 60;
    char tStr[12]; sprintf(tStr, "%02d:%02d", m, s);
    tft.fillRect(20, 60, 280, 70, C_BLACK);
    tft.setTextColor(timerFinished ? C_RED : C_CYAN, C_BLACK); tft.setTextSize(6);
    tft.setCursor(timerFinished ? 55 : 75, 70); tft.print(timerFinished ? "00:00" : tStr);

    static int lastFillW = -1;
    if (timerInitial > 0) {
      int barW = 280; float progress = (float)timerSeconds / timerInitial;
      int fillW = (int)(barW * progress);
      if (fillW != lastFillW || lastTimerDraw == -2) {
        tft.fillRect(20, 130, fillW, 14, timerFinished ? C_RED : C_GREEN);
        if (barW > fillW) {
          tft.fillRect(20 + fillW, 130, barW - fillW, 14, C_DARK_GRAY);
        }
        lastFillW = fillW;
      }
    }
    lastTimerDraw = timerSeconds;
  }
}

// ==========================================
// GIAO DIỆN 4: BLUETOOTH
// ==========================================
void drawBTIcon(int cx, int cy, int size, uint16_t color) {
  int w = size * 0.7; int h = size * 0.5;
  for (int i = -1; i <= 1; i++) {
    tft.drawLine(cx + i, cy - size, cx + i, cy + size, color); tft.drawLine(cx + i, cy - size, cx + w + i, cy - h, color);
    tft.drawLine(cx + w + i, cy - h, cx + i, cy, color); tft.drawLine(cx + i, cy, cx + w + i, cy + h, color);
    tft.drawLine(cx + w + i, cy + h, cx + i, cy + size, color); tft.drawLine(cx - w + i, cy - h, cx + i, cy, color); tft.drawLine(cx - w + i, cy + h, cx + i, cy, color);
  }
}
void runBluetoothMode() {
  if (stateChanged || isBluetoothConnected != lastBluetoothState) {
    if (isBluetoothConnected) {
      tft.fillScreen(C_GREEN);
      tft.drawCircle(160, 60, 40, C_WHITE);
      drawBTIcon(160, 60, 20, C_WHITE);
      tft.setTextSize(3); tft.setTextColor(C_WHITE); tft.setCursor(75, 115); tft.print("CONNECTED");
      tft.fillRoundRect(15, 155, 80, 50, 5, C_DARK_GRAY);
      tft.fillRoundRect(120, 155, 80, 50, 5, C_WHITE);
      tft.fillRoundRect(225, 155, 80, 50, 5, C_DARK_GRAY);
      tft.setTextSize(2);
      tft.setTextColor(C_WHITE); tft.setCursor(30, 172); tft.print("PREV");
      tft.setTextColor(C_BLACK); tft.setCursor(135, 172); tft.print("PLAY");
      tft.setTextColor(C_WHITE); tft.setCursor(240, 172); tft.print("NEXT");
    } else {
      tft.fillScreen(C_BLACK);
      tft.drawCircle(160, 100, 50, C_WHITE);
      tft.drawCircle(160, 100, 51, C_WHITE);
      drawBTIcon(160, 100, 25, C_WHITE);
      tft.setTextSize(2); tft.setTextColor(C_WHITE);
      tft.setCursor(85, 180); tft.print("READY TO PAIR");
      tft.setTextColor(C_MID_GRAY); tft.setTextSize(1);
      tft.setCursor(35, 220); tft.print("Go to Settings -> Bluetooth");
    }
    lastBluetoothState = isBluetoothConnected;
    stateChanged = false;
  }
}

void applyRemotePomoControl() {
  // BLE control changes the timer without changing the physical-button focus.
  const uint32_t now = millis();
  if (pomoRunning) {
    ++pauseCount;
    pomoRemainderMs = uint32_t(now - pomoLastTick);
    pomoRunning = false;
  } else {
    pomoLastTick = now - pomoRemainderMs;
    pomoRunning = true;
    if (pomoStartTimeStr[0] == '\0') {
      if (rtcFound) {
        DateTime n = rtc.now();
        snprintf(pomoStartTimeStr, sizeof(pomoStartTimeStr),
                 "%04d-%02d-%02dT%02d:%02d:%02d",
                 n.year(), n.month(), n.day(), n.hour(), n.minute(), n.second());
      } else {
        snprintf(pomoStartTimeStr, sizeof(pomoStartTimeStr), "2026-01-01T00:00:00");
      }
    }
  }
  stateChanged = true;
}
void sendPomoState(bool ok) {
  StaticJsonDocument<384> reply;
  reply["type"] = "pomo_state"; reply["ok"] = ok;
  reply["running"] = pomoRunning; reply["remaining"] = pomoTime;
  reply["work_min"] = pomoWorkDuration / 60; reply["break_min"] = pomoBreakDuration / 60;
  reply["phase"] = (int)pomoPhase; reply["task_type"] = current_pomo_task_type;
  sendReply(reply);
}
