/*
 * 最大発音数 default= 
 * sampling周波数20MHzなら 5 から　6
 */

#define  MAX_MIDITONE 5



#define SAMPLE_VAL  64
#define PWM_KHZ  24

//#define CLIP


/*
 * PWM_PIN 出力PINの選択  3,5,6,11
 *      3  Timer2 OCR2B
 *      5  Timer0 OCR0B
 *      6  Timer0 OCR0A 
 *      11 Timer2 OCR2A
 *      
 *      Timer0(Pin5 or Pin6)を指定すると
 *      delay()等のTimer0を使った時間管理が出来なくなります
 *       
 */


#define PWM_PIN 11


