\ Project Euler 2

\ variable to hold the sum
VARIABLE SUM

: EVEN ( n -- T|F )
  \ is n even?
  DUP 2 MOD 0 = ;

: FIB ( n n -- )
  \ calculate fibonacci sequence
  BEGIN
    EVEN IF
      \ if tos is even add it to the sum
      DUP SUM +!
    THEN
    \ dup the 2 numbers on the stack, add them
    2DUP +
    \ keep the top two for the next round, drop the third
    ROT DROP

    \ continue until tos is more than 4 million
    DUP 4000000 SWAP <
  UNTIL DROP DROP ;

: EULER2 ( -- )
  \ calculate the sum of all even fibonacci numbers under 4 million
  1 1 FIB SUM @ . ;

EULER2
