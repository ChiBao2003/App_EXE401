#include "timer_engine.h"

#define NUM_PRESETS 8
static const int timer_presets[] = {10, 15, 30, 60, 300, 600, 900, 1500};

void timer_init(TimerState* state) {
    state->selecting = true;
    state->seconds_left = 0;
    state->initial_seconds = 0;
    state->running = false;
    state->finished = false;
    state->selected_preset = -1;
}

void timer_select(TimerState* state, int preset_index) {
    if (preset_index < 0 || preset_index >= NUM_PRESETS) return;
    state->selected_preset = preset_index;
    state->seconds_left = timer_presets[preset_index];
    state->initial_seconds = timer_presets[preset_index];
    state->selecting = false;
    state->running = true;
    state->finished = false;
}

void timer_toggle(TimerState* state) {
    if (state->selecting || state->finished) return;
    state->running = !state->running;
}

void timer_reset(TimerState* state) {
    state->running = false;
    state->finished = false;
    state->selecting = true;
    state->seconds_left = 0;
    state->initial_seconds = 0;
    state->selected_preset = -1;
}

void timer_tick(TimerState* state) {
    if (!state->running || state->finished || state->selecting) return;
    if (state->seconds_left > 0) {
        state->seconds_left--;
    } else {
        state->running = false;
        state->finished = true;
    }
}
