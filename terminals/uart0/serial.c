//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

//
// Pico 2 (W) serial driver
//
// This driver implements a simple serial interface for the Pico 2 using the
// UART peripheral. It handles character reception and transmission,
// user interrupts (Ctrl+C), and provides functions to check for available keys
// and emit characters. The driver uses a circular buffer to store received characters
// and an interrupt handler to process incoming data.
//

#include "pico/stdlib.h"
#include "hardware/uart.h"
#include "hardware/irq.h"

#include "serial.h"

extern volatile bool user_interrupt;

static volatile uint8_t rx_buffer[UART_BUFFER_SIZE];
static volatile uint16_t rx_head = 0;
static volatile uint16_t rx_tail = 0;

// Interrupt handler for UART RX
void on_uart_rx()
{
    while (uart_is_readable(uart0))
    {
        uint8_t ch = uart_getc(uart0);
        // Check for user interrupt (Ctrl+C)
        if (ch == 0x03)                 // Ctrl+C
        {
            user_interrupt = true;      // Set the user interrupt flag
            continue;                   // Skip adding this character to the buffer
        }
        uint16_t next_head = (rx_head + 1) & (UART_BUFFER_SIZE - 1);
        rx_buffer[rx_head] = ch;
        rx_head = next_head;
    }
}

void serial_init()
{
        // Set up our UART
    uart_init(uart0, UART_BAUDRATE);

    // Set the TX and RX pins by using the function select on the GPIO
    // Set datasheet for more information on function select
    gpio_set_function(UART_TX, GPIO_FUNC_UART);
    gpio_set_function(UART_RX, GPIO_FUNC_UART);
    
    // Set UART flow control CTS/RTS, we don't want these, so turn them off
    uart_set_hw_flow(uart0, false, false);

    // Set our data format
    uart_set_format(uart0, UART_DATABITS, UART_STOPBITS, UART_PARITY);

    // Turn off FIFO's - we want to do this character by character
    uart_set_fifo_enabled(uart0, false);

    // Set up a RX interrupt
    // And set up and enable the interrupt handlers
    irq_set_exclusive_handler(UART0_IRQ, on_uart_rx);
    irq_set_enabled(UART0_IRQ, true);

    // Now enable the UART to send interrupts - RX only
    uart_set_irq_enables(uart0, true, false);
}

bool serial_key_available()
{
    return rx_head != rx_tail;
}

int serial_get_key()
{
    while (!keyboard_key_available()) {
        tight_loop_contents();          // Wait for a character
    }
        
    uint8_t ch = rx_buffer[rx_tail];
    rx_tail = (rx_tail + 1) & (UART_BUFFER_SIZE - 1);
    return ch;
}

bool serial_emit_available()
{
    return uart_is_writable(uart0);
}

void serial_emit(char ch)
{
    while (!serial_emit_available())
    {
        tight_loop_contents();          // Wait until we can write
    }
    uart_putc(uart0, ch);             // Send the character
}