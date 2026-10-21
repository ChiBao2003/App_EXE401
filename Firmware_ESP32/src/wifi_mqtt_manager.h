/**
 * wifi_mqtt_manager.h - WiFi + MQTT Manager cho ESP32
 * Xu ly ket noi WiFi, MQTT pub/sub voi Backend AI Productivity.
 * 
 * Topics:
 *   SUBSCRIBE: watch/pomodoro/command  <- Nhan lenh tu App/Backend
 *              watch/alarm/trigger     <- Nhan bao thuc tu Backend  
 *              watch/ai/message        <- Nhan tin nhan AI (hien scroll text)
 *   PUBLISH:   watch/pomodoro/state    -> Gui trang thai len Backend
 */
#pragma once

#include <Arduino.h>

// ==========================================
// Cau hinh WiFi (thay bang thong tin thuc te)
// ==========================================
#define WIFI_SSID        "YOUR_WIFI_SSID"
#define WIFI_PASSWORD    "YOUR_WIFI_PASSWORD"
#define MQTT_BROKER_IP   "192.168.1.x"   // IP may Backend (chay uvicorn)
#define MQTT_BROKER_PORT 1883
#define DEVICE_ID        "esp32_watch_01"
#define MQTT_RECONNECT_INTERVAL_MS 5000

// ==========================================
// MQTT Topics
// ==========================================
#define TOPIC_POMO_CMD    "watch/pomodoro/command"
#define TOPIC_POMO_STATE  "watch/pomodoro/state"
#define TOPIC_ALARM       "watch/alarm/trigger"
#define TOPIC_AI_MESSAGE  "watch/ai/message"

// ==========================================
// Cac ham public
// ==========================================

/** Khoi tao WiFi va MQTT. Goi trong setup() sau Bluetooth init. */
void setupWifiMQTT();

/** Xu ly MQTT loop + auto-reconnect. Goi cuoi loop() moi iteration. */
void loopMQTT();

/**
 * Publish trang thai Pomodoro len Backend.
 * @param isRunning   Co dang chay hay khong
 * @param remainingSec So giay con lai
 * @param phase       "work" | "break" | "long_break"
 */
void publishPomodoroState(bool isRunning, int remainingSec, const char* phase);

/** Publish bao hieu phien ket thuc (completed = true). */
void publishSessionComplete(int workMin, int breakMin, int interruptions);

/** Kiem tra WiFi co dang ket noi khong. */
bool isWifiConnected();

/** Kiem tra MQTT co dang ket noi khong. */
bool isMqttConnected();
