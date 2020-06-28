
/*
 * PWM out PIN3
 * 
 */
#include <avr/io.h>
#include <avr/interrupt.h>
#include "envtone_def.h"

.extern memtone
.extern wave_tbl


//#define USE_DAC 
#define TABLE_SIZE_MASK 0x3f



/* offset from struct head */
#define SIN_POSL 0
#define SIN_POSH 1
#define SIN_STEPL 2
#define SIN_STEPH 3
#define VOL     4
#define ENV_STATE 5
#define ENV_CNT   6
#define ATK   7
#define DECY  8
#define SUL   9
#define SUS   10
#define REL   11
#define LEVEL 12
#define MUL   13
#define WAVE_TBLL 14
#define WAVE_TBLH 15

#define SIZEOF_MEMTONE 16

#define F_ATK  1
#define F_DECY 2
#define F_SUS  3
#define F_REL  4

#define TOTAL_OUT r18
#define CHANNEL_OUT r19

.section .data
wait_cnt: .dc.b  0        //エンベロープのウェイト用カウンタ


.section .text



.global TIMER1_COMPA_vect
TIMER1_COMPA_vect:
.func
  cli
  push r0
  push r1
  in r0,_SFR_IO_ADDR(SREG)
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
  


#ifdef USE_DAC
  cbi 0x03, 0x02
  ldi ZL, 0x36
  out _SFR_IO_ADDR(SPDR), ZL 
#endif

 ldi XL,MAX_REALTONE - 1     ;loop conter
 clr TOTAL_OUT

  
  lds r20,wait_cnt
#ifdef USE_24KHZ
  subi r20,32
#else
  subi r20,64
#endif
  sts wait_cnt,r20
//
  ldi YL,lo8(memtone)
  ldi YH,hi8(memtone)

loop:

  ldd ZL, Y+SIN_POSH     //Zレジスタを逆に使い　読み出しポインタ加算
  ldd ZH, Y+SIN_POSL
  ldd r16,Y+SIN_STEPH
  ldd r17,Y+SIN_STEPL
  add ZH,r17
  adc ZL,r16
  andi ZL,TABLE_SIZE_MASK
  std Y + SIN_POSH, ZL
  std Y + SIN_POSL, ZH


  clr ZH                  //Read sin table from tone pointer

  ldd r16,Y+WAVE_TBLL
  ldd r17,Y+WAVE_TBLH
  add ZL,r16
  adc ZH,r17
  
  //ld CHANNEL_OUT,Z
  lpm CHANNEL_OUT,Z         //波形をPROGMEMで置いている場合
    
  // volume
  subi CHANNEL_OUT,(-31)
  ldi ZL,64                 //計算簡素化のため conv_volを[63][32]から[64][32]に変更した
  ldd  r16, Y + VOL
  muls r16,ZL
  movw ZL,r0
  //clr r0
  add ZL,CHANNEL_OUT
  //adc ZH,r0
  subi ZL,lo8(-(conv_vol ))
  sbci ZH,hi8(-(conv_vol ))
  lpm CHANNEL_OUT,Z


//------- envelope   --- r16  level  r17 env_cnt  ----------------------
  ldd r16,Y + LEVEL
   cpi r20,(0)
   breq DO_ENVCHG
   rjmp ENV_LEVEL   

 
DO_ENVCHG:

  ldd r17,Y + ENV_CNT
  ldd XH,Y + ENV_STATE    //memtone[XL].env_state
  
  cpi XH,F_ATK
  breq ATK_FASE
  
  cpi XH,F_DECY
  breq DECY_FASE
  
  cpi XH,F_SUS
  breq SUS_FASE
  
//  cpi XH,F_REL
//  breq REL_FASE
//  rjmp ENV_LEVEL


REL_FASE:
  ldd XH,Y+REL
  sub r17,XH
  brcs DO_REL_DEC
  std Y+ENV_CNT,r17
  rjmp ENV_LEVEL

DO_REL_DEC:           
  ldi r17,250
  std Y+ENV_CNT,r17
  cpi r16,(0)
  breq STOP_TONE 
  dec r16
  std Y+LEVEL,r16
  sbi 11,2
  rjmp ENV_LEVEL  
 
  
DECY_FASE:
  ldd XH,Y+DECY
  sub r17,XH
  brcs DO_DECY_DEC
  std Y+ENV_CNT,r17
  rjmp ENV_LEVEL

DO_DECY_DEC:
  ldi r17,250
  std Y+ENV_CNT,r17
  dec r16
  std Y+LEVEL,r16
  ldd XH,Y+SUL   //compare sustain level
  cp r16,XH
  brne ENV_LEVEL
  ldi r17,F_SUS         //set sustain fase
  std Y+ENV_STATE,r17
  rjmp ENV_LEVEL


SUS_FASE:
  ldd XH,Y+SUS
  sub r17,XH
  brcs DO_SUS_DEC
  std Y+ENV_CNT,r17
  rjmp ENV_LEVEL

DO_SUS_DEC:
  ldi r17,250
  std Y+ENV_CNT,r17
  cpi r16,(0)
  breq STOP_TONE 
  dec r16
  std Y+LEVEL,r16
  rjmp ENV_LEVEL



STOP_TONE:
  clr r17
  std Y+SIN_STEPL,r17
  std Y+SIN_STEPH,r17 
  rjmp ENV_LEVEL

  

DO_ATK_INC:
  ldi r17,250
  std Y+ENV_CNT,r17
  inc r16
  std Y+LEVEL,r16
  cpi r16,(31)
  brne ENV_LEVEL
  ldi r17,F_DECY       // set decay fase
  std Y+ENV_STATE,r17
  rjmp ENV_LEVEL

  
ATK_FASE:
  ldd XH,Y+ATK
  sub r17,XH
  brcs DO_ATK_INC
  std Y + ENV_CNT,r17
//  rjmp ENV_LEVEL    //このrjmpを減らすのに一番効果のあるのはAtkのここ
  

ENV_LEVEL:  
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


  //add TOTAL_OUT,CHANNEL_OUT

/*-----------------------------------------op2---------------*/
OPERATOR2:
    subi YL,lo8(-(SIZEOF_MEMTONE))
    sbci YH,hi8(-(SIZEOF_MEMTONE))


  ldd ZL, Y+SIN_POSH     //Zレジスタを逆に使い　読み出しポインタ加算
  ldd ZH, Y+SIN_POSL
  ldd r16,Y+SIN_STEPH
  ldd r17,Y+SIN_STEPL
  add ZH,r17
  adc ZL,r16
  andi ZL,TABLE_SIZE_MASK

//or r17,r16
//brne DO_STEP2
//ldi CHANNEL_OUT,0
//rjmp CHANNEL_END
//DO_STEP2:
  
  std Y + SIN_POSH, ZL
  std Y + SIN_POSL, ZH
  
//
//  add CHANNEL_OUT,CHANNEL_OUT
//  andi CHANNEL_OUT,0x3f
  add ZL,CHANNEL_OUT
  andi ZL,0x3f


    clr ZH                  //Read sin table from tone pointer

  ldd r16,Y+WAVE_TBLL
  ldd r17,Y+WAVE_TBLH
  add ZL,r16
  adc ZH,r17
  
  //ld CHANNEL_OUT,Z
  lpm CHANNEL_OUT,Z         //波形をPROGMEMで置いている場合
    
  // volume
  subi CHANNEL_OUT,(-31)
  ldi ZL,64                 //計算簡素化のため conv_volを[63][32]から[64][32]に変更した
  ldd  r16, Y + VOL
  muls r16,ZL
  movw ZL,r0
  //clr r0
  add ZL,CHANNEL_OUT
  //adc ZH,r0
  subi ZL,lo8(-(conv_vol ))
  sbci ZH,hi8(-(conv_vol ))
  lpm CHANNEL_OUT,Z


//------- envelope   --- r16  level  r17 env_cnt  ----------------------
  ldd r16,Y + LEVEL
   cpi r20,(0)
   breq DO_ENVCHG2
   rjmp ENV_LEVEL2  


  
DO_ENVCHG2:

  ldd r17,Y + ENV_CNT
  ldd XH,Y + ENV_STATE    //memtone[XL].env_state
  
  cpi XH,F_ATK
  breq ATK_FASE2
  
  cpi XH,F_DECY
  breq DECY_FASE2
  
  cpi XH,F_SUS
  breq SUS_FASE2
  
//  cpi XH,F_REL
//  breq REL_FASE
//  rjmp ENV_LEVEL


REL_FASE2:
  ldd XH,Y+REL
  sub r17,XH
  brcs DO_REL_DEC2
  std Y+ENV_CNT,r17
  rjmp ENV_LEVEL2

DO_REL_DEC2:           
  ldi r17,250
  std Y+ENV_CNT,r17
  cpi r16,(0)
  breq STOP_TONE2 
  dec r16
  std Y+LEVEL,r16
  sbi 11,2
  rjmp ENV_LEVEL2  

  
  
DECY_FASE2:
  ldd XH,Y+DECY
  sub r17,XH
  brcs DO_DECY_DEC2
  std Y+ENV_CNT,r17
  rjmp ENV_LEVEL2

DO_DECY_DEC2:
  ldi r17,250
  std Y+ENV_CNT,r17
  dec r16
  std Y+LEVEL,r16
  ldd XH,Y+SUL   //compare sustain level
  cp r16,XH
  brne ENV_LEVEL2
  ldi r17,F_SUS         //set sustain fase
  std Y+ENV_STATE,r17
  rjmp ENV_LEVEL2


SUS_FASE2:
  ldd XH,Y+SUS
  sub r17,XH
  brcs DO_SUS_DEC2
  std Y+ENV_CNT,r17
  rjmp ENV_LEVEL2

DO_SUS_DEC2:
  ldi r17,250
  std Y+ENV_CNT,r17
  cpi r16,(0)
  breq STOP_TONE2 
  dec r16
  std Y+LEVEL,r16
  rjmp ENV_LEVEL2



STOP_TONE2:
  clr r17
  std Y+SIN_STEPL,r17
  std Y+SIN_STEPH,r17 
  rjmp ENV_LEVEL2

  

DO_ATK_INC2:
  ldi r17,250
  std Y+ENV_CNT,r17
  inc r16
  std Y+LEVEL,r16
  cpi r16,(31)
  brne ENV_LEVEL2
  ldi r17,F_DECY       // set decay fase
  std Y+ENV_STATE,r17
  rjmp ENV_LEVEL2

  
ATK_FASE2:
  ldd XH,Y+ATK
  sub r17,XH
  brcs DO_ATK_INC2
  std Y + ENV_CNT,r17
//  rjmp ENV_LEVEL    //このrjmpを減らすのに一番効果のあるのはAtkのここ
  

ENV_LEVEL2:  
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

CHANNEL_END:


//lsl CHANNEL_OUT          //増幅？？
  add TOTAL_OUT,CHANNEL_OUT


    subi YL,lo8(-(SIZEOF_MEMTONE))
    sbci YH,hi8(-(SIZEOF_MEMTONE))




  subi XL,(1)
  brcs  endloop
  rjmp loop
endloop:

    subi TOTAL_OUT,0x80


 #ifdef USE_DAC
  out _SFR_IO_ADDR(SPDR), TOTAL_OUT
 #endif

#if (PWM_PIN == 3)
  sts OCR2B, TOTAL_OUT
#elif (PWM_PIN == 11)
  sts OCR2A, TOTAL_OUT
#elif (PWM_PIN == 5)
  sts OCR0B, TOTAL_OUT
#elif( PWM_PIN == 6)
  sts OCR0A, TOTAL_OUT
#endif




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

.global conv_vol   //アドレス計算高速化の為 conv_vol[64][32]
conv_vol: 
.dc.b    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,0
.dc.b  -1, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,0
.dc.b  -2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,0
.dc.b  -3, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  3,0
.dc.b  -4, -3, -3, -3, -3, -3, -3, -3, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  3,  3,  4,0
.dc.b  -5, -4, -4, -4, -4, -4, -4, -3, -3, -3, -3, -3, -3, -2, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  3,  4,  4,  4,  4,  4,  4,  5,0
.dc.b  -6, -5, -5, -5, -5, -5, -4, -4, -4, -4, -4, -3, -3, -3, -3, -3, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1, -0, -0, -0, -0, -0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  4,  4,  4,  4,  4,  5,  5,  5,  5,  5,  6,0
.dc.b  -7, -6, -6, -6, -6, -5, -5, -5, -5, -4, -4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -2, -1, -1, -1, -1, -0, -0, -0, -0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  2,  2,  2,  2,  2,  3,  3,  3,  3,  4,  4,  4,  4,  4,  5,  5,  5,  5,  6,  6,  6,  6,  7,0
.dc.b  -8, -7, -7, -7, -6, -6, -6, -6, -5, -5, -5, -5, -4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -1, -1, -1, -1, -0, -0, -0,  0,  0,  0,  0,  1,  1,  1,  1,  2,  2,  2,  2,  3,  3,  3,  3,  4,  4,  4,  4,  5,  5,  5,  5,  6,  6,  6,  6,  7,  7,  7,  8,0
.dc.b  -9, -8, -8, -8, -7, -7, -7, -6, -6, -6, -6, -5, -5, -5, -4, -4, -4, -4, -3, -3, -3, -2, -2, -2, -2, -1, -1, -1, -0, -0, -0,  0,  0,  0,  0,  1,  1,  1,  2,  2,  2,  2,  3,  3,  3,  4,  4,  4,  4,  5,  5,  5,  6,  6,  6,  6,  7,  7,  7,  8,  8,  8,  9,0
.dc.b -10, -9, -9, -9, -8, -8, -8, -7, -7, -7, -6, -6, -6, -5, -5, -5, -4, -4, -4, -3, -3, -3, -2, -2, -2, -1, -1, -1, -0, -0, -0,  0,  0,  0,  0,  1,  1,  1,  2,  2,  2,  3,  3,  3,  4,  4,  4,  5,  5,  5,  6,  6,  6,  7,  7,  7,  8,  8,  8,  9,  9,  9, 10,0
.dc.b -11,-10,-10, -9, -9, -9, -8, -8, -8, -7, -7, -7, -6, -6, -6, -5, -5, -4, -4, -4, -3, -3, -3, -2, -2, -2, -1, -1, -1, -0, -0,  0,  0,  0,  1,  1,  1,  2,  2,  2,  3,  3,  3,  4,  4,  4,  5,  5,  6,  6,  6,  7,  7,  7,  8,  8,  8,  9,  9,  9, 10, 10, 11,0
.dc.b -12,-11,-11,-10,-10,-10, -9, -9, -8, -8, -8, -7, -7, -6, -6, -6, -5, -5, -5, -4, -4, -3, -3, -3, -2, -2, -1, -1, -1, -0, -0,  0,  0,  0,  1,  1,  1,  2,  2,  3,  3,  3,  4,  4,  5,  5,  5,  6,  6,  6,  7,  7,  8,  8,  8,  9,  9, 10, 10, 10, 11, 11, 12,0
.dc.b -13,-12,-12,-11,-11,-10,-10,-10, -9, -9, -8, -8, -7, -7, -7, -6, -6, -5, -5, -5, -4, -4, -3, -3, -2, -2, -2, -1, -1, -0, -0,  0,  0,  0,  1,  1,  2,  2,  2,  3,  3,  4,  4,  5,  5,  5,  6,  6,  7,  7,  7,  8,  8,  9,  9, 10, 10, 10, 11, 11, 12, 12, 13,0
.dc.b -14,-13,-13,-12,-12,-11,-11,-10,-10, -9, -9, -9, -8, -8, -7, -7, -6, -6, -5, -5, -4, -4, -4, -3, -3, -2, -2, -1, -1, -0, -0,  0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  4,  5,  5,  6,  6,  7,  7,  8,  8,  9,  9,  9, 10, 10, 11, 11, 12, 12, 13, 13, 14,0
.dc.b -15,-14,-14,-13,-13,-12,-12,-11,-11,-10,-10, -9, -9, -8, -8, -7, -7, -6, -6, -5, -5, -4, -4, -3, -3, -2, -2, -1, -1, -0, -0,  0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  5,  6,  6,  7,  7,  8,  8,  9,  9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15,0
.dc.b -16,-15,-14,-14,-13,-13,-12,-12,-11,-11,-10,-10, -9, -9, -8, -8, -7, -7, -6, -6, -5, -5, -4, -4, -3, -3, -2, -2, -1, -1, -0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  5,  6,  6,  7,  7,  8,  8,  9,  9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 16,0
.dc.b -17,-16,-15,-15,-14,-14,-13,-13,-12,-12,-11,-10,-10, -9, -9, -8, -8, -7, -7, -6, -6, -5, -4, -4, -3, -3, -2, -2, -1, -1, -0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  6,  6,  7,  7,  8,  8,  9,  9, 10, 10, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 17,0
.dc.b -18,-17,-16,-16,-15,-15,-14,-13,-13,-12,-12,-11,-11,-10, -9, -9, -8, -8, -7, -6, -6, -5, -5, -4, -4, -3, -2, -2, -1, -1, -0,  0,  0,  1,  1,  2,  2,  3,  4,  4,  5,  5,  6,  6,  7,  8,  8,  9,  9, 10, 11, 11, 12, 12, 13, 13, 14, 15, 15, 16, 16, 17, 18,0
.dc.b -19,-18,-17,-17,-16,-15,-15,-14,-14,-13,-12,-12,-11,-11,-10, -9, -9, -8, -7, -7, -6, -6, -5, -4, -4, -3, -3, -2, -1, -1, -0,  0,  0,  1,  1,  2,  3,  3,  4,  4,  5,  6,  6,  7,  7,  8,  9,  9, 10, 11, 11, 12, 12, 13, 14, 14, 15, 15, 16, 17, 17, 18, 19,0
.dc.b -20,-19,-18,-18,-17,-16,-16,-15,-14,-14,-13,-12,-12,-11,-10,-10, -9, -9, -8, -7, -7, -6, -5, -5, -4, -3, -3, -2, -1, -1, -0,  0,  0,  1,  1,  2,  3,  3,  4,  5,  5,  6,  7,  7,  8,  9,  9, 10, 10, 11, 12, 12, 13, 14, 14, 15, 16, 16, 17, 18, 18, 19, 20,0
.dc.b -21,-20,-19,-18,-18,-17,-16,-16,-15,-14,-14,-13,-12,-12,-11,-10,-10, -9, -8, -8, -7, -6, -6, -5, -4, -4, -3, -2, -2, -1, -0,  0,  0,  1,  2,  2,  3,  4,  4,  5,  6,  6,  7,  8,  8,  9, 10, 10, 11, 12, 12, 13, 14, 14, 15, 16, 16, 17, 18, 18, 19, 20, 21,0
.dc.b -22,-21,-20,-19,-19,-18,-17,-17,-16,-15,-14,-14,-13,-12,-12,-11,-10, -9, -9, -8, -7, -7, -6, -5, -4, -4, -3, -2, -2, -1, -0,  0,  0,  1,  2,  2,  3,  4,  4,  5,  6,  7,  7,  8,  9,  9, 10, 11, 12, 12, 13, 14, 14, 15, 16, 17, 17, 18, 19, 19, 20, 21, 22,0
.dc.b -23,-22,-21,-20,-20,-19,-18,-17,-17,-16,-15,-14,-14,-13,-12,-11,-11,-10, -9, -8, -8, -7, -6, -5, -5, -4, -3, -2, -2, -1, -0,  0,  0,  1,  2,  2,  3,  4,  5,  5,  6,  7,  8,  8,  9, 10, 11, 11, 12, 13, 14, 14, 15, 16, 17, 17, 18, 19, 20, 20, 21, 22, 23,0
.dc.b -24,-23,-22,-21,-20,-20,-19,-18,-17,-17,-16,-15,-14,-13,-13,-12,-11,-10,-10, -9, -8, -7, -6, -6, -5, -4, -3, -3, -2, -1, -0,  0,  0,  1,  2,  3,  3,  4,  5,  6,  6,  7,  8,  9, 10, 10, 11, 12, 13, 13, 14, 15, 16, 17, 17, 18, 19, 20, 20, 21, 22, 23, 24,0
.dc.b -25,-24,-23,-22,-21,-20,-20,-19,-18,-17,-16,-16,-15,-14,-13,-12,-12,-11,-10, -9, -8, -8, -7, -6, -5, -4, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  4,  5,  6,  7,  8,  8,  9, 10, 11, 12, 12, 13, 14, 15, 16, 16, 17, 18, 19, 20, 20, 21, 22, 23, 24, 25,0
.dc.b -26,-25,-24,-23,-22,-21,-20,-20,-19,-18,-17,-16,-15,-15,-14,-13,-12,-11,-10,-10, -9, -8, -7, -6, -5, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  5,  6,  7,  8,  9, 10, 10, 11, 12, 13, 14, 15, 15, 16, 17, 18, 19, 20, 20, 21, 22, 23, 24, 25, 26,0
.dc.b -27,-26,-25,-24,-23,-22,-21,-20,-20,-19,-18,-17,-16,-15,-14,-13,-13,-12,-11,-10, -9, -8, -7, -6, -6, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  6,  6,  7,  8,  9, 10, 11, 12, 13, 13, 14, 15, 16, 17, 18, 19, 20, 20, 21, 22, 23, 24, 25, 26, 27,0
.dc.b -28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-18,-17,-16,-15,-14,-13,-12,-11,-10, -9, -9, -8, -7, -6, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28,0
.dc.b -29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-14,-13,-12,-11,-10, -9, -8, -7, -6, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29,0
.dc.b -30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10, -9, -8, -7, -6, -5, -4, -3, -2, -1, -0,  0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,0
.dc.b -31,-30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10, -9, -8, -7, -6, -5, -4, -3, -2, -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,0

