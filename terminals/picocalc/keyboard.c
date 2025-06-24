//
//  ANS Forth for the Clockwork PicoCalc
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

//
//  PicoCalc keyboard driver
//
//  This driver implements a simple keyboard interface for the PicoCalc
//  using the I2C bus. It handles key presses and releases, modifier keys,
//  and user interrupts.
//
//  The PicoCalc only allows for polling the keyboard, and the API is
//  limited. To support user interrupts, we need to poll the keyboard and
//  buffer the key events for when needed, except for the user interrupt
//  where we process it immediately. We use a semaphore to protect access
//  to the I2C bus and a repeating timer to poll for the key events.
//
//  We also provide functions to interact with other features in the system,
//  such as reading the battery level.
//

#include "pico/stdlib.h"
#include "pico/platform.h"
#include "pico/binary_info.h"
#include "pico/multicore.h"
#include "hardware/gpio.h"
#include "hardware/i2c.h"

#include "keyboard.h"

extern volatile bool user_interrupt;

// Modifier key states
static bool key_control = false;               // control key state
static bool key_shift = false;                 // shift key state

static volatile uint8_t rx_buffer[KBD_BUFFER_SIZE];
static volatile uint16_t rx_head = 0;
static volatile uint16_t rx_tail = 0;
static repeating_timer_t key_timer;
static semaphore_t sb_sem;


//
//  Protect access to the "South Bridge"
//

// Protect the SPI bus with a semaphore
static void southbridge_aquire()
{
    sem_acquire_blocking(&sb_sem);
}

// Release the SPI bus
static void southbridge_release()
{
    sem_release(&sb_sem);
}


//
//  Keyboard Driver
//
//  This section implements the keyboard driver, which polls the
//  keyboard for key events and buffers them for processing. It uses
//  a repeating timer to poll the keyboard at regular intervals.
//

static bool on_keyboard_timer(repeating_timer_t *rt)
{
    uint8_t buffer[2];

    if (sem_available(&sb_sem) == 0)
    {
        return true;                    // if SPI is not available, skip this timer tick
    }

    // Repeat this loop until we exhaust the FIFO on the "south bridge".
    do
    {
        buffer[0] = KBD_REG_FIF;        // command to check if key is available
        i2c_write_blocking(i2c1, KBD_ADDR, buffer, 1, false);
        i2c_read_blocking(i2c1, KBD_ADDR, buffer, 2, false);

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
                else if (key_code == KEY_BREAK)
                {
                    user_interrupt = true; // set user interrupt flag
                }

                continue;
            }

            if (key_state == KEY_STATE_RELEASED)
            {
                if (key_code == KEY_MOD_CTRL) {
                    key_control = false;
                } else if (key_code == KEY_MOD_SHL || key_code == KEY_MOD_SHR) {
                    key_shift = false;
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
                    if (ch == 0x0A)     // enter key is returned as LF
                    {
                        ch = 0x0D;      // convert LF to CR
                    }

                    uint16_t next_head = (rx_head + 1) & (KBD_BUFFER_SIZE - 1);
                    rx_buffer[rx_head] = ch;
                    rx_head = next_head;
                }
            }

        }
    }
    while (buffer[0] != 0);

    return true;
}

void keyboard_init() {
    i2c_init(i2c1, KBD_BAUDRATE);
    gpio_set_function(KBD_SCL, GPIO_FUNC_I2C);
    gpio_set_function(KBD_SDA, GPIO_FUNC_I2C);
    gpio_pull_up(KBD_SCL);
    gpio_pull_up(KBD_SDA);

    // initialize semaphore for I2C access
    sem_init(&sb_sem, 1, 1);

    // poll every 200 ms for key events
    add_repeating_timer_ms(200, on_keyboard_timer, NULL, &key_timer);
}

bool keyboard_key_available()
{
    return rx_head != rx_tail;
}

int keyboard_get_key()
{
    while (!keyboard_key_available()) {
        tight_loop_contents();          // wait for a character
    }
        
    uint8_t ch = rx_buffer[rx_tail];
    rx_tail = (rx_tail + 1) & (KBD_BUFFER_SIZE - 1);
    return ch;
}



//
//  "South Bridge" functions
//
//  The secondary processor on the PicoCalc acts as a "south bridge",
//  providing access to the keyboard, battery, and other peripherals.
//
//  This ssection provides access to the other features of the system.
//

int southbridge_read_battery() {
    uint8_t buffer[2];
    buffer[0] = KBD_REG_BAT;

    southbridge_aquire();
    i2c_write_blocking(i2c1, KBD_ADDR, buffer, 1, false);
    i2c_read_blocking(i2c1, KBD_ADDR, buffer, 2, false);
    southbridge_release();

    return buffer[1];
}