#include "memtone.h"
#include "fmtone_def.h"

#define WAVE_TBL_SIZE  64
#define TONE_DATLEN    17


#define MAX_DEFAULT_TONE    6


enum midistat {MIDI_POLY, MIDI_MONO};
enum wavetype {SIN, CLIP_SIN, TRI, SAW, RECT, ABS_SIN};

class FmTone
{

  protected:
    static const  char wave_sin[];
    static const  char wave_rect[];
    static const  char wave_tri[];
    static const  char wave_clipsin[];
    static const  char wave_saw[];
    static const  char wave_abssin[];

  private:
    /* MIDI ポリフォニック発音割り振り用　*/
    uint8_t queue_cnt = 0;
    uint8_t voice_queue[MAX_MIDITONE];
    uint8_t voice_queue_top = 0;
    uint8_t voice_queue_tail = 0;

    uint8_t ch_midino[MAX_MIDITONE];
    uint8_t active_voice_num = 0;

  public:


    FmTone();
    setup_hardware();
    note_on(uint8_t, uint8_t, uint8_t);
    note_off(uint8_t );
    midi_command(uint8_t com, char dat1, char dat2, char dat3);
    midi_setwave(wavetype wave);

    set_midistate(midistat);
    midistat get_midistate();

    set_wave(uint8_t, wavetype );
    set_envelope(uint8_t ch, uint8_t atk, uint8_t decy, uint8_t sul, uint8_t sus, uint8_t rel, uint8_t tl, uint8_t mul);

    set_tone(uint8_t ch , uint8_t *);
    midi_set_tone(uint8_t *);
    midi_pg_chg(uint8_t);

    change_atk(uint8_t ch, uint8_t atk);

    change_decy(uint8_t ch, uint8_t decy);
    change_sul(uint8_t ch, uint8_t sul);

    change_sus(uint8_t ch, uint8_t sus);
    change_rel(uint8_t ch, uint8_t rel);
    change_tl(uint8_t ch, uint8_t tl);
    change_mul(uint8_t ch, uint8_t mul);
    change_fb(uint8_t ch, uint8_t fb);
    copy_tone();

  private:

    midi_note_off(uint8_t);
    midistat midi_state = MIDI_POLY;

};

extern FmTone FMTONE;

