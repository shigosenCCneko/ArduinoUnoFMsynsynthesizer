#include <avr/io.h>
#include <avr/pgmspace.h>
#include "envtone.h"


#define MIDI_NOTE_OFF        0x80
#define MIDI_NOTE_ON         0x90
#define MIDI_PG_CHG          0xC0



const uint8_t default_tone[MAX_DEFAULT_TONE][16] = {
  {15, 0, 4, 0, 0, 17, 1, 4,  13, 9, 4, 2, 4, 0, 1,  0}, //Syns Trumpet
  {10, 4, 1, 1, 7, 9, 1, 3, 10,15, 1, 1,10, 0, 1, 0,},
  {15, 3, 4, 1, 1, 16, 5, 0, 15, 5, 3, 2, 4, 0, 4, 0,}, //bell
  {15, 8, 5, 0, 2, 8, 1, 5, 15, 7, 2, 2, 6, 0, 1, 0,},
  {14, 6, 4, 0, 0, 14, 3, 5, 15, 5, 1, 0, 10, 0, 1, 0,}
};

EnvTone ENVTONE;
MemTone memtone[ MAX_TONE ];  //アセンブラからアクセスする


/* Sin波 */
const  char EnvTone::wave_sin[WAVE_TBL_SIZE] PROGMEM = {
  0, 3, 6, 9, 12, 15, 17, 20, 22, 24, 26, 28, 29, 30, 31, 31,
  31, 31, 31, 30, 29, 28, 26, 24, 22, 20, 17, 15, 12, 9, 6, 3,
  0, -3, -6, -9, -12, -15, -17, -20, -22, -24, -26, -28, -29, -30, -31, -31,
  -31, -31, -31, -30, -29, -28, -26, -24, -22, -20, -17, -15, -12, -9, -6, -3,
};
/*三角波*/
const  char EnvTone::wave_tri[WAVE_TBL_SIZE]  PROGMEM = {
  0, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29,
  31, 30, 28, 26, 24, 22, 20, 18, 16, 14, 12, 10, 8, 6, 4, 2,
  0, -2, -4, -6, -8, -10, -12, -14, -16, -18, -20, -22, -24, -26, -28, -30,
  -31, -30, -28, -26, -24, -22, -20, -18, -16, -14, -12, -10, -8, -6, -4, -2

};
/*鋸波*/
const  char EnvTone::wave_saw[WAVE_TBL_SIZE]  PROGMEM = {
  0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
  15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 , 28 , 29, 30,
  -31, -30, -29, -28, -27, -26, -25, -24, -23, -22, -21, -20, -19, -18, -17, -16,
  -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1,  0,

};
/*矩形波*/
const  char EnvTone::wave_rect[WAVE_TBL_SIZE]  PROGMEM = {
  -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21,
  -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21, -21,
  21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
  21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21
};
/*クリップされたSin波*/
const char EnvTone::wave_clipsin[WAVE_TBL_SIZE]  PROGMEM = {
  0,  3,  6,  8, 11, 14, 17, 19, 20, 20, 20, 20, 20, 20, 20, 20,
  20, 20, 20, 20, 20, 20, 20, 20, 20, 19, 17, 14, 11,  8,  6,  3,
  0, -3, -6, -8, -11, -14, -17, -19, -20, -20, -20, -20, -20, -20, -20, -20,
  -20, -20, -20, -20, -20, -20, -20, -20, -20, -19, -17, -14, -11, -8, -6, -3,

};
/*全波整流Sin波*/
const char EnvTone::wave_abssin[WAVE_TBL_SIZE]  PROGMEM = {
  0,  3,  6,  8, 11, 14, 17, 19, 21, 23, 25, 27, 28, 29, 30, 30,
  31, 30, 30, 29, 28, 27, 25, 23, 21, 19, 17, 14, 11,  8,  6,  3,
  0,  3,  6,  8, 11, 14, 17, 19, 21, 23, 25, 27, 28, 29, 30, 30,
  31, 30, 30, 29, 28, 27, 25, 23, 21, 19, 17, 14, 11,  8,  6,  3,
};

EnvTone::EnvTone() {
  midi_pg_chg(0);  
  /*　MIDIポリフォニック用のqueue初期化 */
  for (int i = 0 ; i < MAX_REALTONE; i++) {
    voice_queue[i] = i;
    ch_midino[i] = 0;
  }
}


EnvTone::setup_hardware() {
  /* Use PWM OUTPUT */

#if (PWM_PIN == 3)
  //pinMode(3, OUTPUT);   //PWM　OCR2B出力  PD3
  DDRD |= 0x08;
  TCCR2A = 0x0;
  TCCR2B = 0x0;
  TCCR2A = (1 << COM2B1) | (1 << COM2B0) | (1 << WGM21) | (1 << WGM20);
  TCCR2B = (0 << CS21) | (1 << CS20) | (0 << WGM22);

#elif (PWM_PIN == 11)
  //pinMode(11, OUTPUT);   //PWM　OCR2A出力 PB3
  DDRB |= 0x8;
  TCCR2A = 0x0;
  TCCR2B = 0x0;
  TCCR2A = (1 << COM2A1) | (1 << COM2A0) | (1 << WGM21) | (1 << WGM20);
  TCCR2B = (0 << CS21) | (1 << CS20) | (0 << WGM22);

#elif (PWM_PIN == 5)
  //pinMode(5, OUTPUT);   //PWM　OCR0B出力 PD5
  TIMSK0 = 0;
  DDRD |= 0x20;
  TCCR0A = 0x0;
  TCCR0B = 0x0;
  TCCR0A = (1 << COM0B1) | (1 << COM0B0) | (1 << WGM01) | (1 << WGM00);
  TCCR0B = (0 << CS01) | (1 << CS00) | (0 << WGM02);

#elif (PWM_PIN == 6)
  //pinMode(6, OUTPUT);   //PWM　OCR0A出力 PD6
  TIMSK0 = 0;
  DDRD |= 0x40;
  TCCR0A = 0x0;
  TCCR0B = 0x0;
  TCCR0A = (1 << COM0A1) | (1 << COM0A0) | (1 << WGM01) | (1 << WGM00);
  TCCR0B = (0 << CS01) | (1 << CS00) | (0 << WGM02);
#endif

  /* Timer 1 CTC mode clkI/O */
  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1 = 0;

#if  (PWM_HZ == 24)
  OCR1A = 666; //24KHz
#elif  (PWM_HZ == 20)
  OCR1A = 799; //20KHz
#elif (PWM_HZ == 16)
   OCR1A = 999; //16KHz
#endif

  TCCR1A = (1 << COM1A0);
  TCCR1B = (1 << WGM12) | (1 << CS10);
  TIMSK1 = 0;
  TIMSK1 |= (1 << OCIE1A);    //Timer2 enable

}


EnvTone::note_on(uint8_t ch, uint8_t no, uint8_t vel) {
  ch &= 0x0f;
  memtone[ch].tone_on(no);
  memtone[ch - 1].tone_on(no);


}

EnvTone::note_off(uint8_t ch) {
  memtone[ch].tone_off();
}


EnvTone::set_wave(uint8_t ch , wavetype i) {
  uint16_t wave;
  switch (i) {
    case SIN:
      wave = wave_sin;
      break;
    case CLIP_SIN:
      wave = wave_clipsin;
      break;
    case RECT:
      wave = wave_rect;
      break;
    case TRI:
      wave = wave_tri;
      break;
    case SAW:
      wave = wave_saw;
      break;
    case ABS_SIN:
      wave = wave_abssin;
      break;
    default:
      break;
  }
  memtone[ch].set_wave(wave);
}



EnvTone::set_envelope(uint8_t ch, uint8_t atk, uint8_t decy, uint8_t sul, uint8_t sus, uint8_t rel, uint8_t tl, uint8_t mul) {
  ch &= 0x0f;
  atk &= 0x0f;
  decy &= 0x0f;
  sul &= 0x1f;
  sus &= 0x0f;
  rel &= 0x0f;
  tl &= 0x31;
  mul &= 0x1f;
  memtone[ch].set_envelope(atk, decy, sul, sus, rel, tl, mul);
}


EnvTone::set_tone(uint8_t ch , uint8_t *dat) {
  ch *= 2;
  memtone[ch].set_envelope( dat[0],  dat[1],  dat[2],  dat[3],  dat[4],  dat[5],  dat[6]);
  set_wave(ch, (wavetype)dat[7]);
  ch++;
  memtone[ch].set_envelope( dat[8],  dat[9],  dat[10],  dat[11],  dat[12],  dat[13],  dat[14]);
  set_wave(ch, (wavetype)dat[15]);
}

EnvTone::midi_set_tone(uint8_t * dat) {
  for (uint8_t  i = 0; i < MAX_REALTONE; i++) {
    set_tone( i, dat);
  }
}

EnvTone::midi_pg_chg(uint8_t no) {
   if (no > MAX_DEFAULT_TONE)
    no = MAX_DEFAULT_TONE - 1;
  midi_set_tone(default_tone[no]);
}


EnvTone::midi_command(uint8_t com, char dat1, char dat2, char dat3) {

  uint8_t voice_ch;
  uint8_t ch = dat1 & 0x0f;

  if ( this->midi_state == MIDI_POLY) {  // PolyPhonic Mode
    if (ch == 0) {

      switch (com) {

        case MIDI_NOTE_ON:
          if (dat3 == 0) {  //ベロシティ0はノートオフ
            midi_note_off(dat2);

          } else {

            // キューから鳴らすチャンネル番号を得る
            if (active_voice_num == MAX_REALTONE) {
              voice_ch = voice_queue[voice_queue_top];
              memtone[voice_ch * 2].tone_off();
              memtone[voice_ch * 2 + 1].tone_off();
            } else {
              voice_ch = voice_queue[voice_queue_top++];
              if (voice_queue_top == MAX_REALTONE) {
                voice_queue_top = 0;
              }
              active_voice_num++;
            }
            ch_midino[voice_ch] = dat2;
            memtone[voice_ch * 2].tone_on(dat2);
            memtone[voice_ch * 2 + 1].tone_on(dat2);
            memtone[voice_ch * 2 + 1].change_tl( dat3 >> 2);

          }
          break;

        case MIDI_NOTE_OFF:
          midi_note_off(dat2);

          break;
        case MIDI_PG_CHG:
          midi_pg_chg(dat2);

        default:
          break;
      }
    }
  } else {
    switch (com) {

      case MIDI_NOTE_ON:

        if (dat3 == 0) {
          memtone[ch * 2].tone_off();
          memtone[ch * 2 + 1].tone_off();

        } else {
          memtone[ch * 2].tone_on( dat2 );
          memtone[ch * 2 + 1].tone_on(dat2);

        }
        break;

      case MIDI_NOTE_OFF:
        memtone[ch * 2].tone_off();
        memtone[ch * 2 + 1].tone_off();

        break;
      default:

        break;
    }
  }
}

EnvTone::midi_note_off(uint8_t midi_no) {
  for (uint8_t i = 0; i < MAX_REALTONE; i++) {
    if (ch_midino[i] == midi_no) {
      memtone[i * 2].tone_off();
      memtone[i * 2 + 1].tone_off();
      ch_midino[i] = 0;
      // キューへオフしたチャンネル番号を入れる
      voice_queue[voice_queue_tail++] = i;
      if (voice_queue_tail == MAX_REALTONE) {
        voice_queue_tail = 0;
      }
      active_voice_num--;

    }
  }
}

EnvTone::set_midistate(midistat s) {
  this->midi_state = s;
}

midistat EnvTone::get_midistate() {
  return this->midi_state;
}


EnvTone::change_atk(uint8_t ch, uint8_t atk) {
  memtone[ch].change_atk(atk);
}
EnvTone::change_decy(uint8_t ch, uint8_t decy) {
  memtone[ch].change_decy(decy);
}
EnvTone::change_sul(uint8_t ch, uint8_t sul) {
  memtone[ch].change_sul(sul * 2);
}
EnvTone::change_sus(uint8_t ch, uint8_t sus) {
  memtone[ch].change_sus(sus);
}
EnvTone::change_rel(uint8_t ch, uint8_t rel) {
  memtone[ch].change_rel(rel);
}

EnvTone::change_tl(uint8_t ch, uint8_t tl) {
  memtone[ch].change_tl(31 - tl);
}

EnvTone::change_mul(uint8_t ch, uint8_t mul) {
  memtone[ch].change_mul(mul);
}

EnvTone:: copy_tone() {
  for (int i = 0 ; i < MAX_REALTONE; i ++) {
    memtone[i * 2].set_atk( memtone[0].get_atk());
    memtone[i * 2].set_decy( memtone[0].get_decy());
    memtone[i * 2].set_sul( memtone[0].get_sul());
    memtone[i * 2].set_sus( memtone[0].get_sus());
    memtone[i * 2].set_rel( memtone[0].get_rel());
    memtone[i * 2].set_tl( memtone[0].get_tl());
    memtone[i * 2].set_mul( memtone[0].get_mul());
    memtone[i * 2].set_wave( memtone[0].get_wave());

    memtone[i * 2 + 1].set_atk( memtone[1].get_atk());
    memtone[i * 2 + 1].set_decy( memtone[1].get_decy());
    memtone[i * 2 + 1].set_sul( memtone[1].get_sul());
    memtone[i * 2 + 1].set_sus( memtone[1].get_sus());
    memtone[i * 2 + 1].set_rel( memtone[1].get_rel());
    memtone[i * 2 + 1].set_tl( memtone[1].get_tl());
    memtone[i * 2 + 1].set_mul( memtone[1].get_mul());
    memtone[i * 2 + 1].set_wave( memtone[1].get_wave());

  }
}




