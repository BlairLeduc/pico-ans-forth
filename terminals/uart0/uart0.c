//
//  ANS Forth for the Clockwork PicoCalc
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#include "pico/stdlib.h"
#include "hardware/uart.h"

#include "serial.h"

void uart0_init()
{
    stdio_init_all();

    serial_init();
}