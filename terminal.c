//
//  ANS Forth for the Clockwork PicoCalc
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
#include "terminal.h"


#ifdef PICO_ANS_FORTH_TERMINAL_UART

#include "terminals/uart0/uart0.h"
#include "terminals/uart0/serial.h"

static void (*terminal_init)(void) = uart0_init;
static bool (*terminal_key_available)(void) = serial_key_available;
static int  (*terminal_get_key)(void) = serial_get_key;
static bool (*terminal_emit_available)(void) = serial_emit_available;
static void (*terminal_emit)(char ch) = serial_emit;

#endif // PICO_ANS_FORTH_TERMINAL_UART

#ifdef PICO_ANS_FORTH_TERMINAL_PICOCALC

#include "terminals/picocalc/picocalc.h"
#include "terminals/picocalc/display.h"
#include "terminals/picocalc/keyboard.h"

static void (*terminal_init)(void) = picocalc_init;
static bool (*terminal_key_available)(void) = keyboard_key_available;
static int  (*terminal_get_key)(void) = keyboard_get_key;
static bool (*terminal_emit_available)(void) = display_emit_available;
static void (*terminal_emit)(char ch) = display_emit;

#endif // PICO_ANS_FORTH_TERMINAL_PICOCALC

//
// Terminal User Interrupt
//

// External references (implemented in assembly)
extern void __type_error(int error_code);
extern void forth_start();
extern void _quit();

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



//
// Terminal Initialization
//

// Initialize the terminal hardware
void __init()
{
    terminal_init();
}



//
// Terminal Input functions
//

// Check if there is a character available in the RX buffer
bool __key_available()
{
    check_for_user_interrupt();          // Check for user interrupts
    return terminal_key_available(); 
}

// Get a character from the RX buffer, blocking until one is available
int __key()
{
    while (!__key_available())
    {
        tight_loop_contents();          // Wait for a character
    }
    
    return terminal_get_key();
}



//
// Terminal Output functions
//

// Check if a character can be emitted
bool __emit_available()
{
    check_for_user_interrupt();
    return terminal_emit_available();
}

// Write a character to the UART
void __emit(char ch)
{
    while (!__emit_available())
    {
        tight_loop_contents();          // Wait until we can write
    }
    terminal_emit(ch);
}
