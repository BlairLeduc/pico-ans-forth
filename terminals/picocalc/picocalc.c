//
//  ANS Forth for the Clockwork PicoCalc
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#include "pico/stdlib.h"
#include "hardware/uart.h"

#include "display.h"
#include "keyboard.h"


void picocalc_init()
{
    display_init();
    keyboard_init();
}