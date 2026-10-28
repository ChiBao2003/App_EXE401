#pragma once
#include <stdint.h>

// Stable release arms the input. A stable press emits exactly once.
// An input held at boot remains inactive until it has been released.
class PressLatch {
 public:
  PressLatch(uint32_t pressMs, uint32_t releaseMs)
      : pressMs_(pressMs), releaseMs_(releaseMs) {}
  bool update(bool pressed, uint32_t now) {
    if (!initialized_) {
      initialized_ = true;
      raw_ = pressed;
      changedAt_ = now;
      return false;
    }
    if (pressed != raw_) {
      raw_ = pressed;
      changedAt_ = now;
    }
    const uint32_t elapsed = now - changedAt_;
    if (!raw_) {
      if (elapsed >= releaseMs_) armed_ = true;
      return false;
    }
    if (armed_ && elapsed >= pressMs_) {
      armed_ = false;
      return true;
    }
    return false;
  }
 private:
  uint32_t pressMs_, releaseMs_, changedAt_ = 0;
  bool initialized_ = false, raw_ = false, armed_ = false;
};
