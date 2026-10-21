#ifndef TIMER_ENGINE_H
#define TIMER_ENGINE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    bool selecting;
    int seconds_left;
    int initial_seconds;
    bool running;
    bool finished;
    int selected_preset;
} TimerState;

void timer_init(TimerState* state);
void timer_select(TimerState* state, int preset_index);
void timer_toggle(TimerState* state);
void timer_reset(TimerState* state);
void timer_tick(TimerState* state);

#ifdef __cplusplus
}
#endif
#endif
