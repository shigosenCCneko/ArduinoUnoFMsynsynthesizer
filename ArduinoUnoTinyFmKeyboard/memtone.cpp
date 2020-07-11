#include <avr/io.h>
#include <avr/pgmspace.h>
#include  "memtone.h"
#include "fmtone_def.h"
#include "tone_freq.h"


const uint8_t envelope_cnt[16] PROGMEM = {0, 1, 2, 3, 4, 5, 7, 10, 13, 20, 29, 43, 64, 86, 128, 255}; //endless,255,127,85,63,51,36,25,19,12,8,5,3,2,1,0






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
  this->fb_val = 0;
  this->env_step = this->atk;



}

MemTone::tone_off() {
  this->env_state = 4;
  this->env_step = this->rel;

}

MemTone::set_wave(char *wave) {

  this->wave_tbl = wave;
}

MemTone:: set_envelope( uint8_t atk, uint8_t decy, uint8_t sul, uint8_t sus, uint8_t rel,uint8_t tl,uint8_t mul) {
  this->atk = conv_count(atk);
  this->decy = conv_count(decy);
  if(sul == 15){
    this->sul = 0;
  }else{
    this->sul = 31 - sul * 2;
  }
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
MemTone::change_fb(uint8_t fb){

  if(fb == 7)
    fb = 8;     // 7で割る所を8で割っているので最大値のみ補正
  this->fb = fb;
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
MemTone::set_fb(uint8_t fb){
  this->fb = fb;
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
    uint8_t MemTone::get_fb(){
      return this->fb;
    }
    char * MemTone::get_wave(){
      return this->wave_tbl;
    }







