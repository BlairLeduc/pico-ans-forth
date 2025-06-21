//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

// Whilst most code for this implementation of ANS Forth is written in assembly,
// this file contains the C code that interfaces with the hardware using the
// Raspberry Pi Pico-series C/C++ SDK.

#include "pico/stdlib.h"
#include "hardware/uart.h"
#include "hardware/gpio.h"
#include "hardware/i2c.h"
#include "hardware.h"

volatile bool user_interrupt = false;

//  User interrupt handler
void check_for_user_interrupt()
{
    if (user_interrupt)
    {
        user_interrupt = false;         // Set the user interrupt flag
        __emit(0x07);                   // Bell
        __type_error(-28);              // User interrupt error code
        _quit();
    }
}

#ifdef PICO_ANS_FORTH_TERMINAL_UART


#include "termals/uart0/serial.h"


// Initialize the terminal hardware (UART)
void terminal_init()
{
    stdio_init_all();

    serial_init();
}

//
// Terminal Input functions
//

// Check if there is a character available in the RX buffer
bool __key_available()
{
    check_for_user_interrupt();          // Check for user interrupts
    return serial_key_available(); 

// Get a character from the RX buffer, blocking until one is available
int __key()
{
    while (!__key_available())
    {
        tight_loop_contents();          // Wait for a character
    }
    
    return serial_get_key();
}

//
// Terminal Output functions
//

// Check if a character can be emitted
bool __emit_available()
{
    check_for_user_interrupt();
    return serial_emit_available();
}

// Write a character to the UART
void __emit(char ch)
{
    while (!__emit_available())
    {
        tight_loop_contents();          // Wait until we can write
    }
    serial_emit(ch);
}

#endif // PICO_ANS_FORTH_TERMINAL_UART

#ifdef PICO_ANS_FORTH_TERMINAL_PICOCALC

#include "terminals/picocalc/display.h"
#include "terminals/picocalc/keyboard.h"

void terminal_init()
{
    // Debug only
    stdio_init_all();
    uart_init(uart0, 115200);

    uart_set_format(uart0, 8, 1, UART_PARITY_NONE);  // 8-N-1
    uart_set_fifo_enabled(uart0, false);
    // end debug only

display_init();
    keyboard_init();
}

// Terminal Input
bool __key_available()
{
    check_for_user_interrupt();
    return keyboard_key_available();
}

int __key()
{
    while (!__key_available())
    {
        tight_loop_contents();          // Wait for a character
    }
    
    return keyboard_get_key();
}

// Terminal Output
bool __emit_available() {
    check_for_user_interrupt();
    return display_emit_available(); // Always available for output in this implementation
}

void __emit(char ch)
{
    while (!__emit_available())
    {
        tight_loop_contents();          // Wait until we can write
    }

    display_emit(ch);
}

#endif // PICO_ANS_FORTH_TERMINAL_PICOCALC



