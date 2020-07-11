#include <avr/io.h>


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

    

  public:
    MemTone();
    tone_on( int tone);
    tone_off();
    set_wave(char *wave);
    set_envelope( uint8_t atk, uint8_t decy, uint8_t sul, uint8_t sus, uint8_t rel,uint8_t tl,uint8_t mul);

    MemTone::change_atk(uint8_t atk);
    MemTone::change_decy(uint8_t decy);
    MemTone::change_sul(uint8_t sul);
    MemTone::change_sus(uint8_t sus);
    MemTone::change_rel(uint8_t rel);
    MemTone::change_tl(uint8_t vol);
    MemTone::change_mul(uint8_t mul);
    MemTone::change_fb(uint8_t fb);

    MemTone::set_atk(uint8_t atk);
MemTone::set_decy(uint8_t decy);
MemTone::set_sul(uint8_t sul);
MemTone::set_sus(uint8_t sus);
MemTone::set_rel(uint8_t rel);
MemTone::set_tl(uint8_t tl);
MemTone::set_mul(uint8_t mul);
MemTone::set_fb(uint8_t fb);


    uint8_t MemTone::get_atk();
    uint8_t MemTone::get_decy();
    uint8_t MemTone::get_sul();
    uint8_t MemTone::get_sus();
    uint8_t MemTone::get_rel();
    uint8_t MemTone::get_tl();
    uint8_t MemTone::get_mul();
    uint8_t MemTone::get_fb();
    char * MemTone::get_wave();
  private:

    uint8_t conv_count(uint8_t d);

};
