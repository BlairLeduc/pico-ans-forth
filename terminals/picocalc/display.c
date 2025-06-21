//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

//
//  PicoCalc LCD display driver
//
//  This driver implements a simple ANSI terminal interface for the PicoCalc LCD display
//  using the ST7789P LCD controller.
//
//  It is optimised for a character-based display with a fixed-width, 8-pixel wide font
//  and 65K colours in the RGB565 format. This driver is requires little memory as a
//  frame buffer is not used.
//

#include "pico/stdlib.h"
#include "pico/multicore.h"
#include "hardware/spi.h"

#include "string.h"

#include "display.h"

uint8_t state = STATE_NORMAL;           // initial state of escape sequence processing
uint8_t x = 0;                          // cursor x position
uint8_t y = 0;                          // cursor y position
uint8_t foreground = DEFAULT_FOREGROUND;// foreground color (default white phosphor)
uint8_t background = DEFAULT_BACKGROUND;// background color (default black)
bool underline = false;                 // underline state (not used in this implementation)

uint8_t params[16];                     // buffer for ANSI escape sequence parameters
uint8_t params_index = 0;               // index into the params buffer

uint8_t save_x = 0;                     // saved cursor x position for ANSI escape sequences
uint8_t save_y = 0;                     // saved cursor y position for ANSI escape sequences

uint8_t cursor_x = 0;                   // cursor x position for drawing
uint8_t cursor_y = 0;                   // cursor y position for drawing

uint16_t lcd_y_offset = 0;              // offset for vertical scrolling

semaphore_t lcd_sem;

static uint16_t palette[9] = {
    RGB(0, 0, 0),                       // 0 Black
    RGB(255, 0, 0),                     // 1 Red
    RGB(0, 255, 0),                     // 2 Green
    RGB(255, 255, 0),                   // 3 Yellow
    RGB(0, 0, 255),                     // 4 Blue
    RGB(255, 0, 255),                   // 5 Agenta
    RGB(0, 255, 255),                   // 6 Cyan
    RGB(255, 255, 255),                 // 7 White
    RGB(192, 228, 255),                 // 8 White phosphor
};

static repeating_timer_t cursor_timer;
uint16_t char_buffer[8 * GLYPH_HEIGHT] __attribute__ ((aligned(4))); 
extern uint8_t font[];

// Reset the LCD display
static void lcd_reset()
{
    // Blip the reset pin to reset the LCD controller
    gpio_set_pulls(LCD_RST, false, false);
    gpio_pull_up(LCD_RST);
    gpio_put(LCD_RST, 1);
    sleep_ms(10);
    gpio_pull_down(LCD_RST);
    gpio_put(LCD_RST, 0);
    sleep_ms(10);
    gpio_pull_up(LCD_RST);
    gpio_put(LCD_RST, 1);
    sleep_ms(200);
}

// Protect the SPI bus with a semaphore
static void lcd_aquire()
{
    sem_acquire_blocking(&lcd_sem);
}

// Release the SPI bus
static void lcd_release()
{
    sem_release(&lcd_sem);
}

// Send a command
static void lcd_write_cmd(uint8_t cmd)
{
    gpio_put(LCD_DCX, 0);
    gpio_put(LCD_CSX, 0);
    spi_write_blocking(spi1, &cmd, 1);
    gpio_put(LCD_CSX, 1);
}

// Send 8-bit data (byte)
static void lcd_write_data(uint8_t len, ...)
{
    va_list args;
    va_start(args, len);
    gpio_put(LCD_DCX, 1);
    gpio_put(LCD_CSX, 0);
    for (uint8_t i = 0; i < len; i++)
    {
        uint8_t data = va_arg(args, int); // get the next byte of data
        spi_write_blocking(spi1, &data, 1);
    }
    gpio_put(LCD_CSX, 1);
    va_end(args);
}

// Send 16-bit data (half-word)
static void lcd_write16_data(uint8_t len, ...)
{
    va_list args;
    va_start(args, len);
    gpio_put(LCD_DCX, 1);
    gpio_put(LCD_CSX, 0);
    spi_set_format(spi1, 16, 0, 0, SPI_MSB_FIRST);
    for (uint8_t i = 0; i < len; i++)
    {
        uint16_t data = va_arg(args, int); // get the next half-word of data
        spi_write16_blocking(spi1, &data, 1);
    }
    spi_set_format(spi1, 8, 0, 0, SPI_MSB_FIRST);
    gpio_put(LCD_CSX, 1);
    va_end(args);
}

// Send a buffer of 16-bit data (half-words)
static void lcd_write16_buf(const uint16_t* buffer, size_t len)
{
    gpio_put(LCD_DCX, 1);
    gpio_put(LCD_CSX, 0);
    spi_set_format(spi1, 16, 0, 0, SPI_MSB_FIRST);
    spi_write16_blocking(spi1, buffer, len);
    spi_set_format(spi1, 8, 0, 0, SPI_MSB_FIRST);
    gpio_put(LCD_CSX, 1);
}

// Turn on the LCD display
static void lcd_display_on()
{
    lcd_aquire();
    lcd_write_cmd(LCD_CMD_DISPON);
    lcd_release();
}

// Turn off the LCD display
static void lcd_display_off()
{
    lcd_aquire();
    lcd_write_cmd(LCD_CMD_DISPOFF);
    lcd_release();
}

// Select the target of the pixel data in the display RAM that will follow
static void lcd_set_window(int x0, int y0, int x1, int y1)
{
    // Set column address (X)
    lcd_write_cmd(LCD_CMD_CASET);
    lcd_write_data(4,
        UPPER8(x0), LOWER8(x0),
        UPPER8(x1), LOWER8(x1));

    // Set row address (Y)
    lcd_write_cmd(LCD_CMD_RASET);
    lcd_write_data(4,
        UPPER8(y0), LOWER8(y0),
        UPPER8(y1), LOWER8(y1));

    // Prepare to write to RAM
    lcd_write_cmd(LCD_CMD_RAMWR);
}

// Send pixel data to the display
static void lcd_blit(uint16_t* pixels, int x, int y, int width, int height)
{
    // Adjust y for vertical scroll offset and wrap within memory height
    int y_virtual = (y + lcd_y_offset) % MEM_HEIGHT;

    lcd_aquire();
    lcd_set_window(x, y_virtual, x + width - 1, y_virtual + height - 1);
    lcd_write16_buf((uint16_t*)pixels, width * height);
    lcd_release();
}

// Draw a rectangle on the display
static void lcd_rect(uint16_t color, int x, int y, int width, int height)
{
    static uint16_t pixels[WIDTH];

    for (int row = 0; row < height; row++) {
        for (int i = 0; i < width; i++) {
            pixels[i] = color;
        }
        lcd_blit(pixels, x, y + row, width, 1);
    }
}

// Set the scrolling area of the display
//
// This forum post provides a good explanation of how scrolling on the ST7789P display works:
// https://forum.arduino.cc/t/st7735s-scrolling/564506
static void lcd_define_scrolling(int top_fixed_area, int bottom_fixed_area)
{
    int scroll_area = HEIGHT - (top_fixed_area + bottom_fixed_area);

    lcd_aquire();
    lcd_write_cmd(LCD_CMD_VSCRDEF);
    lcd_write_data(6,
        UPPER8(top_fixed_area),
        LOWER8(top_fixed_area),
        UPPER8(scroll_area), 
        LOWER8(scroll_area),
        UPPER8(bottom_fixed_area),
        LOWER8(bottom_fixed_area));
    lcd_release();
}

// Scroll the screen up one line (make space at the bottom)
static void lcd_scroll_up()
{
    // The will rotate the content in the scroll area up by one line
    lcd_y_offset = (lcd_y_offset + GLYPH_HEIGHT) % MEM_HEIGHT;
    lcd_aquire();
    lcd_write_cmd(LCD_CMD_VSCSAD);
    lcd_write_data(2, UPPER8(lcd_y_offset), LOWER8(lcd_y_offset));
    lcd_release();

    // Clear the new line at the bottom
    lcd_rect(palette[background], 0, HEIGHT - GLYPH_HEIGHT, WIDTH, GLYPH_HEIGHT);
}

// Scroll the screen down one line (making space at the top)
static void lcd_scroll_down() {
    // This will rotate the content in the scroll area down by one line
    lcd_y_offset = (lcd_y_offset - GLYPH_HEIGHT + MEM_HEIGHT) % MEM_HEIGHT;
    lcd_aquire();
    lcd_write_cmd(LCD_CMD_VSCSAD);
    lcd_write_data(2, UPPER8(lcd_y_offset), LOWER8(lcd_y_offset));
    lcd_release();

    // Clear the new line at the top
    lcd_rect(palette[background], 0, 0, WIDTH, GLYPH_HEIGHT);
}

// Clear the entire screen
static void lcd_clear_screen()
{
    lcd_rect(palette[background], 0, 0, WIDTH, MEM_HEIGHT);
}

// Draw a character at the specified position
// - I optimised the heck out of this function, and it didn't make any perceived difference
//   in performance. I left it as is. :(
static void lcd_putc(int x, int y, uint8_t c)
{
    uint8_t* glyph = &font[c * GLYPH_HEIGHT];
    uint16_t* buffer = char_buffer;
    int fore = palette[foreground];
    int back = palette[background];

    for (int i = 0; i < GLYPH_HEIGHT; i++, glyph++)
    {
        *(buffer++) = (*glyph & 0x80) ? fore : back;
        *(buffer++) = (*glyph & 0x40) ? fore : back;
        *(buffer++) = (*glyph & 0x20) ? fore : back;
        *(buffer++) = (*glyph & 0x10) ? fore : back;
        *(buffer++) = (*glyph & 0x08) ? fore : back;
        *(buffer++) = (*glyph & 0x04) ? fore : back;
        *(buffer++) = (*glyph & 0x02) ? fore : back;
        *(buffer++) = (*glyph & 0x01) ? fore : back; 
    }

    lcd_blit(char_buffer, x << 3, y * GLYPH_HEIGHT, 8, GLYPH_HEIGHT);
}

// Draw the cursor at the current position
static void lcd_draw_cursor()
{
    lcd_rect(palette[CURSOR_COLOR], cursor_x << 3, ((cursor_y + 1) * GLYPH_HEIGHT) - 1, 8, 1);
}

// Erase the cursor at the current position
static void lcd_erase_cursor()
{
    lcd_rect(palette[background], cursor_x << 3, ((cursor_y + 1) * GLYPH_HEIGHT) - 1, 8, 1);
}


//
// Display API
//

bool display_emit_available()
{
    return true;                        // always available for output in this implementation
}

void display_emit(char ch)
{
    lcd_erase_cursor(x, y);
    if (state == STATE_NORMAL)
    {
        if (ch == 0x1B)                 // escape (start of an ANSI escape sequence?)
        {
            state = STATE_ESCAPE;
        }
        else if (ch == 0x0D)            // carriage return
        {
            x = 0;                      // move cursor to the start of the line
        }
        else if (ch == 0x0A)            // line feed
        {
            y++;                        // move cursor down one line (scroll processed later)
        }
        else if (ch == 0x08)            // backspace
        {
            x = MAX(0, x - 1);          // move cursor back one space (but not before the start of the line)
        }
        else if (ch == 0x09)            // tab
        {
            x += MIN(((x + 4) & ~3), MAX_COL);  // move cursor forward by 4 spaces (but not beyond the end of the line)
        }
        else if (ch >= 0x20 && ch < 0x7F) // printable characters
        {
            lcd_putc(x++, y, ch);
        }
    }
    else if (state == STATE_ESCAPE)
    {
        if (ch == '[')                  // start of control sequence
        {
            state = STATE_CONTROL;
            // reset parameters
            params_index = 0;
            memset(params, 0, sizeof(params));
        }
        else if (ch == '7')             // save cursor
        {
            save_x = x;
            save_y = y;
            state = STATE_NORMAL;
        }
        else if (ch == '8')             // restore cursor
        {
            x = save_x;
            y = save_y;
            state = STATE_NORMAL;
        }
        else if (ch == 'c')             // reset command
        {
            x = y = 0;
            foreground = DEFAULT_FOREGROUND;
            background = DEFAULT_BACKGROUND;
            lcd_clear_screen();
            state = STATE_NORMAL;
        }
        else if (ch == 'D')             // index
        {
            y++;
        }
        else if (ch == 'E')             // next line
        {
            x = 0;
            y++;
        }
        else if (ch == 'M')             // reverse index
        {
            y--;
        }
        else                            // not a valid escape sequence, reset state
        {
            state = STATE_NORMAL;
        }
    }
    else if (state == STATE_CONTROL)
    {
        if (ch >= '0' && ch <= '9')     // build the parameter value
        {
            params[params_index] *= 10;
            params[params_index] += ch - '0'; // convert char to digit
        }
        else if (ch == ';')             // delimiter for multiple parameters
        {
            if (params_index < sizeof(params) - 1)
            {
                params_index++;
            }
        }
        else                            // must be the end of ANSI mode control sequences
        {
            switch (ch)
            {
                case 'A':               // cursor up
                    y = MAX(0, y - params[0]);
                    break;
                case 'B':               // cursor down
                    y = MIN(y + params[0], MAX_ROW);
                    break;
                case 'C':               // cursor right
                    x = MIN(x + params[0], MAX_COL);
                    break;
                case 'D':               // cursor left
                    x = MAX(0, x - params[0]);
                    break;
                case 'J':               // erase in display
                    lcd_clear_screen();
                    break;
                case 'm':               // select graphic rendition
                    // start with reset defaults
                    underline = false;
                    foreground = DEFAULT_FOREGROUND;
                    background = DEFAULT_BACKGROUND;

                    if (params[0] == 1) // bold
                    {
                        foreground = 7; // bright white
                    }
                    else if (params[0] == 2) // dim
                    {
                        foreground = 8; // dim white
                    }
                    else if (params[0] == 4) // underline
                    {
                        underline = true;
                    }
                    else if (params[0] == 7) // reverse video
                    {
                        uint8_t temp = foreground;
                        foreground = background;
                        background = temp;
                    }
                    else if (params[0] >= 30 && params[0] <= 37)
                    {
                        foreground = params[0] - 30; // set foreground color
                    }
                    else if (params[0] >= 40 && params[0] <= 47)
                    {
                        background = params[0] - 40; // set background color
                    }
                    break;
                case 'f':
                case 'H':               // move cursor to position
                    x = MIN(params[0], MAX_COL);
                    y = MIN(params[1], MAX_ROW);
                    break;
                default:
                    break;              // ignore unknown sequences
            }
            state = STATE_NORMAL;
        }
    }
    
    // Handle wrapping and scrolling
    if (x > MAX_COL)                    // wrap around at end of the line
    {
        x = 0;
        y++;
    }

    if (y < 0)                          // scroll at top of the screen
    {
        while (y < 0)                   // scroll until y is non-negative
        {
            lcd_scroll_down();          // scroll down to make space at the top
            y++;
        }
    }
    if (y > MAX_ROW)                    // scroll at bottom of the screen
    {
        while (y > MAX_ROW)             // scroll until y is within bounds
        {
            lcd_scroll_up();            // scroll up to make space at the bottom
            y--;
        }
    }

    cursor_x = x;                       // update cursor position for drawing
    cursor_y = y;                       // update cursor position for drawing
    lcd_draw_cursor();                      // draw the cursor at the new position
}

bool on_cursor_timer(repeating_timer_t *rt)
{
    static bool cursor_visible = false;

    if (sem_available(&lcd_sem) == 0)
    {
        return true; // If SPI is not available, do not toggle cursor
    }

    if (cursor_visible)
    {
        lcd_erase_cursor();
    }
    else
    {
        lcd_draw_cursor();
    }

    cursor_visible = !cursor_visible;     // Toggle cursor visibility
    return true;                          // Keep the timer running
}


void display_init()
{
    // initialise GPIO
    gpio_init(LCD_SCL);
    gpio_init(LCD_SDI);
    gpio_init(LCD_SDO);
    gpio_init(LCD_CSX);
    gpio_init(LCD_DCX);
    gpio_init(LCD_RST);

    gpio_set_dir(LCD_SCL, GPIO_OUT);
    gpio_set_dir(LCD_SDI, GPIO_OUT);
    gpio_set_dir(LCD_CSX, GPIO_OUT);
    gpio_set_dir(LCD_DCX, GPIO_OUT);
    gpio_set_dir(LCD_RST, GPIO_OUT);

    // initialise 4-wire SPI
    spi_init(spi1, LCD_BAUDRATE);
    gpio_set_function(LCD_SCL, GPIO_FUNC_SPI);
    gpio_set_function(LCD_SDI, GPIO_FUNC_SPI);
    gpio_set_function(LCD_SDO, GPIO_FUNC_SPI);
    gpio_set_input_hysteresis_enabled(LCD_SDO, true);

    gpio_put(LCD_CSX, 1);
    gpio_put(LCD_RST, 1);

    lcd_reset();                        // reset the LCD controller

    lcd_write_cmd(LCD_CMD_PGC);         // positive gamma control
    lcd_write_data(15,
        0x00, 0x03, 0x09, 0x08,
        0x16, 0x0A, 0x3F, 0x78,
        0x4C, 0x09, 0x0A, 0x08,
        0x16, 0x1A, 0x0F);

    lcd_write_cmd(LCD_CMD_NGC);         // negative gamma control
    lcd_write_data(15,
        0x00, 0x16, 0x19, 0x03,
        0x0F, 0x05, 0x32, 0x45,
        0x46, 0x04, 0x0E, 0x0D,
        0x35, 0x37, 0x0F);

    lcd_write_cmd(LCD_CMD_PWR1);        // power control 1
    lcd_write_data(2, 0x17, 0x15);      // 0x17=VREG1OUT=4.6V, 0x15=VREG2OUT=4.4V

    lcd_write_cmd(LCD_CMD_PWR2);        // power control 2
    lcd_write_data(1, 0x41);            // 0x41=VGH=4.4V, VGL=-4.4V

    lcd_write_cmd(LCD_CMD_VCMPCTL);     // VCOM control
    lcd_write_data(3, 0x00, 0x12, 0x80);// 0x80=0.85V

    lcd_write_cmd(LCD_CMD_MADCTL);      // Memory Access Control
    lcd_write_data(1, 0x48);            // 0x48=BGR

    lcd_write_cmd(LCD_CMD_COLMOD);      // pixel format set
    lcd_write_data(1, 0x55);            // 16 bit color (565) for SPI

    lcd_write_cmd(LCD_CMD_IFMODE);      // interface mode control
    lcd_write_data(1, 0x00);            // 4-wire SPI

    lcd_write_cmd(LCD_CMD_FRMCTR1);     // frame rate control (in normal mode)
    lcd_write_data(2, 0xD0, 0x11);      // 0xD0=60Hz, 0x11=1/1 duty cycle

    lcd_write_cmd(LCD_CMD_INVON);       // display inversion on

    lcd_write_cmd(LCD_CMD_DIC);         // display inversion control
    lcd_write_data(1, 0x02);            // 0x02=DCI=1, DIC=0

    lcd_write_cmd(LCD_CMD_DFC);         // display function control
    lcd_write_data(3, 0x02, 0x02, 0x3B); // 0x02=SS=1, GS=1, SM=0, ISC=0, BGR=1

    lcd_write_cmd(LCD_CMD_EMS);         // entry mode set
    lcd_write_data(1, 0xC6);            // 0xC6=SS=1, GS=1, SM=0, ISC=0, BGR=1

    lcd_write_cmd(LCD_CMD_E9);          // adjust control
    lcd_write_data(1, 0x00);            // 0x00=default
    lcd_write_cmd(LCD_CMD_F7);          // adjust control 3
    lcd_write_data(4, 0xA9, 0x51, 0x2C, 0x82); // 0xA9=default, 0x51=default, 0x2C=default, 0x82=default

    lcd_write_cmd(LCD_CMD_SLPOUT);      // sleep out
    sleep_ms(120);                      // wait for the display to wake up
    
    gpio_put(LCD_CSX, 1);

    // Prevent the bliking cursor from interfering with other operations
    sem_init(&lcd_sem, 1, 1);

    lcd_define_scrolling(0, 0);        // no fixed areas for scrolling
    lcd_clear_screen();
    lcd_display_on();

    // Blink the cursor every second (500 ms on, 500 ms off)
    add_repeating_timer_ms(500, on_cursor_timer, NULL, &cursor_timer);
}