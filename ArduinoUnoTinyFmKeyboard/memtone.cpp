#include <avr/io.h>
#include <avr/pgmspace.h>
#include "MemTone.h"
#include "envtone_def.h"

const uint8_t envelope_cnt[16] PROGMEM = {0, 1, 2, 3, 4, 5, 7, 10, 13, 20, 29, 43, 64, 86, 128, 255};
//convert timer countervalue   endless,255,127,85,63,51,36,25,19,12,8,5,3,2,1,0




/* tone_freq[92] MIDI note No 24 to 127  2C to 9G   24MHz */
#if (F_PWM == 24)
const  uint16_t tone_freq[92] PROGMEM = {
22  ,24 ,25 ,27 ,28 ,30 ,32 ,33 ,35 ,38 ,40 ,42 ,45 ,47 ,50 ,53 ,56 ,60 ,63 ,67 ,71 ,75 ,80 ,84 ,89 ,95 ,100  ,106  ,113  ,119  ,126  ,134  ,142  ,150  ,159  ,169  ,179  ,189  ,200  ,212  ,225  ,238  ,253  ,268  ,284  ,300  ,318  ,337  ,357  ,378  ,401  ,425  ,450  ,477  ,505  ,535  ,567  ,601  ,636  ,674  ,714  ,757  ,802  ,850  ,900  ,954  ,1010 ,1070 ,1134 ,1201 ,1273 ,1349 ,2858 ,3028 ,3208 ,3398 ,3600 ,3815 ,4041 ,4282 ,4536 ,4806 ,5092 ,5395 ,5715 ,6055 ,6415 ,6797 ,7201 ,7629 ,8083 ,8563 ,

};
#elif (F_PWM == 20)
//20MHz
const  uint16_t tone_freq[92] PROGMEM = {
27  ,28 ,30 ,32 ,34 ,36 ,38 ,40 ,43 ,45 ,48 ,51 ,54 ,57 ,60 ,64 ,68 ,72 ,76 ,80 ,85 ,90 ,95 ,101  ,107  ,114  ,120  ,127  ,135  ,143  ,152  ,161  ,170  ,180  ,191  ,202  ,214  ,227  ,241  ,255  ,270  ,286  ,303  ,321  ,340  ,360  ,382  ,405  ,429  ,454  ,481  ,510  ,540  ,572  ,606  ,642  ,680  ,721  ,764  ,809  ,857  ,908  ,962  ,1019 ,1080 ,1144 ,1212 ,1285 ,1361 ,1442 ,1528 ,1618 ,3429 ,3633 ,3849 ,4078 ,4320 ,4577 ,4850 ,5138 ,5444 ,5767 ,6110 ,6473 ,6858 ,7266 ,7698 ,8156 ,8641 ,9155 ,9699 ,10276  ,

};
#elif (F_PWM == 16)
const  uint16_t tone_freq[92] PROGMEM = {
 33,35,38,40,42,45,47,50,53,56,60,63,67,71,75,80,84,89,95,100,106,113,119,126,134,142,150,159,169,179,189,201,213,225,239,253,268,284,301,319,338,358,379,401,425,451,477,506,536,568,601,637,675,715,758,803,851,901,955,1011,1072,1135,1203,1274,1350,1430,1516,1606,1701,1802,1909,2023,4286,4541,4811,5097,5401,5722,6062,6422,6804,7209,7638,8092,8573,9083,9623,10195,10801,11444,12124,12845,
};
#endif


MemTone::MemTone() {

}

static MemTone::tone_on( int tone) {
  int f;
  if (tone >= 24)
    tone -= 24;
  f = pgm_read_word(&(tone_freq[tone]));
  if(this->mul == 0){
    f = f >>1;
  }else{
    f = f * this->mul;
  }
  this->sin_step = f;
  this->sin_pos = 0;
  this->env_state = 1;
  this->env_cnt = 249;
  this->level = 0;
}

MemTone::tone_off() {
  this->env_state = 4;
}

MemTone::set_wave(char *wave) {

  this->wave_tbl = wave;
}

MemTone:: set_envelope( uint8_t atk, uint8_t decy, uint8_t sul, uint8_t sus, uint8_t rel,uint8_t tl,uint8_t mul) {
  this->atk = conv_count(atk);
  this->decy = conv_count(decy);
  this->sul = 31 - sul * 2;
  this->sus = conv_count(sus);
  this->rel = conv_count(rel);
  this->tl =  31 - tl;
  this->mul = mul;
}


uint8_t MemTone::conv_count(uint8_t d) {
  return pgm_read_byte(&(envelope_cnt[d & 0x0f]));
}

MemTone::change_atk(uint8_t atk) {
  this->atk = conv_count(atk);
}
MemTone::change_decy(uint8_t decy) {
  this->decy = conv_count(decy);
}
MemTone::change_sul(uint8_t sul) {
  this->sul  = (sul*2 );
}
MemTone::change_sus(uint8_t sus) {
  this->sus = conv_count(sus);
}
MemTone::change_rel(uint8_t rel) {
  this->rel = conv_count(rel);
}
MemTone::change_tl(uint8_t tl){
  this->tl = tl;
}
MemTone::change_mul(uint8_t mul){
  this->mul = mul;
}


MemTone::set_atk(uint8_t atk) {
  this->atk = (atk);
}
MemTone::set_decy(uint8_t decy) {
  this->decy = (decy);
}
MemTone::set_sul(uint8_t sul) {
  this->sul  = sul;
}
MemTone::set_sus(uint8_t sus) {
  this->sus = (sus);
}
MemTone::set_rel(uint8_t rel) {
  this->rel = (rel);
}
MemTone::set_tl(uint8_t tl){
  this->tl = tl;
}

MemTone::set_mul(uint8_t mul){
  this->mul = mul;
}

    uint8_t MemTone::get_atk(){
      return this->atk;
    }
    uint8_t MemTone::get_decy(){
      return this->decy;
    }
    uint8_t MemTone::get_sul(){
      return this->sul;
    }
    uint8_t MemTone::get_sus(){
      return this->sus;
    }
    
    uint8_t MemTone::get_rel(){
      return this->rel;
    }
    uint8_t MemTone::get_tl(){
      return this->tl;
    }
    uint8_t MemTone::get_mul(){
      return this->mul;
    }
    char * MemTone::get_wave(){
      return this->wave_tbl;
    }







