
#include "fmtone.h"


#define COMMAND_PIN  13
#define FIRST_TONE 0
// スキャンするポート番号と音色
//                       C   #C    D   #D   E   F  #F   G  #G   A  #A   B   C  #C   D  #D  E
uint8_t pin_no[18] = {  19,  18,  17,  16, 15, 14, 12, 10,  9,  8,  7,  6,  5,  4,  3 , 2, 1, 0  };

// ユーザ定義音色例            
// (op1) FB , Atk ,Decy, SL, Sus, Rel, TL,Mul,Ws ,(op2) Atk ,Decy, SL, Sus, Rel, TL,Mul,Ws                  
static const uint8_t sample_tone[17] = { 2,15, 9, 4, 3, 0,17,  3, 1,  15, 8, 5, 3, 8, 0,  1, 0,};


uint8_t state[18];
uint8_t note_no[18];
int pg_no;
uint8_t pg_state = 0;
int j = 48;


void setup() {
  // put your setup code here, to run once:

/*    ライブラリset up -------------------------------------------------*/

  FMTONE.setup_hardware();             //ハードウェア初期化
  
//FMTONE.set_midistate(MIDI_POLY);     //ポリフォニックモード(default)
// FMTONE.midi_pg_chg(4);              //プリセット音色番号０
 FMTONE.midi_set_tone(sample_tone);   //ユーザ定義音色ロード
  TIMSK0 = 0;                           //Timre0停止　停止しなくてもOK
/* --------------------------------------------------------------------- */

/* キーボード入力Port設定 */
  for (int i = 0; i < 18; i++) {
    pinMode(pin_no[i], INPUT_PULLUP);
    state[i] = 0;
  }
/* コマンドキー */
  pinMode(COMMAND_PIN, INPUT_PULLUP);
}


void loop() {
  int command;
  /* key scan */
  for (int i = 0; i < 18; i++) {
    if (HIGH == digitalRead(pin_no[i])) {

      if (state[i] == 1) {
        state[i] = 0;
        FMTONE.midi_command(0x90, 0x90, note_no[ i], 0);  //Note Off
      } else {
        if (state[i] > 1)
          state[i] = state[i] - 1;
      }
    } else {
      if (state[i] == 0) {
        state[i] = 10;
        uint8_t note = i + j + FIRST_TONE;
        note_no[i] = note;
        FMTONE.midi_command(0x90, 0x90, note, 120);       //Note on 
      }
    }

    /* コマンドキー 押下 */
    
    if (digitalRead(COMMAND_PIN) == LOW) {
      if (pg_state == 0) {
        pg_state = 1;
        while (1) {       //コマンドキーが押されるまでループ
          
          for ( command = 0; command < 15; command++) {
            if (digitalRead(pin_no[command]) == LOW)
              break;
          }
          if (command < 14)
            break;
        }

        switch (command) {
          case 0:     //key C   Program Change -1
            pg_no--;
            if (pg_no < 0)
              pg_no = MAX_DEFAULT_TONE - 1;
            FMTONE.midi_command(0xC0, 0xC0, pg_no, 0);
            break;

          case 1:     //key #C  Program Change +1
            pg_no++;
            if (pg_no > MAX_DEFAULT_TONE - 1)
              pg_no = 0;
            FMTONE.midi_command(0xC0, 0xC0, pg_no, 0);
            break;

          case 2:     //key D   octave--
            j -= 12;
            if (j < 0)
              j += 12;
            break;
          case 3:     //key #D octave--
            j += 12;
            if (j > 108)
              j -= 12;
            break;

          case 4:     //key E octave reset
            j = 60;
            break;

          case 5:     //key F
            j--;
            if (j < 0)
              j = 0;
            break;
          case 6:     //key #F
            j++;
            if (j > 108)
              j = 108;
            break;


          default:
            break;
        }
      }

    } else {
      if ( pg_state == 1) {
        pg_state = 0;
      }
    }
  }
}

