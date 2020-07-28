#include "fmtone.h"

void midi_sysEx(uint8_t * sysex_mes, uint8_t dat_len) {
  uint8_t Data[4];
  uint8_t a, c;
  uint8_t j;
  int f;
  int i;
  uint8_t l;
  int ch;
  int adr;


  if (dat_len < 8) {
    Data[0] = sysex_mes[1];
    Data[1] = sysex_mes[2];
    Data[2] = sysex_mes[3];
    Data[3] = sysex_mes[4];
    l = sysex_mes[5];

    if (l & 0x04) {
      Data[1] += 0x80;
    }
    if (l & 0x02) {
      Data[2] += 0x80;
    }
    if (l & 0x01) {
      Data[3] += 0x80;
    }
    switch (Data[0]) {
      case 2:
        if(Data[1] == 0){
          FMTONE.set_midistate(MIDI_MONO);
        }else if (Data[1]== 1){
          FMTONE.set_midistate(MIDI_POLY);
          }else {
            FMTONE.set_midistate(MIDI_POLY);
            FMTONE.copy_tone();
          }

      case 10:
         //        tone_reg[Data[1] * 30 + Data[2] ] = Data[3];
        //        write_burst();
        if (Data[1] <7) {
           
          a = Data[1] *2 + ((Data[2]-2)/7);  
          switch ((Data[2]-2) % 7) {
            case 0: //SR
              FMTONE.change_sus(a, Data[3] >> 4);

              break;

            case 1: //RR,DR
              FMTONE.change_rel(a,Data[3] >>4);
              FMTONE.change_decy(a,Data[3] & 0x0f);

              break;
            case 2: //AR,SL
              FMTONE.change_atk(a,Data[3] >>4);
              FMTONE.change_sus(a,Data[3] & 0x0f);
              break;
            case 3://TL
              FMTONE.change_tl(a,31-(Data[3] >> 2));
              break;
            case 5: //mul
              FMTONE.change_mul(a,Data[3] >>4);
              break;
            case 6: //WS FB
              FMTONE.set_wave(a, (int)((Data[3] >>3 & 0x07)));
              FMTONE.change_fb(  a, Data[3] & 0x07);
              break;

            default:
              break;
          }
          if(MIDI_POLY ==  FMTONE.get_midistate()){
           FMTONE.copy_tone();
          }
        }
        default:
        break;
    }
  }
}


