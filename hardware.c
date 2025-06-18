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
#include "hardware.h"

static volatile bool user_interrupt = false; 

//  User interrupt handler
void check_for_user_interrupt()
{
    if (user_interrupt) {
        user_interrupt = false;         // Set the user interrupt flag
        __emit(0x07);                   // Bell
        __type_error(-28);              // User interrupt error code
        _quit();
    }
}

#ifdef PICO_ANS_FORTH_TERMINAL_UART

// UART defines
// By default the stdout UART is `uart0`, so we will use the second one
#define UART_ID uart0
#define BAUD_RATE 115200
#define DATA_BITS 8
#define STOP_BITS 1
#define PARITY UART_PARITY_NONE

// We are using pins 0 and 1, but see the GPIO function select table in the
// datasheet for information on which other pins can be used.
#define UART_TX_PIN 0
#define UART_RX_PIN 1

// Add these definitions at the top of the file, after the UART defines
#define BUFFER_SIZE 256
static volatile uint8_t rx_buffer[BUFFER_SIZE];
static volatile uint16_t rx_head = 0;
static volatile uint16_t rx_tail = 0;

// Interrupt handler for UART RX
void on_uart_rx()
{
    while (uart_is_readable(UART_ID))
    {
        uint8_t ch = uart_getc(UART_ID);
        // Check for user interrupt (Ctrl+C)
        if (ch == 0x03)                 // Ctrl+C
        {
            user_interrupt = true;      // Set the user interrupt flag
            continue;                   // Skip adding this character to the buffer
        }
        uint16_t next_head = (rx_head + 1) & (BUFFER_SIZE - 1);
        rx_buffer[rx_head] = ch;
        rx_head = next_head;
    }
}

// Initialize the terminal hardware (UART)
void terminal_init()
{
    stdio_init_all();

    // Set up our UART
    uart_init(UART_ID, BAUD_RATE);

    // Set the TX and RX pins by using the function select on the GPIO
    // Set datasheet for more information on function select
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
    
    // Set UART flow control CTS/RTS, we don't want these, so turn them off
    uart_set_hw_flow(UART_ID, false, false);

    // Set our data format
    uart_set_format(UART_ID, DATA_BITS, STOP_BITS, PARITY);

    // Turn off FIFO's - we want to do this character by character
    uart_set_fifo_enabled(UART_ID, false);

    // Set up a RX interrupt
    // We need to set up the handler first
    // Select correct interrupt for the UART we are using
    int UART_IRQ = UART_ID == uart0 ? UART0_IRQ : UART1_IRQ;

    // And set up and enable the interrupt handlers
    irq_set_exclusive_handler(UART_IRQ, on_uart_rx);
    irq_set_enabled(UART_IRQ, true);

    // Now enable the UART to send interrupts - RX only
    uart_set_irq_enables(UART_ID, true, false);
}

//
// Terminal Input functions
//

// Check if there is a character available in the RX buffer
int __key_available()
{
    check_for_user_interrupt();          // Check for user interrupts
    return rx_head != rx_tail;
}

// Get a character from the RX buffer, blocking until one is available
int __key()
{
    while (!__key_available()) {
        tight_loop_contents();          // Wait for a character
    }
    
    uint8_t ch = rx_buffer[rx_tail];
    rx_tail = (rx_tail + 1) & (BUFFER_SIZE - 1);
    return ch;
}


//
// Terminal Output functions
//

// Check if a character can be emitted
bool __emit_available()
{
    check_for_user_interrupt();
    return uart_is_writable(UART_ID);
}

// Write a character to the UART
void __emit(char ch)
{
    while (!__emit_available())
    {
        tight_loop_contents();          // Wait until we can write
    }
    uart_putc(UART_ID, ch);             // Send the character
}

#endif // PICO_ANS_FORTH_TERMINAL_UART

#ifdef PICO_ANS_FORTH_TERMINAL_PICOCALC

// PicoCals-specific code
// TODO

#endif // PICO_ANS_FORTH_TERMINAL_PICOCALC



