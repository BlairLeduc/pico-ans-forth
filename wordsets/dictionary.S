@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Dictionary in Flash.
@

    .include "forth.S"

    @   Keep track of the the last created dictionary entry.
    .set link, 0

    @   Jump to the word following this one
    .equ JUMP_TO, 0x47184B00          @ ldr/bx

@
@   1.1.6 Numeric Input
@

    @   6.1.0750    BASE ( -— a-addr ) [core]
    defvar "BASE",BASE,10

    @   6.1.1170    DECIMAL ( —- ) [core]
    defword "DECIMAL",,DECIMAL
    .word LITERAL, 10, BASE, STORE
    .word EXIT

    @   6.2.1660    HEX ( —- ) [core]
    defword "HEX",,HEX
    .word LITERAL, 16, BASE, STORE
    .word EXIT


@
@   1.4.1 Comments (FPH, p22)
@

    @   6.2.0200    ( ( “ccc<paren>” -- ) "paren" [core]
    @
    @   Parse ccc delimited by ) (right parenthesis). ( is an immediate word.
    @   The number of characters in ccc may be zero to the number of characters in the parse area.

    defword "(",CB_PRECEDENCE,COMMENT
    .word LITERAL, ')'
    .word PARSE
    .word TWODROP
    .word EXIT

    @   6.2.0200    .( ( -- ) [core ext]
    defcode ".(",CB_PRECEDENCE,DOT_PAREN,_dot_paren


    @   6.2.2535    \ ( -- ) [core ext]
    @   This word is special since it processed internally in INTERPRET
 
@
@   1.4.4 Decompiler and Disassembler
@

    @   15.6.1.2194 SEE <name> ( —- ) [tools]
    @   TODO


@
@   2.1.2 Data Stack Manipulation Operations (FPH, p33)
@

    @   6.1.0370    2DROP ( x1 x2 —- ) [core]
    defcode "2DROP",,TWODROP,_twodrop

    @   6.1.0380    2DUP ( x1 x2 —- x1 x2 x1 x2 ) [core]
    defcode "2DUP",,TWODUP,_twodup

    @   6.1.0400    2OVER ( x1 x2 x3 x4 —- x1 x2 x3 x4 x1 x2 ) [core]
    defcode "2OVER",,TWOOVER,_twoover

    @   6.1.0430    2SWAP ( x1 x2 x3 x4 -— x3 x4 x1 x2 ) [core]
    defcode "2SWAP",,TWOSWAP,_twoswap

    @   6.1.0630    ?DUP ( x -— 0 | x x ) [core]
    defcode "?DUP",,QDUP,_qdup

    @   6.1.1200    DEPTH ( -- +n ) [core]
    defcode "DEPTH",,DEPTH,_depth

    @   6.1.1260    DROP ( x —- ) [core]
    defcode "DROP",,DROP,_drop

    @   6.1.1290    DUP ( x —- x x ) [core]
    defcode "DUP",,DUP,_dup

    @   6.2.1930    NIP ( x1 x2 —- x2 ) [core ext]
    defword "NIP",,NIP                  @ : nip swap drop ; 
    .word SWAP
    .word DROP
    .word EXIT

    @   6.1.1990    OVER ( x1 x2 —- x1 x2 x1 ) [core]
    defcode "OVER",,OVER,_over

    @   6.2.2030    PICK ( +n —- x ) [core ext]
    defcode "PICK",,PICK,_pick

    @   6.2.2150    ROLL ( +n —- x ) [core ext]
    defword "ROLL",,ROLL                @ : roll dup 0branch ( 32 ) swap >r 1- roll r> swap exit drop ;
    .word DUP
    .word ZBRANCH, 32                   @ if zero, do nothing
    .word SWAP
    .word TOR                           @ save the number of elements to roll
    .word DECR
    .word ROLL                          @ recurse, roll the stack
    .word FROMR                         @ restore the number of elements to roll
    .word SWAP
    .word EXIT
    .word DROP
    .word EXIT

    @   6.1.2160    ROT ( x1 x2 x3 —- x2 x3 x1 ) [core]
    defcode "ROT",,ROT,_rot

    @               -ROT ( x1 x2 x3 -- x3 x1 x2 ) [common usage]
    defcode "-ROT",,NROT,_nrot

    @   6.1.2260    SWAP ( x1 x2 —- x2 x1 ) [core]
    defcode "SWAP",,SWAP,_swap

    @   6.2.2300    TUCK ( x1 x2 —- x2 x1 x2 ) [core ext]
    defword "TUCK",,TUCK                @ : tuck swap over ;
    .word SWAP
    .word OVER
    .word EXIT


@
@   2.3.4 Memory Stack Operations (FPH, p69)
@

    @   6.1.0010    ! ( x a-addr —- ) [core]
    defcode "!",,STORE,_store

    @   6.1.0130    +! ( n a-addr —- ) [core]
    defcode "+!",,ADDSTORE,_addstore

    @   6.1.0310    2! ( x1 x2 a-addr —- ) [core]
    defcode "2!",,TWOSTORE,_twostore

    @   6.1.0350    2@ ( a-addr —- x1 x2 ) [core]
    defcode "2@",,TWOFETCH,_twofetch

    @   6.1.0650    @ ( a-addr —- x ) [core]
    defcode "@",,FETCH,_fetch

    @   6.1.0850    C! ( b c-addr —- ) [core]
    defcode "C!",,STOREBYTE,_storebyte

    @               C+! ( b c-addr —- ) [common usage]
    defcode "C+!",,ADDBYTESTORE,_addstorebyte

    @   6.1.0870    C@ ( c-addr —- b ) [core]
    defcode "C@",,FETCHBYTE,_fetchbyte


@
@   2.1.3 Return Stack Manipulation Operations (FPH, p36)
@

    @   6.2.0340    2>R ( x1 x2 —- ) ( R: —- x1 x2 ) [core ext]
    defcode "2>R",,TWOTOR,_twotor

    @   6.2.0410    2R> ( —- x1 x2 ) ( R: x1 x2 —- ) [core ext]
    defcode "2R>",,TWOFROMR,_twofromr

    @   6.2.0415    2R@ ( —- x1 x2 ) ( R: x1 x2 —- x1 x2 ) [core ext]
    defcode "2R@",,TWORSPFETCH,_tworspfetch

    @   6.1.0580    >R ( x -— ) ( R: —- x ) [core]
    defcode ">R",,TOR,_tor

    @   6.1.2060    R> ( —- x ) ( R: x —- ) [core]
    defcode "R>",,FROMR,_fromr

    @   6.1.2070    R@ ( —- x ) ( R: x —- x ) [core]
    defcode "R@",,RSPFETCH,_rspfetch


@
@   2.1.4 Programmer Conveniences (FPH, p37)
@

    @   15.6.1.0220 .S ( —- ) [tools]
    defcode ".S",,DOT_S,_dot_s

    @   15.6.1.0600 ? ( a-addr —- ) [tools]  
    defword "?",,QUESTION               @ : ? ( addr -- ) @ . ;
    .word FETCH                         @ fetch the value at addr
    .word DOT
    .word EXIT

    @   6.1.1345    ENVIRONMENT? ( c-addr u -— false | i*x true ) [core]
    defcode "ENVIRONMENT?",,ENVIRONMENTQ,_environmentq

    @   15.6.1.1280 DUMP ( addr +n —- ) [tools]
    defcode "DUMP",,DUMP,_dump

    @   15.6.1.2465 WORDS ( -— ) [tools]
    defcode "WORDS",,WORDS,_words

@
@   2.2.1 Arithmetic and Shift Operators (FPH, p39)
@

    @
    @   Single-Precision Operations
    @

    @   6.1.0090    * ( n1 n2 —- n3 ) [core]
    defcode "*",,MUL,_mul

    @   6.1.0100    */ ( n1 n2 n3 —- n4 ) [core]
    defword "*/",,MUL_DIV
    .word NROT, MUL, SWAP, DIVIDE
    .word EXIT

    @   6.1.0110    */MOD ( n1 n2 n3 —- n4 n5 ) [core]
    defword "*/MOD",,MUL_DIVMOD
    .word NROT, MUL, SWAP, DIVMOD
    .word EXIT

    @   6.1.0120    + ( n1 n2 —- n3 ) [core]
    defcode "+",,ADD,_add

    @   6.1.0160    - ( n1 n2 —- n3 ) [core]
    defcode "-",,SUB,_sub


    @   6.1.0230    / ( n1 n2 —- n3 ) “slash” [core]
    @
    @   Divide n1 by n2, giving the single-cell quotient n3. An ambiguous condition exists if n2 is zero.
    @   If n1 and n2 differ in sign, the implementation-defined result returned will be the same as that
    @   returned by either the phrase >R S>D R> FM/MOD SWAP DROP or the phrase >R S>D R>
    @   SM/REM SWAP DROP.

    defword "/",,DIVIDE
    .word DIVMOD
    .word SWAP
    .word DROP
    .word EXIT


    @   6.1.0240    /MOD ( n1 n2 —- n3 n4 ) [core]
    defcode "/MOD",,DIVMOD,_slash_mod

    @   6.1.0290    1+ ( n1 —- n2 ) [core]
    defcode "1+",,INCR,_incr

    @   6.1.0300    1- ( n1 —- n2 ) [core]
    defcode "1-",,DECR,_decr

    @               2+ ( n1 —- n2 ) [common usage]
    defcode "2+",,INCR2,_incr2

    @               2- ( n1 —- n2 ) [common usage]
    defcode "2-",,DECR2,_decr2

    @   6.1.0320    2* ( x1 —- x2 ) [core]
    defcode "2*",,TWOMUL,_twomul

    @   6.1.0330    2/ ( x1 —- x2 ) [core]
    defcode "2/",,TWODIV,_twodiv

    @               4+ ( n1 —- n2 ) [common usage]
    defcode "4+",,INCR4,_incr4

    @               4- ( n1 —- n2 ) [common usage]
    defcode "4-",,DECR4,_decr4

    @   6.1.0880    CELL+ ( a-addr1 —- a-addr2 ) [core]
    defcode "CELL+",,CELL_INCR,_cell_incr

    @   6.1.0890    CELLS ( n1 —- n2 ) [core]
    defcode "CELLS",,CELLS,_cells

    @   6.1.0897    CHAR+ ( c-addr1 —- c-addr2 ) [core]
    defcode "CHAR+",,CHAR_INCR,_char_incr

    @   6.1.0898    CHARS ( n1 —- n2 ) [core]
    defcode "CHARS",,CHARS,_noop        @ Does nothing

    @   6.1.1805    LSHIFT ( x1 u —- x2 ) [core]
    defcode "LSHIFT",,LSHIFT,_lshift

    @   6.1.1890    MOD ( n1 n2 —- n3 ) [core]
    defword "MOD",,MOD
    .word DIVMOD
    .word DROP
    .word EXIT

    @   6.1.2162    RSHIFT ( x1 u —- x2 ) [core]
    defcode "RSHIFT",,RSHIFT,_rshift

    @               U/MOD ( n1 n2 —- n3 ) [common usage]
    defcode "U/MOD",,UDIVMOD,_udivmod


    @
    @   Double-precision Operations
    @

    @   8.6.1.1040  D+ ( d1 d2 -— d3 ) [double]
    defcode "D+",,DADD,_dadd

    @   8.6.1.1050  D- ( d1 d2 -— d3 ) [double]
    defcode "D-",,DSUB,_dsub

    @   8.6.1.1090  D2* ( xd1 -— xd2 ) [double]
    @   TODO

    @   8.6.1.1100  D2/ ( xd1 -— xd2 ) [double]
    @   TODO


    @
    @   Mixed-precision Operations
    @

    @   8.6.1.1140  D>S ( d -— n ) [double]
    @   TODO

    @   6.1.1561    FM/MOD ( d n1 —- n2 n3 ) [core]
    @   TODO

    @   6.1.1810    M* ( n1 n2 —- d ) [core]
    @   TODO

    @   8.6.1.1820  M*/ ( d1 n1 +n2 —- d2 ) [double]
    @   TODO

    @   8.6.1.1830  M+ ( d1 n —- d2 ) [double]
    @   TODO

    @               M- ( d1 n —- d2 ) [commom usage]
    @   TODO

    @               M/ ( d1 n —- d2 ) [common usage]
    @   TODO

    @   6.1.2170    S>D ( n —- d ) [core]
    @   TODO

    @   6.1.2214    SM/REM ( d n1 —- n2 n3 ) [core]
    @   TODO

    @               T* ( d n —- t ) [core]
    @   TODO

    @               T/ ( t +n —- d ) [core]
    @   TODO

    @   6.1.2360   UM* ( u1 u2 -— ud ) [core]
    @   TODO

    @   6.1.2370    UM/MOD ( ud u1 —- u2 u3 ) [core]
    @   TODO


@
@   2.2.2 Logical and Relational Operations (FPH, p44)
@

    @
    @   Single-Precision Logical Operations
    @

    @   6.1.0690    ABS ( n -— +n ) [core]
    defcode "ABS",,ABS,_abs

    @   6.1.0720    AND ( x1 x2 —- x3 ) [core]
    defcode "AND",,AND,_and

    @   6.1.1720    INVERT ( x1 —- x2 ) [core]
    defcode "INVERT",,INVERT,_invert    @ this is the FORTH bitwise "NOT" function (cf. NEGATE and NOT)

    @   6.1.1870    MAX ( n1 n2 —- n3 ) [core]
    defcode "MAX",,MAX,_max

    @   6.1.1880    MIN ( n1 n2 —- n3 ) [core]
    defcode "MIN",,MIN,_min

    @   6.1.1910    NEGATE ( n1 —- n2 ) [core]
    defcode "NEGATE",,NEGATE,_negate

    @   6.1.1980    OR ( x1 x2 —- x3 ) [core]
    defcode "OR",,OR,_or

    @   6.2.2440    WITHIN ( test low high -- flag ) [core]
    defcode "WITHIN",,WITHIN,_within

    @   6.1.2490    XOR ( x1 x2 —- x3 ) [core]
    defcode "XOR",,XOR,_xor

    @
    @   Double-Precision Logical Operations
    @

    @   8.6.1.1160  DABS ( d —- +d ) [double]
    @   TODO

    @   8.6.1.1210  DMAX ( d1 d2 —- d3 ) [double]
    @   TODO

    @   8.6.1.1220  DMIN ( d1 d2 —- d3 ) [double]
    @   TODO

    @   8.6.1.1230  DNEGATE ( d —- -d ) [double]
    @   TODO

@
@   2.2.3 Comparison and Testing Operations
@

    @   6.1.0250    0< ( n -— flag ) [core]
    defcode "0<",,ZLT,_zlt

    @   6.2.0260    0<> ( n —- flag ) [core ext]
    defcode "0<>",,ZNEQU,_znequ

    @   6.1.0270    0= ( n -— flag ) [core]
    defcode "0=",,ZEQU,_zequ

    @   6.2.0280    0> ( n -— flag ) [core ext]
    defcode "0>",,ZGT,_zgt

    @   6.1.0480    < ( n1 n2 —- flag )  [core]
    defcode "<",,LT,_lt

    @   6.2.0500    <> ( n1 n2 —- flag ) [core]
    defcode "<>",,NEQU,_nequ

    @   6.1.0530    = ( n1 n2 —- flag ) [core]
    defcode "=",,EQU,_equ

    @   6.1.0540    > ( n1 n2 —- flag ) [core]
    defcode ">",,GT,_gt

    @   8.6.1.1075  D0< ( d -— flag ) [double]
    @   TODO

    @   8.6.1.1080  D0= ( d -— flag ) [double]
    @   TODO
    
    @   8.6.1.1110  D< ( d1 d2 -— flag ) [double]
    @   TODO
    
    @   8.6.1.1120  D= ( d1 d2 -— flag ) [double]
    @   TODO
    
    @   8.6.2.1270  DU< ( ud1 ud2 -— flag ) [double ext]
    @   TODO

    @   6.2.1485    FALSE ( —- flag ) [core ext]
    defcode "FALSE",,FALSE,_false

    @               NOT ( x —- flag ) [common usage]
    defcode "NOT",,NOT,_zequ            @ identical to 0=, but more readable

    @   6.2.2298    TRUE ( —- flag ) [core ext]
    defcode "TRUE",,TRUE,_true

    @   6.1.2340    U< ( u1 u2 —- flag ) [core]
    defcode "U<",,ULT,_ult

    @   6.2.2350    U> ( u1 u2 —- flag ) [core]
    defcode "U>",,UGT,_ugt


@
@   2.3.1 The PAD—Scratch Storage for Strings
@

    @   6.1.1650    HERE ( -— addr ) [core]
    defcode "HERE",,HERE,_here

    @   6.2.2000    PAD ( -— addr ) [core ext]
    defcode "PAD",,PAD,_pad


@
@   2.3.2.2 Constants and Values
@

    @   6.1.0950    CONSTANT ( x “<spaces>name” -- ) [core]
    defword "CONSTANT",,CONSTANT
    .word CREATE, COMMA, DOES
    .word JUMP_TO, _paren_does
    .word FETCH
    .word EXIT

    @   6.1.0960    VALUE ( x “<spaces>name” -- ) [core]
    defword "VALUE",,VALUE
    .word CREATE, COMMA, DOES
    .word JUMP_TO, _paren_does
    .word FETCH
    .word EXIT

    @   6.1.0970    VARIABLE ( —- ) [core]
    defword "VARIABLE",,VARIABLE
    .word CREATE, LITERAL, 1, CELLS, ALLOT
    .word EXIT


@
@   2.3.3 String Management Operations
@

    @   17.6.1.0170 -TRAILING ( c-addr u1 -— c-addr u2 ) [string]
    @   TODO

    @   17.6.1.0245 /STRING ( c-addr1 u1 +n -— c-addr2 u2 ) [string]
    @   TODO

    @   17.6.1.0780 BLANK ( c-addr u -— ) [string]
    defcode "BLANK",,BLANK,_blank

    @   6.2.1350    ERASE ( c-addr u -— ) [core ext]
    defcode "ERASE",,ERASE,_erase

    @   6.1.1540    FILL ( c-addr u b —- ) [core]
    defcode "FILL",,FILL,_fill

    @   6.2.2295    TO ( x -- ) [core ext]
    defcode "TO",,TO,_to

    @   17.6.1.0910 CMOVE ( c-addr1 c-addr2 u -— ) [string]
    @   TODO

    @   17.6.1.0920 CMOVE> ( c-addr1 c-addr2 u -— ) [string]
    @   TODO

@
@   2.3.4 Comparing Character Strings
@

    @   17.6.1.0935 COMPARE ( c-addr1 u1 c-addr2 u2 -— n ) [string]
    @   TODO

    @   17.6.1.2191 SEARCH ( c-addr1 u1 c-addr2 u2 -— c-addr3 u3 flag ) [string]
    @   TODO



@
@   2.4.1 Standard Numeric Output Words
@

    @   6.1.0180    . ( n —- ) [core]
    defcode ".",,DOT,_dot

    @   6.2.0210    .R ( n1 +n2 —- ) [core ext]
    defcode ".R",,DOT_R,_dot_r

    @   8.6.1.1060  D. ( d -— ) [double]
    @   TODO

    @   8.6.1.1070  D.R ( d +n -— ) [double]
    @   TODO

    @   6.1.2320    U. ( u -— ) [core]
    defcode "U.",,U_DOT,_u_dot

    @   6.2.2330    U.R ( u +n -— ) [core ext]
    defcode "U.R",,U_DOT_R,_u_dot_r

@
@   2.4.2 Pictured Number Conversion
@

    @   6.1.0490    <# ( ud —- ud ) or ( n ud -— n ud )  [core]
    @   TODO

    @   6.1.0030    # ( ud1 —- ud2 ) [core]
    @   TODO

    @   6.1.0050    #S ( ud1 —- ud2 ) [core]
    @   TODO

    @   6.1.2210    SIGN ( n —- ) [core]
    @   TODO

    @   6.1.0040    #> ( ud —- c-addr u ) [core]
    @   TODO

@
@   2.4.2.2 Using Pictured Fill Characters
@

    @   6.1.0895    CHAR ( —- char ) [core]
    defcode "CHAR",,CHAR,_char

    @   6.1.1670    HOLD ( char —- ) [core]
    @   TODO

    @   6.1.2520    [CHAR] ( —- char ) [core]
    defword "[CHAR]",CB_PRECEDENCE,CHAR_LITERAL
    .word CHAR
    .word BRACKET_TICK, LITERAL, COMMA
    .word COMMA
    .word EXIT


@
@   2.5.1 Indefinite Loops
@

    @   6.2.0700    AGAIN ( —- ) [core ext]
    defword "AGAIN",CB_PRECEDENCE,AGAIN
    .word BRACKET_TICK, BRANCH, COMMA   @ compile branch
    .word HERE, SUB                     @ calculate the offset back
    .word COMMA                         @ compile the offset here
    .word EXIT

    @   6.1.0760    BEGIN ( —- ) [core]
    defword "BEGIN",CB_PRECEDENCE,BEGIN
    .word HERE                          @ save location on the stack
    .word EXIT

    @   6.1.2140    REPEAT ( —- ) [core]
    defword "REPEAT",CB_PRECEDENCE,REPEAT
    .word BRACKET_TICK, BRANCH, COMMA   @ compile branch
    .word HERE, SUB, COMMA              @ and compile it after branch
    .word DUP
    .word HERE, SWAP, SUB               @ calculate the offset2
    .word SWAP, STORE                   @ and back-fill it in the original location
    .word EXIT

    @   6.1.2390    UNTIL ( x —- ) [core]
    defword "UNTIL",CB_PRECEDENCE,UNTIL
    .word BRACKET_TICK, ZBRANCH, COMMA  @ compile 0branch
    .word HERE, SUB                     @  calculate the offset from the address saved on the stack
    .word COMMA                         @ compile the offset here
    .word EXIT

    @   6.1.2430    WHILE ( x —- ) [core]
    defword "WHILE",CB_PRECEDENCE,WHILE
    .word BRACKET_TICK, ZBRANCH, COMMA  @ compile 0branch
    .word HERE                          @ save location of the offset2 on the stack
    .word SWAP                          @ get the original offset (from begin)
    .word LITERAL, 0, COMMA                 @ compile a dummy offset2
    .word EXIT

@
@   2.5.2 Counting (Finite) Loops
@

    @   6.1.1240    DO ( n1 n2 —- ) [core]
    @   TODO

    @   6.2.0620    ?DO ( n1 n2 —- ) [core ext]
    @   TODO

    @   6.1.1800    LOOP ( —- ) [core]
    @   TODO

    @   6.1.0140    +LOOP ( n1 n2 —- ) [core]
    @   TODO

    @   6.1.1680    I ( —- n ) [core]
    @   TODO

    @   6.1.1730    J ( —- n ) [core]
    @   TODO

    @   6.1.1760    LEAVE ( —- ) [core]
    @   TODO

    @   6.1.2380    UNLOOP ( —- ) [core]
    @   TODO

@
@   2.5.3 Conditionals
@

    @   6.1.1310    ELSE ( —- ) [core]
    defword "ELSE",CB_PRECEDENCE,ELSE
    .word BRACKET_TICK, BRANCH, COMMA   @ definite branch to just over the false-part
    .word HERE                          @ save location of the offset on the stack
    .word LITERAL, 0, COMMA                 @ compile a dummy offset
    .word SWAP                          @ now back-fill the original (if) offset
    .word DUP                           @ same as for then word above
    .word HERE, SWAP, SUB
    .word SWAP, STORE
    .word EXIT

    @   6.1.1700    IF ( x —- ) [core]
    defword "IF",CB_PRECEDENCE,IF
    .word BRACKET_TICK, ZBRANCH, COMMA  @ compile 0branch
    .word HERE                          @ save location of the offset on the stack
    .word LITERAL, 0, COMMA                 @ compile a dummy offset
    .word EXIT

    @   6.1.2270    THEN ( —- ) [core]
    defword "THEN",CB_PRECEDENCE,THEN
    .word DUP
    .word HERE, SWAP, SUB               @ calculate the offset from the address saved on the stack
    .word SWAP, STORE                   @ store the offset in the back-filled location
    .word EXIT

@
@   2.5.4 CASE Statement
@

    @   6.2.0873    CASE ( —- ) [core]
    defword "CASE",CB_PRECEDENCE,CASE
    .word LITERAL, 0
    .word EXIT

    @   6.2.1342    ENDCASE ( —- ) [core]
    defword "ENDCASE",CB_PRECEDENCE,ENDCASE
    .word BRACKET_TICK, DROP, COMMA
    .word QDUP, ZBRANCH, 16
    .word THEN, BRANCH, -20
    .word EXIT

    @   6.2.1343    ENDOF ( —- ) [core]
    defword "ENDOF",CB_PRECEDENCE,ENDOF
    .word ELSE
    .word EXIT

    @   6.2.1950    OF ( x —- ) [core]
    defword "OF",CB_PRECEDENCE,OF
    .word BRACKET_TICK, OVER, COMMA
    .word BRACKET_TICK, EQU, COMMA
    .word IF
    .word BRACKET_TICK, DROP, COMMA
    .word EXIT

@
@   2.5.5 Un-nesting Definitions
@

    @   6.1.1380    EXIT ( -— ); ( R: nest-sys — ) [core]
    defcode "EXIT",,EXIT,_exit
 
@
@   2.5.6 Vectored Execution
@

    @               DEFER <name> ( -— ) [commmon usage]
    @   TODO

    @   6.1.1370    EXECUTE ( i*x xt -— j*x ) [core]
    defcode "EXECUTE",,EXECUTE,_execute

    @               IS <name> ( xt -— ) [common usage]
    @   TODO


@
@   2.6 EXCEPTION HANDLING
@

    @   9.6.2.0670  ABORT ( -- ) [core]
    defword "ABORT",,abort
    .word LITERAL, -1
    .word THROW
    .word EXIT

    @   9.6.2.0680  ABORT" ( i*x flag -— ); ( R: j*x -— ) [core]
    defword "ABORT\"",,abort_quote  @"
    .word LITERAL, '"'
    .word PARSE
    .word ROT, ZBRANCH, 16
    .word LITERAL, -2
    .word THROW
    .word THEN
    .word EXIT

    @   9.6.1.0875  CATCH ( i*x xt -- j*x 0 | i*x n ) [exception]
    defcode "CATCH",,CATCH,_catch

    @   9.6.1.2275  THROW ( k*x n -- k*x | i*x n ) [exception]
    defcode "THROW",,THROW,_throw


@
@    3.3.1 Terminal Input
@

    @   6.1.0695    ACCEPT ( c-addr +n1 —- +n2 ) [core]
    defcode "ACCEPT",,ACCEPT,_accept

    @   10.6.2.1305 EKEY ( —- u ) [facility ext]
    defcode "EKEY",,EKEY,_key

    @   10.6.2.1306 EKEY>CHAR ( u —- u 0 | char -1 ) [facility ext
    defcode "EKEY>CHAR",,EKEY_TO_CHAR,_key_to_char

    @   10.6.2.1307 EKEY? ( —- flag ) [facility ext]
    defcode "EKEY?",,EKEYQ,_keyq

    @   6.1.1750    KEY ( —- b ) [core]
    defcode "KEY",,KEY,_key

    @   10.6.1.1755 KEY? ( —- flag ) [facility]
    defcode "KEY?",,KEYQ,_keyq


@
@   3.3.2 Terminal Output
@

    @   6.1.1320    EMIT ( b —- ) [core]
    defcode "EMIT",,EMIT,_emit

    @   10.6.2.1325 EMIT? ( -— flag ) [facility ext]
    defcode "EMIT?",,EMITQ,_emitq

    @   6.1.2310    TYPE ( c-addr u —- ) [core]
    defcode "TYPE",,TYPE,_type

@
@   3.3.3 Support of Special Terminal Features
@

    @   10.6.1.0742 AT-XY ( u1 u2 -- ) [facility]
    defcode "AT-XY",,AT_XY,_at_xy

    @   6.1.0990    CR ( —- ) [core]
    defcode "CR",,CR,_cr

    @   10.6.1.2005 PAGE ( —- ) [facility]
    defcode "PAGE",,PAGE,_page

    @   6.1.2220    SPACE ( —- ) [core]
    defcode "SPACE",,SPACE,_space

    @   6.1.2230    SPACES ( u —- ) [core]
    defcode "SPACES",,SPACES,_spaces


@
@   4.1.1 Input Sources
@

    @   7.6.1.0790  BLK ( -— a-addr ) [block]
    defvar "BLK",BLK,0

    @   6.2.2218    SOURCE-ID ( -— n ) [core ext, file]
    defvar "SOURCE_ID",SOURCE_ID,0

@
@   4.1.2 Source Selection and Parsing
@

    @   6.2.0060    #TIB ( -- a-addr ) [core ext]
    @defvar "#TIB",TIB_SIZE,TERMINAL_INPUT_BUFFER_SIZE

    @   6.1.0560    >IN ( —- a-addr ) [core]
    defvar ">IN",TOIN,0

    @   6.1.1360    EVALUATE ( i*x c-addr u —- j*x ) [core, block]
    defcode "EVALUATE",,EVALUATE,_evaluate

    @               INTERPRET ( i*x —- j*x ) [core]
    defcode "INTERPRET",,INTERPRET,_interpret

    @   6.2.2008    PARSE ( char —- c-addr u ) [core ext]
    defcode "PARSE",,PARSE,_parse

    @   (6.2.2008)  PARSE-WORD ( “<spaces>name” -- c-addr u ) [core ext]
    defcode "PARSE-WORD",,PARSE_WORD,_parse_word

    @   6.1.2050    QUIT ( i*x —- ); ( R: j*x —- ) [core]
    defcode "QUIT",,QUIT,_quit

    @   6.2.2125    REFILL ( —- flag ) [core]
    defcode "REFILL",,REFILL,_refill

    @   6.2.2148    RESTORE-INPUT ( xn … x1 n -— flag ) [core ext]
    defcode "RESTORE-INPUT",,RESTORE_INPUT,_restore_input

    @   6.2.2182    SAVE-INPUT ( -— xn … x1 n ) [core ext]
    defcode "SAVE-INPUT",,SAVE_INPUT,_save_input

    @   6.1.2216    SOURCE ( -- c-addr u ) [core]
    defcode "SOURCE",,SOURCE,_source

    @   6.2.2290    TIB ( -- c-addr ) [core ext]
    defcode "TIB",,TIB,_tib


@
@   4.1.3 Dictionary Searches
@

    @   6.1.0070    ' <name> ( —- xt ) [core]
    defcode "'",,TICK,_tick

    @   6.1.2510    ['] <name> ( —- ) [core]
    defcode "[']",CB_PRECEDENCE,BRACKET_TICK,_bracket_tick

    @   6.1.0550    >BODY ( xt —- a-addr ) [core]
    defcode ">BODY",,TO_BODY,_noop

    @   6.1.1550    FIND ( c-addr —- c-addr 0 | xt 1 | xt -1 ) [core]
    defcode "FIND",,FIND,_find

@
@   6.1.5 Text Interpreter Conditionals
@

    @               [DEFINED] <name> ( —- flag ) [common usage]
    defcode "[DEFINED]",CB_PRECEDENCE,BRACKET_DEFINED,_bracket_defined

    @               [UNDEFINED] <name> ( —- flag ) [common usage]
    defcode "[UNDEFINED]",CB_PRECEDENCE,BRACKET_UNDEFINED,_bracket_undefined

    @   6.1.0200    [IF] ( —- ) [core]
    defcode "[IF]",CB_PRECEDENCE,BRACKET_IF,_bracket_if

    @   6.1.0210    [ELSE] ( —- ) [core]
    defcode "[ELSE]",CB_PRECEDENCE,BRACKET_ELSE,_bracket_else

    @   6.1.0220    [THEN] ( —- ) [core]
    defcode "[THEN]",CB_PRECEDENCE,BRACKET_THEN,_noop

@
@   6.2.2 Colon Definitions
@

    @   6.1.0450    : <name> ( —- ) [core]
    defcode ":",CB_PRECEDENCE,COLON,_colon

    @   6.2.0455    :NONAME ( -- xt ) [core ext]
    defcode ":NONAME",CB_PRECEDENCE,COLON_NONAME,_colon_noname

    @   6.1.0460    ; ( —- ) [core]
    defcode ";",CB_PRECEDENCE,SEMICOLON,_semicolon

    @   6.1.2120    RECURSE ( -- ) [core]
    defcode "RECURSE",CB_PRECEDENCE,RECURSE,_recurse

@
@   4.1.4 Input Number Conversion
@

    @   6.1.0570    >NUMBER ( ud1 c-addr1 u1 —- ud2 c-addr2 u2 ) [core]
    @   TODO



@
@   4.1.5.1 Scanning Characters to a Delimiter
@

    @   6.1.0770    BL ( -— char ) [core]
    defcode "BL",,BL,_bl

    @   6.1.0980    COUNT ( c-addr1 -— c-addr2 n ) [core]
    defcode "COUNT",,COUNT,_count

    @   6.1.2450    WORD <text> ( char -— c-addr ) [core]
    defcode "WORD",,WORD,_word

@
@   4.1.5.2 Compiling and Interpreting Strings
@

    @   6.1.2165    S" <string>" ( —- c-addr u ) [core]
    defcode "S\"",CB_PRECEDENCE,S_QUOTE,_s_quote @"

    @   6.2.0855    C" <string>" ( -— c-addr ) [core ext]
    @   TODO

    @   6.1.0190    ." <string>" ( -— ) [core]
    defcode ".\"",CB_PRECEDENCE,DOT_QUOTE,_dot_quote @"


@
@   4.2.1 Creating a Dictionary Entry
@

    @   6.1.0710    ALLOT ( n —- ) [core]
    defcode "ALLOT",,ALLOT,_allot

    @   6.1.0725    CREATE ( —- a-addr ) [core]
    defcode "CREATE",,CREATE,_create

    @   6.2.2395    UNUSED ( —- u ) [core ext]
    defcode "UNUSED",,UNUSED,_unused

@
@   4.3.2 Use of , and C, to Compile Values
@

    @   6.1.0150    , ( x —- ) [core]
    defcode ",",,COMMA,_comma

    @   6.1.0705    ALIGN ( —- ) [core]
    defword "ALIGN",,ALIGN
    .word HERE
    .word ALIGNED
    .word DP
    .word STORE
    .word EXIT

    @   6.1.0706    ALIGNED ( addr —- a-addr ) [core]
    defword "ALIGNED",,ALIGNED
    .word LITERAL, 3, ADD
    .word LITERAL, 3, INVERT
    .word AND
    .word EXIT

    @               BUFFER: ( n -- ) [common usage]
    defword "BUFFER:",,BUFFER_COLON
    .word CREATE, ALLOT
    .WORD EXIT

    @   6.1.0860    C, ( char —- ) [core]
    defcode "C,",,C_COMMA,_c_comma


@
@   4.3.3 The Forth Compiler
@

    @   6.2.2530    [COMPILE] ( “<spaces>name” -- ) [core ext]
    @ defword "[COMPILE]",CB_PRECEDENCE,BRACKET_COMPILE
    @ .word WORD                          @ get the next word
    @ .word PAREN_FIND                    @ find it in the dictionary
    @ .word TCFA                          @ get its code field 
    @ .word COMMA                         @ and compile that
    @ .word EXIT

    @   6.1.2250    STATE ( —- a-addr ) [core]
    defvar "STATE",STATE,0

    @   6.1.2500    [ ( -— ) [core]
    defcode "[",CB_PRECEDENCE,LBRAC,_lbrac

    @   6.1.2540    ] ( —- ) [core]
    defcode "]",CB_PRECEDENCE,RBRAC,_rbrac

@
@   4.3.5 Explicit Literals
@

    @   6.1.1780    LITERAL ( -— x ) [core]
    defcode "LITERAL",CB_PRECEDENCE,LITERAL,_literal

    @   8.6.1.0390  2LITERAL ( -— x1 x2 ) [double]
    defcode "2LITERAL",CB_PRECEDENCE,TWO_LITERAL,_two_literal


@
@   4.3.7 Compiling Strings
@

    @   17.6.1.2212 SLITERAL ( -— c-addr u ) [string]
    defcode "SLITERAL",CB_PRECEDENCE,S_LITERAL,_s_literal

@
@   4.6.2 Managing Word Lists
@

    @   16.6.2.1590 FORTH ( -- ) [search ext]
    defcode "FORTH",,FORTH,_noop        @ Ignore this, for now


@
@   6.2.4.2 Constructing Custom Defining Words
@

    @ 6.1.1250      DOES> ( xt —- ) [core]
    defcode "DOES>",CB_PRECEDENCE,DOES,_does

@
@   6.3.1 The Forth Compiler
@

    @   6.2.0945    COMPILE, ( xt -- ) [core ext]
    defcode "COMPILE,",CB_PRECEDENCE,COMPILE_COMMA,_comma

@
@   Internal
@

    defcode "BRANCH",,BRANCH, _branch

    defcode "0BRANCH",,ZBRANCH, _zbranch

    defcode "BATTERY",,BATTERY,_battery

    defcode "BOOTSEL",,BOOTSEL,_bootsel

    @   DOCOL [core]
    @defconst "DOCOL",DOCOL,_docol

    @   R0                              The address of the top of the return stack.
    defconst "R0",RZ,return_stack_top

    @   S0                              Stores the address of the top of the data stack.
    defconst "S0",SZ,data_stack_top

    @   DP                              The dictionary pointer, which points to the current position in the data space.
    defvar "DP",DP,data_space

    @   LATEST                          Points to the latest (most recently defined) word in the dictionary.
    defvar "LATEST",LATEST,link