\ Project Euler 1

\ variable to hold the sum
VARIABLE SUM

: 0= ( n -- T|F )
  0 = ;

: NMOD ( n m -- T|F )
  OVER SWAP MOD 0= ;

: ACC ( n -- n )
  DUP SUM +! ;

: MOD35 ( n -- )
  3 NMOD IF
    ACC
  ELSE
    5 NMOD IF
      ACC
    THEN
  THEN ;

: COUNTDOWN ( n -- )
  FOR R@ MOD35 DROP NEXT ;

: EULER1 ( -- )
  \ sum all mod 3/5 numbers under 1000
  999 COUNTDOWN

  \ display sum
  SUM @ . ;

EULER1
