#include "../src/io_service.h"
#include <assert.h>
#include <stdio.h>

static int sample(PressLatch& button, bool down, uint32_t start, uint32_t count) {
  int events = 0;
  for (uint32_t i=0; i<count; ++i) events += button.update(down, start+i);
  return events;
}
int main() {
  static_assert(BUTTON_MODE_PIN==36 && BUTTON_OK_PIN==34 && BUTTON_SELECT_PIN==35,
                "Physical GPIO assignments must not change");
  NavigationButtons boot;
  assert(boot.update(2,true,0)==KeyEvent::None);
  assert(boot.update(2,true,5000)==KeyEvent::None);
  assert(boot.update(2,false,5100)==KeyEvent::None);
  assert(boot.update(2,false,5125)==KeyEvent::None);
  assert(boot.update(2,true,5200)==KeyEvent::None);
  assert(boot.update(2,true,5225)==KeyEvent::Select);
  // A brief release during a held press cannot arm another action.
  assert(boot.update(2,false,5300)==KeyEvent::None);
  assert(boot.update(2,true,5320)==KeyEvent::None);
  assert(boot.update(2,true,7000)==KeyEvent::None);
  NavigationButtons wrapKeys;
  assert(wrapKeys.update(1,false,0xffffff00u)==KeyEvent::None);
  assert(wrapKeys.update(1,true,0xfffffff0u)==KeyEvent::None);
  assert(wrapKeys.update(1,true,0x9u)==KeyEvent::Ok);
  assert(wrapKeys.update(1,true,0x1000u)==KeyEvent::None);
  PressLatch contact(80,150);
  contact.suppressUntilRelease(0);
  assert(!contact.update(true,1000));
  assert(!contact.update(false,1100));
  assert(!contact.update(false,1250));
  assert(!contact.update(true,1300));
  assert(contact.update(true,1380));
  assert(!contact.update(true,5000));
  NavigationButtons navigation;
  for (uint8_t i=0;i<3;++i) {
    assert(navigation.update(i,false,0)==KeyEvent::None);
    assert(navigation.update(i,true,100)==KeyEvent::None);
    assert(navigation.update(i,true,124)==KeyEvent::None);
    const KeyEvent expected=i==0?KeyEvent::Mode:i==1?KeyEvent::Ok:KeyEvent::Select;
    assert(navigation.update(i,true,125)==expected);
    assert(navigation.update(i,true,1125)==KeyEvent::None);
    assert(navigation.update(i,true,5125)==KeyEvent::None);
    assert(navigation.update(i,false,5200)==KeyEvent::None);
    assert(navigation.update(i,false,5225)==KeyEvent::None);
    assert(navigation.update(i,true,5300)==KeyEvent::None);
    assert(navigation.update(i,true,5325)==expected);
  }
  puts("PASS: MODE36, OK34, SELECT35 on press; holding and release produce no extra event");
  // Hardware-test debounce: accept press/release only after 25 ms.
  DebouncedButton key;
  assert(!key.update(false,0));
  assert(!key.update(true,10));
  assert(!key.update(false,20));
  assert(!key.update(true,30));
  assert(!key.update(true,54));
  assert(key.update(true,55));
  assert(!key.update(true,2000));
  assert(!key.update(false,2010));
  assert(key.down());
  assert(!key.update(false,2035));
  assert(!key.down());
  assert(!key.update(true,2040));
  assert(key.update(true,2065));
  // Stuck/held at power-on cannot switch screens.
  PressLatch held(45,120);
  assert(sample(held,true,0,5000)==0);
  assert(sample(held,false,5000,200)==0);
  assert(sample(held,true,5200,100)==1);
  assert(sample(held,true,5300,5000)==0);
  // Bounce and a brief release must not create additional presses.
  assert(sample(held,false,10300,20)==0);
  assert(sample(held,true,10320,200)==0);
  assert(sample(held,false,10520,200)==0);
  assert(sample(held,true,10720,200)==1);
  PressLatch bounce(45,120);
  assert(sample(bounce,false,0,200)==0);
  for (int i=0;i<10;++i) {
    assert(sample(bounce,true,200+i*20,10)==0);
    assert(sample(bounce,false,210+i*20,10)==0);
  }
  assert(sample(bounce,true,400,100)==1);
  // A held MODE cannot prevent the other button from being pressed.
  PressLatch other(45,120);
  assert(sample(other,false,0,200)==0);
  assert(sample(other,true,200,100)==1);
  assert(sample(other,false,300,200)==0);
  assert(sample(other,true,500,100)==1);
  // Unsigned time arithmetic remains valid when millis wraps.
  PressLatch wrap(45,120);
  assert(sample(wrap,false,0xffffff00u,200)==0);
  assert(sample(wrap,true,0xffffffc8u,100)==1);
  BeepSequence beep;
  beep.start(3,100,0);
  assert(beep.tick(0)); assert(beep.tick(99)); assert(!beep.tick(100));
  assert(!beep.tick(179)); assert(beep.tick(180)); assert(!beep.tick(280));
  assert(beep.tick(360)); assert(!beep.tick(460)); assert(!beep.tick(5000));
  beep.start(8,200,6000); assert(beep.tick(6001));
  beep.stop(); assert(!beep.tick(6002));
  beep.start(3,100,0xffffffc0u);
  assert(beep.tick(0xffffffc1u)); assert(!beep.tick(0x24u));
  assert(!beep.tick(0x10000u));
  puts("PASS: 25 ms stable press/release");
  puts("PASS: exact beep timing, stop during beep, delayed update and timer wrap");
  puts("PASS: boot hold, long hold, bounce, release, independent keys, millis wrap");
}
