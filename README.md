# ArduinoUno  簡易FM音源
ArduinoUnoで２オペレータのFM音源を実現するライブラリと
入力ポートにタクトスイッチを接続して作った簡易キーボードのスケッチ例

![SANY0243](https://user-images.githubusercontent.com/28349102/85951556-bae89f00-b99e-11ea-81ff-e492c51760d5.JPG)

##  仕様

Timer1を使いサンプル数64の波形データを2オペレータのFM音源の直列アルゴリズムとして合成しTimer0かTimer2を使ったPWMから出力します  
発音数や出力ポート等の各種設定は**fmtone_def.h**で定義しています。

### FM音源
2オペレータ直列アルゴリズムのみ  
~~FeedBackは処理時間の関係で断念しました  
代わりに~~基本波形を6種類選べます。
- Sin波
-三角波
-鋸波
-矩形波
-クリップされたSin波
-全波整流Sin波








### 出力可能PIN

|pint No| Timer | 出力レジスタ|
|:--|    --|--:|
|PIN3  |Timer2|  OCR2B|
|PIN5  |Timer0  |OCR0B|
|PIN6  |Timer0  |OCR0A |
|PIN11 |Timer2  |OCR2A  |

Timer0を使用するとdelay()等の時間管理が使えなくなります  
### サンプリング周波数、最大発音数
サンプリング周波数と最大発音数はfmtone_def.hで  
MAX_MIDITONEとPWM_KHZで指定します
下は発音数に対する最大サンプリング周波数です。


|発音数　MAX_MIDITONE|最大サンプリング周波数 PWM_KHZ　|
|      --        |        --              |
|2| 51    |
|3|38|
|4|30|
|5|24|
|6|21|
|7|18|
|8|16|

あくまで発音可能な最大周波数なので、-1ぐらいの値にしておいた方が無難です
 　



### エンベロープ
    attack,
    Decey,
    Sutain level,
    Sustain,
    Release　
            sustain level  0 to 31  
            other          0 to 15

## インターフェイス

#### FMTONE.setup_hardware()
    タイマ等ハードウェアの設定

#### FMTONE.set_midistate(miditype)
    miditype:  
            MIDI_POLY  MIDIチャンネル1 4音ポリフォニックモード
            MIDI_MONO  MIDIチャンネル1～4 モノフォニックモード
#### FMTONE.midi_pg_chg(program_no)
    program_no
      0 シンセトランペット
      1 トランペット
      2 Bell
      3
      4 シンセリード
      5
      6


#### FMTONE.midi_set_tone(tone)
    ユーザ定義音色を全チャンネルすべてに設定
    uint8_t tone[17]=
    FeedBack        0-7
    OP1
      Attack Rate   0-15
      Decey Rate    0-15
      Sustain level 0-15
      Sustain Rate  0-15
      Release Rate  0-15
      Total level   0-31
      wavetype      0-4

    OP2   
    Attack Rate   0-15
    Decey Rate    0-15
    Sustain level 0-15
    Sustain Rate  0-15
    Release Rate  0-15
    Total level   0-31
    wavetype      0-5    

    :wavetype
    0- Sin波
    1-クリップされたSin波
    2-三角波
    3-鋸波
    4-矩形波
    5-全波整流Sin波    

    enum wavetype {SIN, CLIP_SIN, TRI, SAW, RECT, ABS_SIN};  

    波形データはFMTONE.cppでcharの64byteの配列に置いていますので
    適当なデータに置き換えて鳴らせます。

#### FMTONE.set_tone(uint8_t ch , uint8_t tone[16])
    MIDIチャンネル指定音色設定、パラメータはチャンネル以外は
    FMTONE.midi_set_tone(tone)と同じ



#### FMTONE.midi_command(com, dat1, dat2, dat3)
    MIDIコマンド送信
    0x80 NOTE OFF
    0x90 NOTE ON
    0xCO プログラムチェンジ(0～5)

     のみ実装



## あとがき
Arduino Uno を使ったガジェット等でTONE()の音色じゃ物足りないと波形メモリ音源をつくったのですが、出力を次のチャンネルの読み出しポイントに加算すればFM音源になるのではと思い作って見ました、結構重い処理をしているのでアプリケーションにどれぐらい回せるのか問題ですが結構良い音がなっています、ただPWMの周波数とサンプリング周波数が低いので
澄んだ音色はなかなか出ません。  
出力にCRのローパスフィルタを入れると音質がマイルドになります

スケッチ例のキーボードは、ブレッドボードにタクトスイッチを挿して
ArduinoUnoの入力をPULL_UPに設定して押した時にGNDへ落ちる様にして配列に登録したキーをスキャンして対応する音を鳴らしています。
A13PINはコマンドキーで、一度押した後に左列からプログラムチェンジ、
オクターブシフトに割り当てています。

![SANY0244](https://user-images.githubusercontent.com/28349102/85951851-cdfc6e80-b9a0-11ea-8f47-9e4fe3c330a3.JPG)
