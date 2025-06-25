//
//  ANS Forth for the Clockwork PicoCalc
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

//
//  PicoCalc LCD display driver
//
//  This driver implements a simple VT100 terminal interface for the PicoCalc LCD display
//  using the ST7789P LCD controller.
//
//  It is optimised for a character-based display with a fixed-width, 8-pixel wide font
//  and 65K colours in the RGB565 format. This driver requires little memory as it
//  uses the frame memory on the controller directly.
//
//  NOTE: Some code below is written to respect timing constraints of the ST7789P controller.
//        For instance, you can usually get away with a short chip select high pulse widths, but
//        writing to the display RAM requires the minimum chip select high pulse width of 40ns.
//

#include "pico/stdlib.h"
#include "pico/multicore.h"
#include "hardware/spi.h"

#include "string.h"

#include "display.h"

//
//  LCD Driver
//
//  This section contains the definitions and variables used for handling
//  the LCD display.
//

// Cursor positioning and scrolling
uint8_t cursor_x = 0;                   // cursor x position for drawing
uint8_t cursor_y = 0;                   // cursor y position for drawing
uint16_t lcd_y_offset = 0;              // offset for vertical scrolling

uint16_t foreground = FOREGROUND;       // default foreground colour (white phosphor)
uint16_t background = BACKGROUND;       // default background colour (black)

bool underscore = false;                // underscore state (not implemented)
bool reverse = false;                   // reverse video state (not implemented)

// Text drawing
extern uint8_t font[];
uint16_t char_buffer[8 * GLYPH_HEIGHT] __attribute__ ((aligned(4))); 

// Background processing
semaphore_t lcd_sem;
static repeating_timer_t cursor_timer;

// Reset the LCD display
static void lcd_reset()
{
    // Blip the reset pin to reset the LCD controller
    gpio_put(LCD_RST, 0);
    sleep_us(20);                       // 20µs reset pulse (10µs minimum)

    gpio_put(LCD_RST, 1);
    sleep_ms(120);                      // 5ms required after reset, but 120ms needed before sleep out command
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


//
// Low-level SPI functions
//

// Send a command
static void lcd_write_cmd(uint8_t cmd)
{
    gpio_put(LCD_DCX, 0);               // Command
    gpio_put(LCD_CSX, 0);
    spi_write_blocking(spi1, &cmd, 1);
    gpio_put(LCD_CSX, 1);
}

// Send 8-bit data (byte)
static void lcd_write_data(uint8_t len, ...)
{
    va_list args;
    va_start(args, len);
    gpio_put(LCD_DCX, 1);               // Data
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

    // DO NOT MOVE THE spi_set_format() OR THE gpio_put(LCD_DCX) CALLS!
    // They are placed before the gpio_put(LCD_CSX) to ensure that a minimum
    // chip select high pulse width is achieved (at least 40ns)
    spi_set_format(spi1, 16, 0, 0, SPI_MSB_FIRST);

    va_start(args, len);
    gpio_put(LCD_DCX, 1);               // Data
    gpio_put(LCD_CSX, 0);
    for (uint8_t i = 0; i < len; i++)
    {
        uint16_t data = va_arg(args, int); // get the next half-word of data
        spi_write16_blocking(spi1, &data, 1);
    }
    gpio_put(LCD_CSX, 1);
    va_end(args);

    spi_set_format(spi1, 8, 0, 0, SPI_MSB_FIRST);
}

// Send a buffer of 16-bit data (half-words)
static void lcd_write16_buf(const uint16_t* buffer, size_t len)
{
    // DO NOT MOVE THE spi_set_format() OR THE gpio_put(LCD_DCX) CALLS!
    // They are placed before the gpio_put(LCD_CSX) to ensure that a minimum
    // chip select high pulse width is achieved (at least 40ns)
    spi_set_format(spi1, 16, 0, 0, SPI_MSB_FIRST);

    gpio_put(LCD_DCX, 1);               // Data
    gpio_put(LCD_CSX, 0);
    spi_write16_blocking(spi1, buffer, len);
    gpio_put(LCD_CSX, 1);

    spi_set_format(spi1, 8, 0, 0, SPI_MSB_FIRST);
}


//
//  ST7365P LCD controller functions
//

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


//
//  Send pixel data to the display
//
//  All display RAM updates come through this function. This function is responsible for
//  setting the correct window in the display RAM and writing the pixel data to it. It also
//  handles the vertical scrolling by adjusting the y-coordinate based on the current scroll
//  offset (lcd_y_offset).
//
//  The pixel data is expected to be in RGB565 format, which is a 16-bit value with the
//  red component in the upper 5 bits, the green component in the middle 6 bits, and the
//  blue component in the lower 5 bits.

static void lcd_blit(uint16_t* pixels, int x, int y, int width, int height)
{
    // Adjust y for vertical scroll offset and wrap within memory height
    int y_virtual = (y + lcd_y_offset) % FRAME_HEIGHT;

    lcd_aquire();
    lcd_set_window(x, y_virtual, x + width - 1, y_virtual + height - 1);
    lcd_write16_buf((uint16_t*)pixels, width * height);
    lcd_release();
}

// Draw a solid rectangle on the display
static void lcd_solid_rectangle(uint16_t color, int x, int y, int width, int height)
{
    static uint16_t pixels[WIDTH];

    for (int row = 0; row < height; row++) {
        for (int i = 0; i < width; i++) {
            pixels[i] = color;
        }
        lcd_blit(pixels, x, y + row, width, 1);
    }
}


//
//  Set the scrolling area of the display
//
//  This forum post provides a good explanation of how scrolling on the ST7789P display works:
//      https://forum.arduino.cc/t/st7735s-scrolling/564506
//
//  These functions (lcd_define_scrolling, lcd_scroll_up, and lcd_scroll_down) configure and
//  set the vertical scrolling area of the display, but it is the responsibility of lcd_blit()
//  to ensure that the pixel data is written to the correct location in the display RAM.
//

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
    lcd_y_offset = (lcd_y_offset + GLYPH_HEIGHT) % FRAME_HEIGHT;
    lcd_aquire();
    lcd_write_cmd(LCD_CMD_VSCSAD);      // Sets where in display RAM the scroll area starts
    lcd_write_data(2, UPPER8(lcd_y_offset), LOWER8(lcd_y_offset));
    lcd_release();

    // Clear the new line at the bottom
    lcd_solid_rectangle(background, 0, HEIGHT - GLYPH_HEIGHT, WIDTH, GLYPH_HEIGHT);
}

// Scroll the screen down one line (making space at the top)
static void lcd_scroll_down() {
    // This will rotate the content in the scroll area down by one line
    lcd_y_offset = (lcd_y_offset - GLYPH_HEIGHT + FRAME_HEIGHT) % FRAME_HEIGHT;
    lcd_aquire();
    lcd_write_cmd(LCD_CMD_VSCSAD);      // Sets where in display RAM the scroll area starts
    lcd_write_data(2, UPPER8(lcd_y_offset), LOWER8(lcd_y_offset));
    lcd_release();

    // Clear the new line at the top
    lcd_solid_rectangle(background, 0, 0, WIDTH, GLYPH_HEIGHT);
}

// Clear the entire screen
static void lcd_clear_screen()
{
    lcd_solid_rectangle(background, 0, 0, WIDTH, FRAME_HEIGHT);
}

// Draw a character at the specified position
static void lcd_putc(int x, int y, uint8_t c)
{
    uint8_t* glyph = &font[c * GLYPH_HEIGHT];
    uint16_t* buffer = char_buffer;

    for (int i = 0; i < GLYPH_HEIGHT; i++, glyph++)
    {
        *(buffer++) = (*glyph & 0x80) ? foreground : background;
        *(buffer++) = (*glyph & 0x40) ? foreground : background;
        *(buffer++) = (*glyph & 0x20) ? foreground : background;
        *(buffer++) = (*glyph & 0x10) ? foreground : background;
        *(buffer++) = (*glyph & 0x08) ? foreground : background;
        *(buffer++) = (*glyph & 0x04) ? foreground : background;
        *(buffer++) = (*glyph & 0x02) ? foreground : background;
        *(buffer++) = (*glyph & 0x01) ? foreground : background; 
    }

    lcd_blit(char_buffer, x << 3, y * GLYPH_HEIGHT, 8, GLYPH_HEIGHT);
}

// Draw the cursor at the current position
static void lcd_draw_cursor()
{
    lcd_solid_rectangle(foreground, cursor_x << 3, ((cursor_y + 1) * GLYPH_HEIGHT) - 1, 8, 1);
}

// Erase the cursor at the current position
static void lcd_erase_cursor()
{
    lcd_solid_rectangle(background, cursor_x << 3, ((cursor_y + 1) * GLYPH_HEIGHT) - 1, 8, 1);
}



//
//  VT100 Terminal Emulation
//
//  This section contains the definitions and variables used for handling
//  ANSI escape sequences, cursor positioning, and text attributes.
//
//  Reference: https://vt100.net/docs/vt100-ug/chapter3.html
//

uint8_t state = STATE_NORMAL;           // initial state of escape sequence processing
uint8_t x = 0;                          // cursor x position
uint8_t y = 0;                          // cursor y position

uint8_t parameters[16];                 // buffer for selective parameters
uint8_t p_index = 0;                    // index into the buffer

uint8_t save_x = 0;                     // saved cursor x position for DECSC/DECRC
uint8_t save_y = 0;                     // saved cursor y position for DECSC/DECRC


bool display_emit_available()
{
    return true;                        // always available for output in this implementation
}

void display_emit(char ch)
{
    lcd_erase_cursor(x, y);

    // State machine for processing incoming characters
    switch (state)
    {
        case STATE_ESCAPE:                  // ESC character received, process the next character
            state = STATE_NORMAL;           // reset state by default
            switch (ch)
            {
                case 0x18:                  // CAN – cancel the current escape sequence
                case 0x1A:                  // SUB – same as cancel
                    lcd_putc(x++, y, 0x02); // print a error character
                    break;
                case 0x1B:                  // ESC - Escape    
                    state = STATE_ESCAPE;   // stay in escape state
                    break;
                case '7':                   // DECSC – Save Cursor
                    save_x = x;
                    save_y = y;
                    break;
                case '8':                   // DECRC – Restore Cursor
                    x = save_x;
                    y = save_y;
                    break;
                case 'D':                   // IND – Index
                    y++;
                    break;
                case 'E':                   // NEL – Next Line
                    x = 0;
                    y++;
                    break;
                case 'M':                   // RI – Reverse Index
                    y--;
                    break;
                case 'c':                   // RIS – Reset To Initial State
                    x = y = 0;
                    foreground = FOREGROUND;
                    background = BACKGROUND;
                    underscore = false;
                    reverse = false;
                    lcd_clear_screen();
                    break;
                case '[':                   // CSI - Control Sequence Introducer
                    p_index = 0;
                    memset(parameters, 0, sizeof(parameters));
                    state = STATE_CS;
                    break;
                default:
                    // not a valid escape sequence, should we print an error?
                    break;
            }
            break;

        case STATE_CS:                      // in Control Sequence
            if (ch == 0x1B)                 // ESC
            {
                state = STATE_ESCAPE;
                break;                      // reset to escape state
            }
            else if (ch >= '0' && ch <= '9')
            {
                parameters[p_index] *= 10;  // accumulate digits
                parameters[p_index] += ch - '0';
            }
            else if (ch == ';')             // delimiter
            {
                if (p_index < sizeof(parameters) - 1)
                {
                    p_index++;
                }
            }
            else                            // final character in control sequence
            {
                state = STATE_NORMAL;       // reset state after processing the control sequence
                switch (ch)
                {
                    case 'A':               // CUU – Cursor Up
                        y = MAX(0, y - parameters[0]);
                        break;
                    case 'B':               // CUD – Cursor Down
                        y = MIN(y + parameters[0], MAX_ROW);
                        break;
                    case 'C':               // CUF – Cursor Forward
                        x = MIN(x + parameters[0], MAX_COL);
                        break;
                    case 'D':               // CUB - Cursor Backward
                        x = MAX(0, x - parameters[0]);
                        break;
                    case 'J':               // ED – Erase In Display
                        lcd_clear_screen(); // Only support clearing the entire screen (2)
                        break;
                    case 'm':               // SGR – Select Graphic Rendition
                        for (int i =0; i <= p_index; i++)
                        {
                            if (parameters[i] == 0)     // attributes off
                            {
                                foreground = FOREGROUND;
                                background = BACKGROUND;
                                underscore = false;
                                reverse = false;
                            }
                            else if (parameters[i] == 1) // bold or increased intensity
                            {
                                foreground = BRIGHT;
                            }
                            else if (parameters[i] == 4) // underscore
                            {
                                underscore = true;
                            }
                            // No support for blink (5)
                            else if (parameters[i] == 7) // negative (reverse) image
                            {
                                reverse = true;
                            }
                        }
                        break;
                    case 'f':               // HVP – Horizontal and Vertical Position
                    case 'H':               // CUP – Cursor Position
                        x = MIN(parameters[0], MAX_COL);
                        y = MIN(parameters[1], MAX_ROW);
                        break;
                    case 0x18:              // CAN – cancel the current escape sequence
                    case 0x1A:              // SUB – same as cancel
                        lcd_putc(x++, y, 0x02); // print a error character
                        break;
                    default:
                        break;              // ignore unknown sequences
                }
            }
            break;

        case STATE_NORMAL:
        default:
            // Normal/default state, process characters directly
            switch (ch)
            {
                case 0x08:              // BS
                    x = MAX(0, x - 1);  // move cursor back one space (but not before the start of the line)
                    break;
                case 0x07:              // BEL
                    // No action for bell in this implementation
                    break;
                case 0x09:              // HT
                    x += MIN(((x + 4) & ~3), MAX_COL); // move cursor forward by 1 tabstop (but not beyond the end of the line)
                    break;
                case 0x0A:              // LF
                case 0x0B:              // VT
                case 0x0C:              // FF
                    y++;                // move cursor down one line
                    break;
                case 0x0D:              // CR
                    x = 0;              // move cursor to the start of the line
                    break;
                case 0x1B:              // ESC
                    state = STATE_ESCAPE;
                    break;
                default:
                    if (ch >= 0x20 && ch < 0x7F) // printable characters
                    {
                        lcd_putc(x++, y, ch);
                    }
                    // No action on non-printable characters
                    break;
            }
            break;
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
    lcd_draw_cursor();                  // draw the cursor at the new position
}



//
//  Background processing
//
//  Handle background tasks such as blinking the cursor
//

// Blink the cursor at regular intervals
bool on_cursor_timer(repeating_timer_t *rt)
{
    static bool cursor_visible = false;

    if (!sem_available(&lcd_sem))
    {
        return true;                    // if the SPI bus is not available, do not toggle cursor
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



//
//  Display Initialization
//

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

    gpio_put(LCD_CSX, 1);
    gpio_put(LCD_RST, 1);

    lcd_reset();                        // reset the LCD controller

    lcd_write_cmd(LCD_CMD_SWRESET);     // reset the commands and parameters to their S/W Reset default values
    sleep_ms(10);                       // required to wait at least 5ms

    lcd_write_cmd(LCD_CMD_COLMOD);      // pixel format set
    lcd_write_data(1, 0x55);            // 16 bit/pixel (RGB565)

    lcd_write_cmd(LCD_CMD_MADCTL);      // memory access control
    lcd_write_data(1, 0x48);            // BGR colour filter panel, top to bottom, left to right

    lcd_write_cmd(LCD_CMD_INVON);       // display inversion on

    lcd_write_cmd(LCD_CMD_EMS);         // entry mode set
    lcd_write_data(1, 0xC6);            // normal display, 16-bit (RGB) to 18-bit (rgb) color
                                        //   conversion: r(0) = b(0) = G(0)

    lcd_write_cmd(LCD_CMD_VSCRDEF);     // vertical scroll definition
    lcd_write_data(6,
        0x00, 0x00,                     // top fixed area of 0 pixels
        0x01, 0x40,                     // scroll area height of 320 pixels
        0x00, 0x00                      // bottom fixed area of 0 pixels
    );

    lcd_write_cmd(LCD_CMD_SLPOUT);      // sleep out
    sleep_ms(10);                       // required to wait at least 5ms
    
    // Prevent the blinking cursor from interfering with other operations
    sem_init(&lcd_sem, 1, 1);

    // Clear the screen
    lcd_clear_screen();

    // Now that the display is initialized, display RAM garbage is cleared,
    // turn on the display
    lcd_display_on();

    // Blink the cursor every second (500 ms on, 500 ms off)
    add_repeating_timer_ms(500, on_cursor_timer, NULL, &cursor_timer);
}