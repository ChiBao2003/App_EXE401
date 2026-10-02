# TÀI LI?U Ð?C T? PH?N C?NG (HARDWARE SPECIFICATION)
**Phiên b?n:** 1.0
**Mô dun:** H? th?ng Nhúng (ESP32) & Thi?t b? ngo?i vi

## 1. T?ng quan h? th?ng (System Overview)
Thi?t b? là m?t Ð?ng h? thông minh Pomodoro tích h?p loa Bluetooth, du?c xây d?ng trên n?n t?ng vi di?u khi?n ESP32. Thi?t b? v?a dóng vai trò nhu m?t thi?t b? IoT thu th?p d? li?u thói quen, v?a ho?t d?ng nhu m?t h? th?ng gi?i trí da phuong ti?n (loa Bluetooth).

## 2. Vi di?u khi?n chính (Main Microcontroller)
- **Board:** DOIT ESP32 DevKit V1 (ESP32-D0WD-V3)
- **Ki?n trúc:** Xtensa Dual-Core 32-bit LX6, xung nh?p 240MHz
- **B? nh?:** 520 KB SRAM, 4 MB Flash
- **K?t n?i không dây:** Wi-Fi & Bluetooth v4.2 BR/EDR và BLE (Dual-Mode)

## 3. Các module ngo?i vi (Peripherals)
### 3.1. Kh?i Hi?n th? và C?m ?ng (Display & Touch)
- **Màn hình:** TFT LCD (dùng thu vi?n `MCUFRIEND_kbv` và `Adafruit GFX`)
- **C?m ?ng:** Ði?n tr?/Ði?n dung (`Adafruit TouchScreen`)
- **Ch?c nang:** Hi?n th? giao di?n d?ng h?, d?m ngu?c Pomodoro.

### 3.2. Kh?i Th?i gian th?c (RTC)
- **Chip:** DS3231 ho?c PCF8563 (I2C)
- **Ch?c nang:** Luu tr? th?i gian k? c? khi m?t di?n.

### 3.3. Kh?i Âm thanh (Audio System)
- **Giao th?c:** I2S (Inter-IC Sound) k?t h?p module DAC.
- **Thu vi?n:** `ESP32-A2DP`. Xu?t âm thanh stream t? di?n tho?i ra loa ngoài.

## 4. Ch? d? Bluetooth Kép (Dual-Mode Topology)
1. **A2DP Sink:** Ho?t d?ng nhu loa Bluetooth (nghe nh?c).
2. **SPP (Serial Port Profile):** Truy?n d? li?u n?i ti?p. Khi k?t thúc phiên Pomodoro, d? li?u JSON du?c truy?n v? di?n tho?i.
