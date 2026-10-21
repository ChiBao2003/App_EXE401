#pragma once
#include <stdint.h>
#include "input_latch.h"

enum class KeyEvent : uint8_t { None, Mode, Select, Ok };

inline const char* keyEventName(KeyEvent event) {
  switch (event) {
    case KeyEvent::Mode: return "MODE";
    case KeyEvent::Select: return "SELECT";
    case KeyEvent::Ok: return "OK";
    default: return "NONE";
  }
}

// Same raw-change/stable-level debounce as the hardware test (active low
// is converted to pressed=true by io_service). No internal GPIO pull-ups.
class DebouncedButton {
 public:
  bool update(bool pressed, uint32_t now) {
    if (!initialized_) {
      initialized_ = true;
      raw_ = down_ = pressed;
      changedAt_ = now;
      return false;
    }
    if (pressed != raw_) { raw_ = pressed; changedAt_ = now; }
    if (raw_ != down_ && uint32_t(now - changedAt_) >= 25) {
      down_ = raw_;
      return down_;
    }
    return false;
  }
  bool down() const { return down_; }
 private:
  bool initialized_ = false, raw_ = false, down_ = false;
  uint32_t changedAt_ = 0;
};

// Physical sampling order: GPIO36 MODE, GPIO34 OK, GPIO35 SELECT.
class NavigationButtons {
 public:
  KeyEvent update(uint8_t index, bool pressed, uint32_t now) {
    if (index>=3 || !buttons_[index].update(pressed,now)) return KeyEvent::None;
    return index==0?KeyEvent::Mode:index==1?KeyEvent::Ok:KeyEvent::Select;
  }
  bool down(uint8_t index) const { return index<3 && buttons_[index].down(); }
 private:
  DebouncedButton buttons_[3];
};

class BeepSequence {
 public:
  void start(int count, uint32_t onMs, uint32_t now) {
    remaining_ = count > 0 ? count : 0;
    onMs_ = onMs;
    on_ = remaining_ > 0;
    changedAt_ = now;
  }
  void stop() { remaining_ = 0; on_ = false; }
  bool tick(uint32_t now) {
    while (remaining_ > 0) {
      uint32_t duration = on_ ? onMs_ : 80;
      if (uint32_t(now - changedAt_) < duration) break;
      changedAt_ += duration;
      if (on_) { on_ = false; --remaining_; }
      else { on_ = true; }
    }
    return on_;
  }
 private:
  int remaining_ = 0;
  uint32_t onMs_ = 100, changedAt_ = 0;
  bool on_ = false;
};
