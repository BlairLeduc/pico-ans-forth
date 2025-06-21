//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#include "pico/binary_info.h"
#include "pico/stdlib.h"
#include "pico/platform.h"
#include "hardware/gpio.h"
#include "hardware/i2c.h"

#include "keyboard.h"

extern volatile bool user_interrupt;

bool key_control = false;               // Control key state
bool key_shift = false;                 // Shift key state
bool key_alt = false;                   // Alt key state

// Add these definitions at the top of the file, after the UART defines
static volatile uint8_t rx_buffer[BUFFER_SIZE];
static volatile uint16_t rx_head = 0;
static volatile uint16_t rx_tail = 0;
static repeating_timer_t key_timer;


bool on_timer(repeating_timer_t *rt)
{
    uint8_t buffer[2];
    do
    {
        buffer[0] = REG_ID_FIF; // command to check if key is available
        int writeResult = i2c_write_blocking(I2C_KBD_MOD, I2C_KBD_ADDR, buffer, 1, false);
        if (writeResult == PICO_ERROR_GENERIC || writeResult == PICO_ERROR_TIMEOUT)
        {
            return true; // I2C write error
        }

        int readResult = i2c_read_blocking(I2C_KBD_MOD, I2C_KBD_ADDR, buffer, 2, false);
        if (readResult == PICO_ERROR_GENERIC || readResult == PICO_ERROR_TIMEOUT)
        {
            return true; // I2C read error
        }

        if (buffer[0] != 0)
        {
            uint8_t key_state = buffer[0];
            uint8_t key_code = buffer[1];

            if (key_state == KEY_STATE_PRESSED)
            {
                if (key_code == KEY_MOD_CTRL)
                {
                    key_control = true;
                }
                else if (key_code == KEY_MOD_SHL || key_code == KEY_MOD_SHR)
                {
                    key_shift = true;
                }
                else if (key_code == KEY_MOD_ALT)
                {
                    key_alt = true;
                }
                else if (key_code == KEY_BREAK)
                {
                    user_interrupt = true; // Set user interrupt flag
                }

                continue;
            }

            if (key_state == KEY_STATE_RELEASED)
            {
                if (key_code == KEY_MOD_CTRL) {
                    key_control = false;
                } else if (key_code == KEY_MOD_SHL || key_code == KEY_MOD_SHR) {
                    key_shift = false;
                } else if (key_code == KEY_MOD_ALT) {
                    key_alt = false;
                } else {
                    // If a key is released, we return the key code
                    // This allows us to handle the key release in the main loop
                    uint8_t ch = key_code;
                    if (ch >= 'a' && ch <= 'z') // Ctrl and Shift handling
                    {
                        if (key_control)
                        {
                            ch &= ~0x40;
                        }
                        if (key_shift)
                        {
                            ch &= ~0x20;
                        }
                    }
                    if (ch == 0x0A) // Enter key is returned as LF
                    {
                        ch = 0x0D; // Convert LF to CR
                    }

                    uint16_t next_head = (rx_head + 1) & (BUFFER_SIZE - 1);
                    rx_buffer[rx_head] = ch; // Store the key state and code in the buffer
                    rx_head = next_head;
                }
            }

        }
    }
    while (buffer[0] != 0);
    return true;
}

void keyboard_init() {
    i2c_init(I2C_KBD_MOD, I2C_KBD_SPEED);
    gpio_set_function(I2C_KBD_SCL, GPIO_FUNC_I2C);
    gpio_set_function(I2C_KBD_SDA, GPIO_FUNC_I2C);
    gpio_pull_up(I2C_KBD_SCL);
    gpio_pull_up(I2C_KBD_SDA);
    bi_decl(bi_2pins_with_func(I2C_KBD_SDA, I2C_KBD_SCL, GPIO_FUNC_I2C));

    add_repeating_timer_ms(100, on_timer, NULL, &key_timer); // Start polling for keys every 100ms
}

bool keyboard_key_available()
{
    return rx_head != rx_tail;
}

int keyboard_get_key()
{
    while (!keyboard_key_available()) {
        tight_loop_contents();          // Wait for a character
    }
        
    uint8_t ch = rx_buffer[rx_tail];
    rx_tail = (rx_tail + 1) & (BUFFER_SIZE - 1);
    return ch;
}

int read_battery() {
    uint8_t buffer[2];

    buffer[0] = REG_ID_BAT;
    int writeResult = i2c_write_blocking(I2C_KBD_MOD, I2C_KBD_ADDR, buffer, 1, false);
    if (writeResult == PICO_ERROR_GENERIC || writeResult == PICO_ERROR_TIMEOUT)
    {
        return -1; // I2C write error
    }

    int readResult = i2c_read_blocking(I2C_KBD_MOD, I2C_KBD_ADDR, buffer, 2, false);
    if (readResult == PICO_ERROR_GENERIC || readResult == PICO_ERROR_TIMEOUT)
    {
        return -1; // I2C read error
    }

    return buffer[1];
}