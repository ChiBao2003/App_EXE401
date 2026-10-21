#pragma once
#include <stdint.h>
#include "input_latch.h"

enum class KeyEvent : uint8_t { None, Next, Ok, Back, BackLong };

class BackKey {
 public:
  KeyEvent update(bool pressed, uint32_t now) {
    if (latch_.update(pressed, now)) {
      pending_ = true;
      pressedAt_ = now;
    }
    if (pressed) {
      releaseSeen_ = false;
      if (pending_ && uint32_t(now - pressedAt_) >= 1000) {
        pending_ = false;
        return KeyEvent::BackLong;
      }
    } else if (pending_) {
      if (!releaseSeen_) { releaseSeen_ = true; releasedAt_ = now; }
      if (uint32_t(now - releasedAt_) >= 25) {
        pending_ = false;
        return KeyEvent::Back;
      }
    }
    return KeyEvent::None;
  }
 private:
  PressLatch latch_{25, 25};
  bool pending_ = false, releaseSeen_ = false;
  uint32_t pressedAt_ = 0, releasedAt_ = 0;
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
