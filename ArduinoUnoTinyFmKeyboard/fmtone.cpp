#include <avr/io.h>
#include <avr/pgmspace.h>

#include "FmTone.h"
#include "deftone.h"
#include "tone_freq.h"

#define MIDI_NOTE_OFF        0x80
#define MIDI_NOTE_ON         0x90
#define MIDI_COMMAND_PIN     0xC0


const uint8_t envelope_cnt[16] PROGMEM = {0, 1, 2, 3, 4, 5, 7, 10, 13, 20, 29, 43, 64, 86, 128, 255};
                                         //endless,255,127,85,63,51,36,25,19,12,8,5,3,2,1,0

struct FmOperator {
    uint8_t fb;
    uint8_t fb_val;

    uint8_t atk;
    uint8_t decy;
    uint8_t sul;
    uint8_t sus;
    uint8_t rel;

    uint8_t  tl;
    uint8_t mul;
    uint16_t wave_tbl;

    uint16_t sin_pos;
    uint16_t sin_step;

    uint8_t env_state;
    uint8_t env_cnt;
    uint8_t env_step;
    uint8_t level;
};

FmTone FMTONE;
extern FmOperator fm_operator[ MAX_MIDITONE * 2 ];  //アセンブラからアクセスする

extern const char wave_sin[WAVE_TBL_SIZE];
extern const char wave_tri[WAVE_TBL_SIZE];
extern const char  wave_saw[WAVE_TBL_SIZE];
extern const char  wave_rect[WAVE_TBL_SIZE];
extern const char  wave_clipsin[WAVE_TBL_SIZE];
extern const char  wave_abssin[WAVE_TBL_SIZE];



FmTone::FmTone() {
  for (int i = 0; i < MAX_MIDITONE * 2 ; i ++) {
    fm_operator[i].wave_tbl = (wave_tri);
    set_envelope(i,15, 9, 9, 2, 5, 31, 1);

  }
  for (int i = 0 ; i < MAX_MIDITONE; i++) {
    voice_queue[i] = i;
    ch_midino[i] = 0;
  }
}


FmTone::setup_hardware() {
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

  uint16_t freq;
  freq = (160000 / PWM_KHZ + 5 ) / 10;  //浮動小数点ライブラリを使いたくない
  OCR1A = freq;

  TCCR1A = (1 << COM1A0);
  TCCR1B = (1 << WGM12) | (1 << CS10);
  TIMSK1 = 0;
  TIMSK1 |= (1 << OCIE1A);    //Timer2 enable

}





FmTone::set_wave(uint8_t ch , wavetype i) {
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
  fm_operator[ch].wave_tbl = (wave);
}

FmTone::midi_setwave(wavetype wave) {
  for (uint8_t i = 0; i < MAX_MIDITONE * 2; i++) {
    set_wave(i, wave);
  }
}

FmTone::set_envelope(uint8_t ch, uint8_t atk, uint8_t decy, uint8_t sul, uint8_t sus, uint8_t rel, uint8_t tl, uint8_t mul) {
  ch &= 0x0f;
  atk &= 0x0f;
  decy &= 0x0f;
  sul &= 0x1f;
  sus &= 0x0f;
  rel &= 0x0f;
  tl &= 0x31;
  mul &= 0x1f;
    fm_operator[ch].atk = conv_count(atk);
  fm_operator[ch].decy = conv_count(decy);
  if(sul == 15){
    fm_operator[ch].sul = 0;
  }else{
    fm_operator[ch].sul = 31 - sul * 2;
  }
  fm_operator[ch].sus = conv_count(sus);
  fm_operator[ch].rel = conv_count(rel);
  fm_operator[ch].tl =  31 - tl;
  fm_operator[ch].mul = mul;

}




FmTone::set_tone(uint8_t ch , uint8_t *dat) {
  ch *= 2;
  fm_operator[ch].fb = (dat[0] & 0x07);

  set_envelope(ch, dat[1],  dat[2],  dat[3],  dat[4],  dat[5],  dat[6],  dat[7] );
  set_wave(ch, (wavetype)dat[8]);
  ch++;
  set_envelope(ch, dat[9],  dat[10],  dat[11],  dat[12],  dat[13],  dat[14],  dat[15] );
  set_wave(ch, (wavetype)dat[16]);
}

FmTone::midi_set_tone(uint8_t * dat) {


  for (uint8_t  i = 0; i < MAX_MIDITONE; i++) {
    set_tone( i, dat);
  }

}

FmTone::midi_pg_chg(uint8_t no) {
  if (no > MAX_DEFAULT_TONE)
    no = MAX_DEFAULT_TONE - 1;
  midi_set_tone(default_tone[no]);

}


FmTone::midi_command(uint8_t com, char dat1, char dat2, char dat3) {

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
            if (active_voice_num == MAX_MIDITONE) {
              voice_ch = voice_queue[voice_queue_top];
                midi_note_off(dat2);
            } else {
              voice_ch = voice_queue[voice_queue_top++];
              if (voice_queue_top == MAX_MIDITONE) {
                voice_queue_top = 0;
              }
              active_voice_num++;
            }
            ch_midino[voice_ch] = dat2;
            int f;
            if (dat2 >= 24)
              dat2 -= 24;
            f = pgm_read_word(&(tone_freq[dat2]));
            if (fm_operator[voice_ch * 2].mul == 0) {
              f = f >> 1;
            } else {
              f = f * fm_operator[voice_ch * 2].mul;
            }
            fm_operator[voice_ch * 2].sin_step = f;
            fm_operator[voice_ch * 2].sin_pos = 0;
            fm_operator[voice_ch * 2].env_state = 1;
            fm_operator[voice_ch * 2].env_cnt = 249;
            fm_operator[voice_ch * 2].level = 0;
            fm_operator[voice_ch * 2].fb_val = 0;
            fm_operator[voice_ch * 2].env_step = fm_operator[voice_ch * 2].atk;
           

            f = pgm_read_word(&(tone_freq[dat2]));
            if (fm_operator[voice_ch * 2 + 1].mul == 0) {
              f = f >> 1;
            } else {
              f = f * fm_operator[voice_ch * 2 + 1].mul;
            }
            fm_operator[voice_ch * 2 + 1].sin_step = f;
            fm_operator[voice_ch * 2 + 1].sin_pos = 0;
            fm_operator[voice_ch * 2 + 1].env_state = 1;
            fm_operator[voice_ch * 2 + 1].env_cnt = 249;
            fm_operator[voice_ch * 2 + 1].level = 0;
            fm_operator[voice_ch * 2 + 1].fb_val = 0;
            fm_operator[voice_ch * 2 + 1].env_step = fm_operator[voice_ch * 2 + 1].atk;


            fm_operator[voice_ch * 2 + 1].tl = (  (dat3 >> 2) );

          }
          break;

        case MIDI_NOTE_OFF:
          midi_note_off(dat2);

          break;
        case MIDI_COMMAND_PIN:
          if (this->midi_state == MIDI_POLY) {
            midi_pg_chg(dat2);

          }
        default:
          break;
      }
    }
  } else {
    switch (com) {

      case MIDI_NOTE_ON:

        if (dat3 == 0) {
          if (ch_midino[ch ] == dat2) {
            //            fm_operator[ch * 2].tone_off();
            //            fm_operator[ch * 2 + 1].tone_off();
            fm_operator[ch * 2].env_state = 4;
            fm_operator[ch * 2].env_step = fm_operator[ch * 2].rel;

            fm_operator[ch * 2 + 1].env_state = 4;
            fm_operator[ch * 2 + 1].env_step = fm_operator[ch * 2+1].rel;

          }
        } else {
          int f;
          ch_midino[ch ] = dat2;
          if (dat2 >= 24)
            dat2 -= 24;
          f = pgm_read_word(&(tone_freq[dat2]));
          if (fm_operator[ch * 2].mul == 0) {
            f = f >> 1;
          } else {
            f = f * fm_operator[ch * 2].mul;
          }
          fm_operator[ch * 2].sin_step = f;
          fm_operator[ch * 2].sin_pos = 0;
          fm_operator[ch * 2].env_state = 1;
          fm_operator[ch * 2].env_cnt = 249;
          fm_operator[ch * 2].level = 0;
          fm_operator[ch * 2].fb_val = 0;
          fm_operator[ch * 2].env_step = fm_operator[ch * 2].atk;

          f = pgm_read_word(&(tone_freq[dat2]));
          if (fm_operator[ch * 2 + 1].mul == 0) {
            f = f >> 1;
          } else {
            f = f * fm_operator[ch * 2 + 1].mul;
          }
          fm_operator[ch * 2 + 1].sin_step = f;
          fm_operator[ch * 2 + 1].sin_pos = 0;
          fm_operator[ch * 2 + 1].env_state = 1;
          fm_operator[ch * 2 + 1].env_cnt = 249;
          fm_operator[ch * 2 + 1].level = 0;
          fm_operator[ch * 2 + 1].fb_val = 0;
          fm_operator[ch * 2 + 1].env_step = fm_operator[ch * 2 + 1].atk;

          fm_operator[ch * 2 + 1].tl = (  (dat3 >> 2) );
        }
        break;

      case MIDI_NOTE_OFF:
        if (ch_midino[ch ] == dat2) {
          //        fm_operator[ch * 2].tone_off();
          //        fm_operator[ch * 2 + 1].tone_off();
          fm_operator[ch * 2].env_state = 4;
          fm_operator[ch * 2].env_step = fm_operator[ch * 2].rel;

          fm_operator[ch * 2 + 1].env_state = 4;
          fm_operator[ch * 2 + 1].env_step = fm_operator[ch * 2 + 1].rel;
        }
        break;

      case MIDI_COMMAND_PIN:
        set_tone(ch, default_tone[dat2]);
        break;
      default:

        break;
    }
  }
}

FmTone::midi_note_off(uint8_t midi_no) {
  for (uint8_t i = 0; i < MAX_MIDITONE; i++) {
    if (ch_midino[i] == midi_no) {

      //      fm_operator[i * 2].tone_off();
      //      fm_operator[i * 2 + 1].tone_off();

      fm_operator[i * 2].env_state = 4;
      fm_operator[i * 2].env_step = fm_operator[i * 2].rel;

      fm_operator[i * 2 + 1].env_state = 4;
      fm_operator[i * 2 + 1].env_step = fm_operator[i * 2 + 1].rel;


      ch_midino[i] = 0;
      // キューへオフしたチャンネル番号を入れる
      voice_queue[voice_queue_tail++] = i;
      if (voice_queue_tail == MAX_MIDITONE) {
        voice_queue_tail = 0;
      }
      active_voice_num--;

    }
  }
}

FmTone::set_midistate(midistat s) {
  this->midi_state = s;
}

midistat FmTone::get_midistate() {
  return this->midi_state;
}

uint8_t FmTone::conv_count(uint8_t d) {
  return pgm_read_byte(&(envelope_cnt[d & 0x0f]));

}

FmTone::change_atk(uint8_t ch,uint8_t atk) {
  fm_operator[ch].atk = conv_count(atk);
}
FmTone::change_decy(uint8_t ch,uint8_t decy) {
  fm_operator[ch].decy = conv_count(decy);
}
FmTone::change_sul(uint8_t ch,uint8_t sul) {
  fm_operator[ch].sul  = (sul*2 );
}
FmTone::change_sus(uint8_t ch,uint8_t sus) {
  fm_operator[ch].sus = conv_count(sus);
}
FmTone::change_rel(uint8_t ch,uint8_t rel) {
  fm_operator[ch].rel = conv_count(rel);
}
FmTone::change_tl(uint8_t ch,uint8_t tl){
  fm_operator[ch].tl = tl;
}
FmTone::change_mul(uint8_t ch,uint8_t mul){
  fm_operator[ch].mul = mul;
}
FmTone::change_fb(uint8_t ch,uint8_t fb){

  if(fb == 7)
    fb = 8;     // 7で割る所を8で割っているので最大値のみ補正
  fm_operator[ch].fb = fb;
}

FmTone:: copy_tone() {
  for (int i = 0 ; i < MAX_MIDITONE; i ++) {
    fm_operator[i * 2].atk = fm_operator[0].atk;
    fm_operator[i * 2].decy = fm_operator[0].decy;
    fm_operator[i * 2].sul = fm_operator[0].sul;
    fm_operator[i * 2].sus = fm_operator[0].sus;
    fm_operator[i * 2].rel = fm_operator[0].rel;
    fm_operator[i * 2].tl = fm_operator[0].tl;
    fm_operator[i * 2].mul = fm_operator[0].mul;
    fm_operator[i * 2].wave_tbl =  fm_operator[0].wave_tbl;
    fm_operator[i * 2].fb = fm_operator[0].fb;

    fm_operator[i * 2 + 1].atk = fm_operator[1].atk;
    fm_operator[i * 2 + 1].decy = fm_operator[1].decy;
    fm_operator[i * 2 + 1].sul = fm_operator[1].sul;
    fm_operator[i * 2 + 1].sus = fm_operator[1].sus;
    fm_operator[i * 2 + 1].rel = fm_operator[1].rel;
    fm_operator[i * 2 + 1].tl = fm_operator[1].tl;
    fm_operator[i * 2 + 1].mul = fm_operator[1].mul;
    fm_operator[i * 2 + 1].wave_tbl =  fm_operator[1].wave_tbl;
    fm_operator[i * 2 + 1].fb = fm_operator[1].fb;

  }
}




