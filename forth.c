//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#include <stdio.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "hardware/uart.h"

#include "forth.h"
#include "version.h"

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
static volatile bool user_interrupt = false; 

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

void __type(const char *str, int len)
{
    while (len--)
    {
        __emit(*str++);
    }
}

void __type_cstr(const char *str)
{
    while (*str)
    {
        __emit(*str++);
    }
}

int __accept(char *buffer, int len)
{
    int pos = 0;
    char ch;
    
    while (1)
    {
        ch = __key();

        // Handle backspace (both ASCII BS and DEL)
        if (ch == 0x08)
        {
            if (pos > 0)
            {
                pos--;
                // Echo backspace-space-backspace sequence
                __emit(0x08);
                __emit(' ');
                __emit(0x08);
            }
            else
            {
                __emit(0x07);           // Bell
            }
            continue;
        }

        if (ch == 0x7f) // DEL
        {
            pos = 0; // Reset position on DEL
            __type_cstr("\033[2K\015"); // Echo a new line
            
            continue;
        }

        // Handle carriage return
        if (ch == 0x0d)
        {
            buffer[pos] = ' ';          // Replace CR with space
            __emit(' ');                // Echo space instead of CR
            return pos;                 // Return the length of the input
        }

        // Ignore characters outside of printable ASCII range
        if (ch < 0x20 || ch > 0x7e)
        {
            continue;
        }

        // Check if buffer is full
        if (pos >= len)
        {
            __emit(0x07);               // Bell
            continue;
        }

        // Store and echo valid character
        buffer[pos] = ch;
        __emit(ch);
        pos++;
    }
}


void __type_error(int error_code)
{
    // Emit an error message based on the error code
    switch (error_code)
    {
        case   0: __type_cstr("ok\015\012"); break;
        case  -1: __type_cstr("Abort\015\012"); break;
        case  -2: __type_cstr("Abort: Message\015\012"); break;
        case  -3: __type_cstr("Stack overflow\015\012"); break;
        case  -4: __type_cstr("Stack underflow\015\012"); break;
        case  -5: __type_cstr("Return stack overflow\015\012"); break;
        case  -6: __type_cstr("Return stack underflow\015\012"); break;
        case  -7: __type_cstr("Do-loops nested too deeply\015\012"); break;
        case  -8: __type_cstr("Dictionary overflow\015\012"); break;
        case  -9: __type_cstr("Invalid memory address\015\012"); break;
        case -10: __type_cstr("Division by zero\015\012"); break;
        case -11: __type_cstr("Result out of range\015\012"); break;
        case -12: __type_cstr("Argument type mismatch\015\012"); break;
        case -13: __type_cstr("Undefined word\015\012"); break;
        case -14: __type_cstr("Interpreting a compile-only word\015\012"); break;
        case -15: __type_cstr("Invalid FORGET\015\012"); break;
        case -16: __type_cstr("Attempt to use zero-length string as a name\015\012"); break;
        case -17: __type_cstr("Pictured numeric output string overflow\015\012"); break;
        case -18: __type_cstr("Parsed string overflow\015\012"); break;
        case -19: __type_cstr("Definition name too long\015\012"); break;
        case -20: __type_cstr("Write to a read-only location\015\012"); break;
        case -21: __type_cstr("Unsupported operation\015\012"); break;
        case -22: __type_cstr("Control structure mismatch\015\012"); break;
        case -23: __type_cstr("Address alignment exception\015\012"); break;
        case -24: __type_cstr("Invalid numeric argument\015\012"); break;
        case -25: __type_cstr("Return stack imbalance\015\012"); break;
        case -26: __type_cstr("Loop parameters unavailable\015\012"); break;
        case -27: __type_cstr("Invalid recursion\015\012"); break;
        case -28: __type_cstr("User Interrupt\015\012"); break;
        case -29: __type_cstr("Compiler nesting\015\012"); break;
        case -57: __type_cstr("Exception in sending or receiving\015\012"); break;
        default:
            char error_code_str[12];
            itoa(error_code, error_code_str, 10); // Convert error code to string
            if (error_code < 0)
            {
                __type_cstr("\015\012  Unknown system error: ");
                __type_cstr(error_code_str);
                __type_cstr("\015\012");
            }
            else
            {
                __type_cstr("\015\012  Application error: ");
                __type_cstr(error_code_str);
                __type_cstr("\015\012");
            }
    }
}

void __type_welcome()
{
    __type_cstr("\033cANS Forth for the Pico 2\015\012");
    __type_cstr("Copyright Blair Leduc.\015\012");
    __type_cstr("Version ");
    __type_cstr(PICO_ANS_FORTH_VERSION);
    __type_cstr("\015\012");
}


void hardware_init()
{
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

int main()
{
    stdio_init_all();
    hardware_init();

    // OK, all set up.

    forth_start();
}
