/*
 * 最大発音数
 * 
 */
#define MAX_REALTONE 5

#define MAX_TONE  (MAX_REALTONE * 2)


/*
 * サンプリング周波数,
 *  16,20,24
 */

#define F_PWM  24


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
