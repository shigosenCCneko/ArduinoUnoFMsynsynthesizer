
/*
   FM output PWM

*/
#include <avr/io.h>
#include <avr/interrupt.h>
#include "fmtone_def.h"

.extern fm_operator
.extern wave_tbl


//#define USE_DAC
#define TABLE_SIZE_MASK 0x3f
#define MAX_LEVEL  31


/* offset from struct head */
#define FB        0
#define FBVAL     1

#define ATK   2
#define DECY  3
#define SUL   4
#define SUS   5
#define REL   6

#define VOL   7
#define MUL   8
#define WAVE_TBLL 9
#define WAVE_TBLH 10


#define SIN_POSL 11
#define SIN_POSH 12
#define SIN_STEPL 13
#define SIN_STEPH 14

#define ENV_STATE 15
#define ENV_CNT   16
#define  ENV_STEP 17
#define LEVEL 18

#define SIZEOF_FMOPERATOR 19

#define F_ATK  1
#define F_DECY 2
#define F_SUS  3
#define F_REL  4

#define TOTAL_OUT r18
#define CHANNEL_OUT r19
#define ZERO r21

.section .data
wait_cnt: .dc.b  0        //エンベロープのウェイト用カウンタ

.section .bss
.global fm_operator
//.balign 256
fm_operator:  .ds.b  ( MAX_MIDITONE * 2 * SIZEOF_FMOPERATOR )


.section .text

.global TIMER1_COMPA_vect
TIMER1_COMPA_vect:
.func
  cli
  push r0
  push r1
  in r0, _SFR_IO_ADDR(SREG)
  push r0
  push XL
  push XH
  push YL
  push YH
  push ZL
  push ZH
  push r16
  push r17
  push TOTAL_OUT
  push CHANNEL_OUT
  push r20
  push r21
  clr r21



#ifdef USE_DAC
  cbi 0x03, 0x02
  ldi ZL, 0x36
  out _SFR_IO_ADDR(SPDR), ZL 
#endif


  ldi XL, MAX_MIDITONE - 1     ; loop conter
  clr TOTAL_OUT


  lds r20, wait_cnt
  inc r20
  andi r20, 0x07 //8回に1回 subi 32 と同じ
  sts wait_cnt, r20
  //
  ldi YL, lo8(fm_operator)
  ldi YH, hi8(fm_operator)

loop:

  ldd ZL, Y + SIN_POSH   //Zレジスタを逆に使い　読み出しポインタ加算
  ldd ZH, Y + SIN_POSL
  ldd r16, Y + SIN_STEPH
  ldd r17, Y + SIN_STEPL
  add ZH, r17
  adc ZL, r16
  
  std Y + SIN_POSH, ZL
  std Y + SIN_POSL, ZH

  ldd r17,Y + FBVAL
  add ZL,r17
  andi ZL,TABLE_SIZE_MASK
  
//  clr ZH                  //Read sin table from tone pointer
//  
//  ldd r16, Y + WAVE_TBLL
//  ldd r17, Y + WAVE_TBLH
//  add ZL, r16
//  adc ZH, r17
    ldd r16, Y + WAVE_TBLL
    ldd ZH, Y + WAVE_TBLH
    add ZL,r16
//    adc ZH,ZERO       //波形テーブルを　.balign 64にしたので桁上げしない

  lpm CHANNEL_OUT, Z        //波形をPROGMEMで置いている場合

//------- envelope   --- r16  level  r17 env_cnt  ----------------------


  ldd r16,Y + LEVEL
   cp r20,XL
   brne ENV_LEVEL
  
DO_ENVCHG:

  ldd r17,Y + ENV_CNT
  ldd XH,Y + ENV_STEP
  sub r17,XH
  brcc ENV_LEVEL_WITHSAVE

DO_ENVSTEP:
  
  ldd XH,Y + ENV_STATE
  ldi r17,250
  
  cpi XH, F_ATK
  breq ATK_FASE

  cpi XH, F_DECY
  breq DECY_FASE

  cpi XH,F_SUS
  breq SUS_FASE
  
  
REL_FASE:
  std Y+ENV_CNT,r17
  cpi r16,(0)
  breq STOP_TONE
  dec r16
  std Y+LEVEL,r16
  rjmp ENV_LEVEL

 DECY_FASE:
  std Y+ENV_CNT,r17
  dec r16
  std Y+LEVEL,r16
  ldd XH,Y+SUL   //compare sustain level
  cp r16,XH
  brne ENV_LEVEL
  ldi r17,F_SUS         //set sustain fase
  std Y+ENV_STATE,r17
  ldd XH,Y + SUS
  std Y + ENV_STEP,XH
  rjmp ENV_LEVEL

SUS_FASE:
  std Y+ENV_CNT,r17
  cpi r16,(0)
  breq STOP_TONE 
  dec r16
  std Y+LEVEL,r16
  rjmp ENV_LEVEL 

STOP_TONE:

  std Y+SIN_STEPL,ZERO
  std Y+SIN_STEPH,ZERO 
  rjmp ENV_LEVEL


ATK_FASE:
  inc r16
  std Y+LEVEL,r16
  cpi r16,(MAX_LEVEL)
  brne ENV_LEVEL_WITHSAVE
 ldi r16,F_DECY       // set decay fase
  std Y+ENV_STATE,r16
  ldd XH,Y + DECY
  std Y + ENV_STEP,XH
ENV_LEVEL_WITHSAVE:
  std Y+ENV_CNT,r17  //処理をパスしてきた時のsaveと共用する

ENV_LEVEL:
/*
   subi CHANNEL_OUT,(-31);
  ldi ZL,64
  mul r16,ZL
  movw ZL,r0
  //clr r0
  add ZL,CHANNEL_OUT
  //adc ZH,r0
  subi ZL,lo8(-(conv_vol))
  sbci ZH,hi8(-(conv_vol))
  lpm CHANNEL_OUT,Z

  上の素直なコードをaとbに対し２回行っていたものを

     (a * b )/31 を
     (( (a +1 )<<2 )*( (b + 1) <<1 ) >> 8) -1 で代用
*/
//
//ldd XH,Y + VOL
//inc r16
//lsl r16
//lsl r16
//inc XH
//lsl XH
//mul r16,XH
//dec r1
//subi CHANNEL_OUT,(-MAX_LEVEL)
//ldi ZL,64
//mul r1,ZL
//movw ZL,r0
//add ZL,CHANNEL_OUT
//  subi ZL,lo8(- (conv_vol)   )
//  sbci ZH,hi8(-(conv_vol))
//  lpm CHANNEL_OUT,Z

//さらにコードのシフトを最適化した



  ldd XH, Y + VOL
  inc r16
  inc XH
  lsl XH
  mul r16, XH
  movw ZL, r0
  subi ZL, lo8(-(conv_vol - 2))
  sbci ZH, hi8(-(conv_vol - 2))
  andi ZL, 0xc0             //int()
  
  subi CHANNEL_OUT, (-MAX_LEVEL)
  add ZL, CHANNEL_OUT
  
  lpm CHANNEL_OUT, Z
/*------------------FeedBack-------------------------------*/

/*
 *   a * b /8
 * 
 */
  ldd r16, Y+FB
  fmulsu CHANNEL_OUT,r16		//Thank to Mr.Nanase
  asr r0
  asr r0
  asr r0  //   /16
  std Y + FBVAL,r0

/*-----------------------------------------op2---------------*/
OPERATOR2:  
  
  ldd ZL, Y + SIN_POSH + SIZEOF_FMOPERATOR //Zレジスタを逆に使い　読み出しポインタ加算
  ldd ZH, Y + SIN_POSL + SIZEOF_FMOPERATOR
  ldd r16, Y + SIN_STEPH + SIZEOF_FMOPERATOR
  ldd r17, Y + SIN_STEPL + SIZEOF_FMOPERATOR
  
  add ZH, r17
  adc ZL, r16
  
  std Y + SIN_POSH + SIZEOF_FMOPERATOR, ZL
  std Y + SIN_POSL + SIZEOF_FMOPERATOR, ZH
  
  add ZL, CHANNEL_OUT
  andi ZL, TABLE_SIZE_MASK
  

   ldd r16, Y + WAVE_TBLL + SIZEOF_FMOPERATOR
   ldd ZH, Y + WAVE_TBLH + SIZEOF_FMOPERATOR
   add ZL,r16

 
  lpm CHANNEL_OUT, Z        //波形をPROGMEMで置いている場合

//------- envelope   --- r16  level  r17 env_cnt   r21 vol ----------------------

  ldd r16,Y + LEVEL + SIZEOF_FMOPERATOR
  cp r20,XL
  brne ENV_LEVEL2
  
DO_ENVCHG2:

  ldd r17,Y + ENV_CNT + SIZEOF_FMOPERATOR
  ldd XH,Y + ENV_STEP + SIZEOF_FMOPERATOR
  sub r17,XH

  brcc ENV_LEVEL2_WITHSAVE
  

DO_ENVSTEP2:
  ldd XH,Y + ENV_STATE + SIZEOF_FMOPERATOR
  ldi r17,250
  
  cpi XH, F_ATK
  breq ATK_FASE2

  cpi XH, F_DECY
  breq DECY_FASE2

  cpi XH,F_SUS
  breq SUS_FASE2
  
  
REL_FASE2:
  std Y+ENV_CNT + SIZEOF_FMOPERATOR,r17
  cpi r16,(0)
  breq STOP_TONE2
  dec r16
  std Y+LEVEL + SIZEOF_FMOPERATOR,r16
  rjmp ENV_LEVEL2

DECY_FASE2:
  std Y+ENV_CNT + SIZEOF_FMOPERATOR,r17
  dec r16
  std Y+LEVEL + SIZEOF_FMOPERATOR,r16
  ldd XH,Y+SUL + SIZEOF_FMOPERATOR   //compare sustain level
  cp r16,XH
  brne ENV_LEVEL2
  ldi r17,F_SUS         //set sustain fase
  std Y+ENV_STATE + SIZEOF_FMOPERATOR,r17
  ldd XH,Y + SUS + SIZEOF_FMOPERATOR
  std Y + ENV_STEP + SIZEOF_FMOPERATOR,XH
  rjmp ENV_LEVEL2

SUS_FASE2:
  std Y+ENV_CNT + SIZEOF_FMOPERATOR,r17
  cpi r16,(0)
  breq STOP_TONE2 
  dec r16
  std Y+LEVEL + SIZEOF_FMOPERATOR,r16
  rjmp ENV_LEVEL2 

STOP_TONE2:

  std Y+SIN_STEPL + SIZEOF_FMOPERATOR,ZERO
  std Y+SIN_STEPH + SIZEOF_FMOPERATOR,ZERO 
  rjmp ENV_LEVEL2


ATK_FASE2:
//  std Y+ENV_CNT,r17  //書き込みを共用するため最後に移動
  inc r16
  std Y+LEVEL + SIZEOF_FMOPERATOR,r16
  cpi r16,(MAX_LEVEL)
  brne ENV_LEVEL2_WITHSAVE
 ldi r16,F_DECY       // set decay fase
  std Y+ENV_STATE + SIZEOF_FMOPERATOR,r16
  ldd XH,Y + DECY + SIZEOF_FMOPERATOR
  std Y + ENV_STEP + SIZEOF_FMOPERATOR,XH
ENV_LEVEL2_WITHSAVE:
  std Y+ENV_CNT + SIZEOF_FMOPERATOR,r17  //処理をパスしてきた時のsaveと共用する



ENV_LEVEL2:

  ldd XH, Y + VOL + SIZEOF_FMOPERATOR
  inc r16
  inc XH
  lsl XH
  mul r16, XH
  movw ZL, r0
  subi ZL, lo8(-(conv_vol - 2 ))
  sbci ZH, hi8(-(conv_vol - 2 ))
  andi ZL, 0xc0
  subi CHANNEL_OUT, (-MAX_LEVEL)
  
  add ZL, CHANNEL_OUT
  lpm CHANNEL_OUT, Z



CHANNEL_END:


  add TOTAL_OUT, CHANNEL_OUT


  subi YL, lo8(-(SIZEOF_FMOPERATOR * 2))
  sbci YH, hi8(-(SIZEOF_FMOPERATOR * 2))   
  
  subi XL, (1)
  brcs  endloop
  rjmp loop
  endloop:
  
  subi TOTAL_OUT, 0x80


#if (PWM_PIN == 3)
  sts OCR2B, TOTAL_OUT
#elif (PWM_PIN == 11)
  sts OCR2A, TOTAL_OUT
#elif (PWM_PIN == 5)
  sts OCR0B, TOTAL_OUT
#elif( PWM_PIN == 6)
  sts OCR0A, TOTAL_OUT
#endif

 #ifdef USE_DAC
  out _SFR_IO_ADDR(SPDR), TOTAL_OUT
 #endif

  pop r21
  pop r20
  pop CHANNEL_OUT
  pop TOTAL_OUT
  pop r17
  pop r16
  pop ZH
  pop ZL
  pop YH
  pop YL
  pop XH
  pop XL
  pop r0
  out _SFR_IO_ADDR(SREG), r0
  pop r1
  pop r0
  #ifdef USE_DAC  
  sbi 0x03, 0x02;
#endif  
  sei
  reti

.endfunc


// 除算テーブル
.balign 64
.global conv_vol   //アドレス計算高速化の為 conv_vol[64][32]
conv_vol:
.dc.b    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0
.dc.b  - 1, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1, 0
.dc.b  - 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2, 0
.dc.b  - 3, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  3, 0
.dc.b  - 4, -3, -3, -3, -3, -3, -3, -3, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  3,  3,  4, 0
.dc.b  - 5, -4, -4, -4, -4, -4, -4, -3, -3, -3, -3, -3, -3, -2, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  3,  4,  4,  4,  4,  4,  4,  5, 0
.dc.b  - 6, -5, -5, -5, -5, -5, -4, -4, -4, -4, -4, -3, -3, -3, -3, -3, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  4,  4,  4,  4,  4,  5,  5,  5,  5,  5,  6, 0
.dc.b  - 7, -6, -6, -6, -6, -5, -5, -5, -5, -4, -4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -2, -1, -1, -1, -1, -0, -0, -0, -0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  2,  2,  2,  2,  2,  3,  3,  3,  3,  4,  4,  4,  4,  4,  5,  5,  5,  5,  6,  6,  6,  6,  7, 0
.dc.b  - 8, -7, -7, -7, -6, -6, -6, -6, -5, -5, -5, -5, -4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -1, -1, -1, -1, -0, -0, -0,  0,  0,  0,  0,  1,  1,  1,  1,  2,  2,  2,  2,  3,  3,  3,  3,  4,  4,  4,  4,  5,  5,  5,  5,  6,  6,  6,  6,  7,  7,  7,  8, 0
.dc.b  - 9, -8, -8, -8, -7, -7, -7, -6, -6, -6, -6, -5, -5, -5, -4, -4, -4, -4, -3, -3, -3, -2, -2, -2, -2, -1, -1, -1, -0, -0, -0,  0,  0,  0,  0,  1,  1,  1,  2,  2,  2,  2,  3,  3,  3,  4,  4,  4,  4,  5,  5,  5,  6,  6,  6,  6,  7,  7,  7,  8,  8,  8,  9, 0
.dc.b - 10, -9, -9, -9, -8, -8, -8, -7, -7, -7, -6, -6, -6, -5, -5, -5, -4, -4, -4, -3, -3, -3, -2, -2, -2, -1, -1, -1, -0, -0, -0,  0,  0,  0,  0,  1,  1,  1,  2,  2,  2,  3,  3,  3,  4,  4,  4,  5,  5,  5,  6,  6,  6,  7,  7,  7,  8,  8,  8,  9,  9,  9, 10, 0
.dc.b - 11, -10, -10, -9, -9, -9, -8, -8, -8, -7, -7, -7, -6, -6, -6, -5, -5, -4, -4, -4, -3, -3, -3, -2, -2, -2, -1, -1, -1, -0, -0,  0,  0,  0,  1,  1,  1,  2,  2,  2,  3,  3,  3,  4,  4,  4,  5,  5,  6,  6,  6,  7,  7,  7,  8,  8,  8,  9,  9,  9, 10, 10, 11, 0
.dc.b - 12, -11, -11, -10, -10, -10, -9, -9, -8, -8, -8, -7, -7, -6, -6, -6, -5, -5, -5, -4, -4, -3, -3, -3, -2, -2, -1, -1, -1, -0, -0,  0,  0,  0,  1,  1,  1,  2,  2,  3,  3,  3,  4,  4,  5,  5,  5,  6,  6,  6,  7,  7,  8,  8,  8,  9,  9, 10, 10, 10, 11, 11, 12, 0
.dc.b - 13, -12, -12, -11, -11, -10, -10, -10, -9, -9, -8, -8, -7, -7, -7, -6, -6, -5, -5, -5, -4, -4, -3, -3, -2, -2, -2, -1, -1, -0, -0,  0,  0,  0,  1,  1,  2,  2,  2,  3,  3,  4,  4,  5,  5,  5,  6,  6,  7,  7,  7,  8,  8,  9,  9, 10, 10, 10, 11, 11, 12, 12, 13, 0
.dc.b - 14, -13, -13, -12, -12, -11, -11, -10, -10, -9, -9, -9, -8, -8, -7, -7, -6, -6, -5, -5, -4, -4, -4, -3, -3, -2, -2, -1, -1, -0, -0,  0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  4,  5,  5,  6,  6,  7,  7,  8,  8,  9,  9,  9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 0
.dc.b - 15, -14, -14, -13, -13, -12, -12, -11, -11, -10, -10, -9, -9, -8, -8, -7, -7, -6, -6, -5, -5, -4, -4, -3, -3, -2, -2, -1, -1, -0, -0,  0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  5,  6,  6,  7,  7,  8,  8,  9,  9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 0
.dc.b - 16, -15, -14, -14, -13, -13, -12, -12, -11, -11, -10, -10, -9, -9, -8, -8, -7, -7, -6, -6, -5, -5, -4, -4, -3, -3, -2, -2, -1, -1, -0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  5,  6,  6,  7,  7,  8,  8,  9,  9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 16, 0
.dc.b - 17, -16, -15, -15, -14, -14, -13, -13, -12, -12, -11, -10, -10, -9, -9, -8, -8, -7, -7, -6, -6, -5, -4, -4, -3, -3, -2, -2, -1, -1, -0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  6,  6,  7,  7,  8,  8,  9,  9, 10, 10, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 17, 0
.dc.b - 18, -17, -16, -16, -15, -15, -14, -13, -13, -12, -12, -11, -11, -10, -9, -9, -8, -8, -7, -6, -6, -5, -5, -4, -4, -3, -2, -2, -1, -1, -0,  0,  0,  1,  1,  2,  2,  3,  4,  4,  5,  5,  6,  6,  7,  8,  8,  9,  9, 10, 11, 11, 12, 12, 13, 13, 14, 15, 15, 16, 16, 17, 18, 0
.dc.b - 19, -18, -17, -17, -16, -15, -15, -14, -14, -13, -12, -12, -11, -11, -10, -9, -9, -8, -7, -7, -6, -6, -5, -4, -4, -3, -3, -2, -1, -1, -0,  0,  0,  1,  1,  2,  3,  3,  4,  4,  5,  6,  6,  7,  7,  8,  9,  9, 10, 11, 11, 12, 12, 13, 14, 14, 15, 15, 16, 17, 17, 18, 19, 0
.dc.b - 20, -19, -18, -18, -17, -16, -16, -15, -14, -14, -13, -12, -12, -11, -10, -10, -9, -9, -8, -7, -7, -6, -5, -5, -4, -3, -3, -2, -1, -1, -0,  0,  0,  1,  1,  2,  3,  3,  4,  5,  5,  6,  7,  7,  8,  9,  9, 10, 10, 11, 12, 12, 13, 14, 14, 15, 16, 16, 17, 18, 18, 19, 20, 0
.dc.b - 21, -20, -19, -18, -18, -17, -16, -16, -15, -14, -14, -13, -12, -12, -11, -10, -10, -9, -8, -8, -7, -6, -6, -5, -4, -4, -3, -2, -2, -1, -0,  0,  0,  1,  2,  2,  3,  4,  4,  5,  6,  6,  7,  8,  8,  9, 10, 10, 11, 12, 12, 13, 14, 14, 15, 16, 16, 17, 18, 18, 19, 20, 21, 0
.dc.b - 22, -21, -20, -19, -19, -18, -17, -17, -16, -15, -14, -14, -13, -12, -12, -11, -10, -9, -9, -8, -7, -7, -6, -5, -4, -4, -3, -2, -2, -1, -0,  0,  0,  1,  2,  2,  3,  4,  4,  5,  6,  7,  7,  8,  9,  9, 10, 11, 12, 12, 13, 14, 14, 15, 16, 17, 17, 18, 19, 19, 20, 21, 22, 0
.dc.b - 23, -22, -21, -20, -20, -19, -18, -17, -17, -16, -15, -14, -14, -13, -12, -11, -11, -10, -9, -8, -8, -7, -6, -5, -5, -4, -3, -2, -2, -1, -0,  0,  0,  1,  2,  2,  3,  4,  5,  5,  6,  7,  8,  8,  9, 10, 11, 11, 12, 13, 14, 14, 15, 16, 17, 17, 18, 19, 20, 20, 21, 22, 23, 0
.dc.b - 24, -23, -22, -21, -20, -20, -19, -18, -17, -17, -16, -15, -14, -13, -13, -12, -11, -10, -10, -9, -8, -7, -6, -6, -5, -4, -3, -3, -2, -1, -0,  0,  0,  1,  2,  3,  3,  4,  5,  6,  6,  7,  8,  9, 10, 10, 11, 12, 13, 13, 14, 15, 16, 17, 17, 18, 19, 20, 20, 21, 22, 23, 24, 0
.dc.b - 25, -24, -23, -22, -21, -20, -20, -19, -18, -17, -16, -16, -15, -14, -13, -12, -12, -11, -10, -9, -8, -8, -7, -6, -5, -4, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  4,  5,  6,  7,  8,  8,  9, 10, 11, 12, 12, 13, 14, 15, 16, 16, 17, 18, 19, 20, 20, 21, 22, 23, 24, 25, 0
.dc.b - 26, -25, -24, -23, -22, -21, -20, -20, -19, -18, -17, -16, -15, -15, -14, -13, -12, -11, -10, -10, -9, -8, -7, -6, -5, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  5,  6,  7,  8,  9, 10, 10, 11, 12, 13, 14, 15, 15, 16, 17, 18, 19, 20, 20, 21, 22, 23, 24, 25, 26, 0
.dc.b - 27, -26, -25, -24, -23, -22, -21, -20, -20, -19, -18, -17, -16, -15, -14, -13, -13, -12, -11, -10, -9, -8, -7, -6, -6, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  6,  6,  7,  8,  9, 10, 11, 12, 13, 13, 14, 15, 16, 17, 18, 19, 20, 20, 21, 22, 23, 24, 25, 26, 27, 0
.dc.b - 28, -27, -26, -25, -24, -23, -22, -21, -20, -19, -18, -18, -17, -16, -15, -14, -13, -12, -11, -10, -9, -9, -8, -7, -6, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 0
.dc.b - 29, -28, -27, -26, -25, -24, -23, -22, -21, -20, -19, -18, -17, -16, -15, -14, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 0
.dc.b - 30, -29, -28, -27, -26, -25, -24, -23, -22, -21, -20, -19, -18, -17, -16, -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 0
.dc.b - 5, -30, -29, -28, -27, -26, -25, -24, -23, -22, -21, -20, -19, -18, -17, -16, -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 0





.global wave_sin
.global wave_tri
.global wave_saw
.global wave_rect
.global wave_clipsin
.global wave_abssin

wave_sin:
.dc.b   0, 3, 6, 9, 12, 15, 17, 20, 22, 24, 26, 28, 29, 30, 31, 31
.dc.b   31, 31, 31, 30, 29, 28, 26, 24, 22, 20, 17, 15, 12, 9, 6, 3
.dc.b   0, -3, -6, -9, -12, -15, -17, -20, -22, -24, -26, -28, -29, -30, -31, -31
.dc.b  -31, -31, -31, -30, -29, -28, -26, -24, -22, -20, -17, -15, -12, -9, -6, -3


wave_tri:
.dc.b 0,1,3,5,7,9,11,13,15,17,19,21,23,25,27,29
.dc.b 31,30,28,26,24,22,20,18,16,14,12,10,8,6,4,2
.dc.b 0,-2,-4,-6,-8,-10,-12,-14,-16,-18,-20,-22,-24,-26,-28,-30
.dc.b -31,-30,-28,-26,-24,-22,-20,-18,-16,-14,-12,-10,-8,-6,-4,-2

wave_saw:
.dc.b   0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14
.dc.b   15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 , 28 , 29, 30
.dc.b   -31, -30, -29, -28, -27, -26, -25, -24, -23, -22, -21, -20, -19, -18, -17, -16
.dc.b   -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1,  0

wave_rect:
.dc.b   -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21
.dc.b   -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21
.dc.b   21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21
.dc.b   21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21


wave_clipsin:
.dc.b   0,  3,  6,  8, 11, 14, 17, 19, 20, 20, 20, 20, 20, 20, 20, 20
.dc.b   20, 20, 20, 20, 20, 20, 20, 20, 20, 19, 17, 14, 11,  8,  6,  3
.dc.b   0, -3, -6, -8, -11, -14, -17, -19, -20, -20, -20, -20, -20, -20, -20, -20
.dc.b   -20, -20, -20, -20, -20, -20, -20, -20, -20, -19, -17, -14, -11, -8, -6, -3
  
wave_abssin:
.dc.b   0,  3,  6,  8, 11, 14, 17, 19, 21, 23, 25, 27, 28, 29, 30, 30
.dc.b   31, 30, 30, 29, 28, 27, 25, 23, 21, 19, 17, 14, 11,  8,  6,  3
.dc.b   0,  3,  6,  8, 11, 14, 17, 19, 21, 23, 25, 27, 28, 29, 30, 30
.dc.b   31, 30, 30, 29, 28, 27, 25, 23, 21, 19, 17, 14, 11,  8,  6,  3









/*
   速度求めて改変し過ぎたので同等のCコードイメージ（テスト未)
      

#define TABLE_SIZE_MASK 0x3f

struct MemTone {
  private:
    uint16_t sin_pos;
    uint16_t sin_step;
   uint8_t  tl;

    uint8_t env_state;
    uint8_t env_cnt;

    uint8_t atk;
    uint8_t decy;
    uint8_t sul;
    uint8_t sus;
    uint8_t rel;
    uint8_t level;
    uint8_t mul;
    uint16_t wave_tbl;
    uint8_t fb;
    uint8_t fb_val;
    uint8_t env_step;
} fm_operator[MAX_TONE * sizeof(MemTone)];

uint8_t wait_cnt = 0;


ISR(TIMER_COMPA_vect){
  uint16_t read_pos16;
  uint8_t  read_pos8;
  uint8_t *wave_table;
  uint8_t channel_out;
  uint8_t env_level;
  
  wait_cnt++;
  wait_cnt &= 0x7;   // 最大7音
  
  
  for(uint8_t ch, ch < MAX_MIDITONE,ch++){
  read_pos16 = fm_operator[ch].sin_pos;    // 16bit固定小数点(8.8)形式
  red_pos16 += fm_operator[ch].sin_step;
  fm_operator[ch].sin_pos = read_pos16;
  read_pos8 = read_pos16 >>8;          //int()

  // feed back 
  read_pos8 += fm_operator[ch].fb_val;
  read_pos8 &= TABLE_SIZE_MASK;

  wave_table = fm_operator[ch].wave_tbl;
  channel_out = wave_table[read_pos8];

  env_level = fm_operator[ch].level;
  
  if(wait_cnt == ch){
    uint8_t cnt;
    uint8_t step;
    cnt = fm_operator[ch].env_cnt;
    step = fm_operator[ch].env_step;
    cnt = cnt -step;
    fm_operator[ch].env_cnt = cnt;
    if(cnt < 0){
    fm_operator[ch].env_cnt = 250;
    
    switch(fm_operator[ch].env_state){
      
    case F_ATK:
      env_level++;
      if(env_level == MAX_LEVEL){
      fm_operator[ch].env_state = F_DECY;
      }
      fm_operator[ch].level = env_level;
      break;

    case F_DECY:
      env_level--;
      if(env_level == fm_operator[ch].sul){
      fm_operator[ch].env_state = F_SUS;
      }
      fm_operator[ch].level = env_level;
      break;
      
    case F_SUS:
      env_level--;
      if(env_level == 0){
      fm_operator[ch].sin_step = 0;  //stepが0なので音は鳴らない
      }
      fm_operator[ch].level = env_level;
      break;

    case F_REL:
      env_level--;
      if(env_level == 0){
      fm_operator[ch].sin_step = 0;
      }
      fm_operator[ch].level = env_level;
      break;

    default:
      break;
    }
    }


  }
  channel_out = channel_out * fm_operator[ch].vol * env_level / 31 / 31;
  
  //---------------  OP2  --------------------------//
  ch++;
  read_pos16 = fm_operator[ch].sin_pos;    // 16bit固定小数点(8.8)形式
  red_pos16 += fm_operator[ch].sin_step;
  fm_operator[ch].sin_pos = read_pos16;
  read_pos8 = read_pos16 >>8;          //int()

  // feed back 
  read_pos8 += channel_out;      //前OPの出力で読み出しポインタを変更
  read_pos8 &= TABLE_SIZE_MASK;

  //----------後は同じ----------------------
  //--------------------------------------
  }
}


 
 */
