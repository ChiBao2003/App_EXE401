/**
 * wifi_mqtt_manager.cpp - WiFi + MQTT Implementation
 * 
 * QUAN TRONG: File nay duoc #include tuy chon.
 * Chi kich hoat khi #define ENABLE_WIFI_MQTT trong Esp32Pj.ino
 * de tranh conflict RAM voi A2DP Bluetooth khi dang phat nhac.
 */
#include "wifi_mqtt_manager.h"
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// ==========================================
// Internal state
// ==========================================
static WiFiClient    wifiClient;
static PubSubClient  mqttClient(wifiClient);
static unsigned long lastReconnectAttempt = 0;
static bool          wifiConnected = false;

// ==========================================
// Forward declarations
// ==========================================
static void onMqttMessage(char* topic, byte* payload, unsigned int length);
static bool connectMQTT();
static void displayScrollTextHelper(const char* text, uint16_t color);

// ==========================================
// External variables tu Esp32Pj.ino
// (khai bao extern de truy cap ma khong can include cheo)
// ==========================================
extern int   pomoWorkDuration;
extern int   pomoBreakDuration;
extern bool  stateChanged;
// AppState enum - can match voi Esp32Pj.ino
extern int   currentState;  // Su dung int thay vi AppState tranh cyclic include
#define EXTERNAL_MODE_POMODORO 1  // Phai match voi AppState::MODE_POMODORO

// Ham hien scroll text (se goi ham tu Esp32Pj.ino)
// Khai bao weak so Linker khong bao loi neu chua implement
__attribute__((weak)) void displayScrollText(const char* text, uint16_t color) {}
__attribute__((weak)) void beepBuzzer(int count, int onMs, int freq) {}

// ==========================================
// Setup
// ==========================================
void setupWifiMQTT() {
    Serial.println("[WiFi] Dang ket noi WiFi...");
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    WiFi.setAutoReconnect(true);

    // Cho ket noi WiFi toi da 10 giay
    unsigned long wifiStart = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < 10000) {
        delay(200);
    }

    if (WiFi.status() == WL_CONNECTED) {
        wifiConnected = true;
        Serial.printf("[WiFi] Da ket noi! IP: %s\n", WiFi.localIP().toString().c_str());

        // Cau hinh MQTT
        mqttClient.setServer(MQTT_BROKER_IP, MQTT_BROKER_PORT);
        mqttClient.setCallback(onMqttMessage);
        mqttClient.setBufferSize(512);

        connectMQTT();
    } else {
        Serial.println("[WiFi] Khong ket noi duoc - tiep tuc khong co WiFi/MQTT");
        wifiConnected = false;
    }
}

// ==========================================
// MQTT Connect
// ==========================================
static bool connectMQTT() {
    if (!wifiConnected) return false;

    Serial.printf("[MQTT] Dang ket noi toi broker %s:%d...\n",
                  MQTT_BROKER_IP, MQTT_BROKER_PORT);

    if (mqttClient.connect(DEVICE_ID)) {
        Serial.println("[MQTT] Da ket noi MQTT broker!");
        // Dang ky nhan cac topics
        mqttClient.subscribe(TOPIC_POMO_CMD);
        mqttClient.subscribe(TOPIC_ALARM);
        mqttClient.subscribe(TOPIC_AI_MESSAGE);
        Serial.println("[MQTT] Da dang ky 3 topics");
        return true;
    }

    Serial.printf("[MQTT] Ket noi that bai, loi: %d\n", mqttClient.state());
    return false;
}

// ==========================================
// Loop - Goi moi iteration trong loop()
// ==========================================
void loopMQTT() {
    // Kiem tra WiFi
    if (WiFi.status() != WL_CONNECTED) {
        wifiConnected = false;
        return;
    }
    wifiConnected = true;

    // Kiem tra MQTT reconnect
    if (!mqttClient.connected()) {
        unsigned long now = millis();
        if (now - lastReconnectAttempt > MQTT_RECONNECT_INTERVAL_MS) {
            lastReconnectAttempt = now;
            connectMQTT();
        }
        return;
    }

    mqttClient.loop();
}

// ==========================================
// MQTT Callback - Xu ly tin nhan den
// ==========================================
static void onMqttMessage(char* topic, byte* payload, unsigned int length) {
    char buf[512] = {0};
    memcpy(buf, payload, min((unsigned int)511, length));

    StaticJsonDocument<256> doc;
    if (deserializeJson(doc, buf) != DeserializationError::Ok) {
        Serial.printf("[MQTT] JSON parse error for topic: %s\n", topic);
        return;
    }

    // --- Nhan lenh Pomodoro tu App ---
    if (strcmp(topic, TOPIC_POMO_CMD) == 0) {
        const char* action = doc["action"] | "";

        if (strcmp(action, "start") == 0) {
            int workMin  = doc["work_min"]  | 25;
            int breakMin = doc["break_min"] | 5;
            pomoWorkDuration  = workMin * 60;
            pomoBreakDuration = breakMin * 60;
            currentState = EXTERNAL_MODE_POMODORO;
            stateChanged = true;
            beepBuzzer(2, 150, 1000);  // 2 beep = bat dau
            Serial.printf("[MQTT] Bat dau Pomodoro: %d/%d phut\n", workMin, breakMin);
        }
        else if (strcmp(action, "stop") == 0) {
            currentState = 0;  // MODE_CLOCK
            stateChanged = true;
            beepBuzzer(1, 300, 600);
            Serial.println("[MQTT] Dung Pomodoro");
        }
        else if (strcmp(action, "set_duration") == 0) {
            pomoWorkDuration  = (doc["work_min"]  | 25) * 60;
            pomoBreakDuration = (doc["break_min"] | 5)  * 60;
            Serial.printf("[MQTT] Cap nhat thoi gian: %d/%d phut\n",
                          pomoWorkDuration/60, pomoBreakDuration/60);
        }
    }

    // --- Nhan bao thuc / canh bao tu Backend ---
    else if (strcmp(topic, TOPIC_ALARM) == 0) {
        const char* type = doc["type"] | "alarm";

        if (strcmp(type, "alarm") == 0) {
            beepBuzzer(5, 500, 1200);
        }
        else if (strcmp(type, "burnout_warning") == 0) {
            beepBuzzer(3, 300, 700);
            displayScrollText("! NGHI NGOI DI BAN OI !", 0xF800);  // RED
        }
        else if (strcmp(type, "reminder") == 0) {
            beepBuzzer(2, 200, 900);
            const char* title = doc["title"] | "Nhac nho";
            displayScrollText(title, 0xFFE0);  // YELLOW
        }
    }

    // --- Tin nhan AI scroll tren man hinh ---
    else if (strcmp(topic, TOPIC_AI_MESSAGE) == 0) {
        const char* text = doc["text"] | "";
        if (strlen(text) > 0) {
            displayScrollText(text, 0x07FF);  // CYAN
        }
    }
}

// ==========================================
// Publish trang thai Pomodoro
// ==========================================
void publishPomodoroState(bool isRunning, int remainingSec, const char* phase) {
    if (!mqttClient.connected()) return;

    StaticJsonDocument<200> doc;
    doc["device_id"]    = DEVICE_ID;
    doc["is_running"]   = isRunning;
    doc["remaining_s"]  = remainingSec;
    doc["phase"]        = phase;
    doc["timestamp_ms"] = millis();

    char buf[200];
    serializeJson(doc, buf);
    mqttClient.publish(TOPIC_POMO_STATE, buf, true);  // retained message
}

// ==========================================
// Publish ket thuc phien
// ==========================================
void publishSessionComplete(int workMin, int breakMin, int interruptions) {
    if (!mqttClient.connected()) return;

    StaticJsonDocument<200> doc;
    doc["device_id"]    = DEVICE_ID;
    doc["event"]        = "session_complete";
    doc["work_min"]     = workMin;
    doc["break_min"]    = breakMin;
    doc["interruptions"]= interruptions;
    doc["timestamp_ms"] = millis();

    char buf[200];
    serializeJson(doc, buf);
    mqttClient.publish(TOPIC_POMO_STATE, buf, false);
}

// ==========================================
// Status helpers
// ==========================================
bool isWifiConnected() { return wifiConnected && WiFi.status() == WL_CONNECTED; }
bool isMqttConnected() { return mqttClient.connected(); }
