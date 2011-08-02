 // This sketch drives a combo keyer/code oscilator
// See associated SCHEMATIC file for schematic

#define DIT 1
#define DAH 3

// Sets the code oscilator tone frequency, in hz
#define TONE_IN_HZ      600

// WPM keyer defaults to on reset
#define INITIAL_WPM     20

// Set to DIT/DAH to configure paddles the way you want
#define LEFT_PADDLE     DIT
#define RIGHT_PADDLE    DAH

// Length to use to calculate WPM. "Paris"
// = dit dah dah dit (dit) dit dah (dit) dit dah dit (dit) dit dit (dit) dit dit dit (dah)
#define CANONICAL_WORD (DIT + DAH + DAH + DIT + DIT + DIT + DAH + DIT + DIT + DAH + DIT + DIT + DIT + DIT + DIT + DIT + DIT + DIT + DAH)

// Pin definitions
#define LEFT_IN        7
#define RIGHT_IN       6
#define TONE_OUT       5
#define ACTIVITY_LED  13

// States
#define STATE_KEYER_WAITING        0
#define STATE_SENDING_CW           1
#define STATE_KEYER_BOTH_PRESSED   2
#define STATE_CW_PAUSE             3

// Global variables
int  co_tone           = 700;
int  wpm               = 0;
int  dit_in_ms         = 0;
int  dah_in_ms         = 0;
int  left_len          = 0;
int  right_len         = 0;
int  last_pressed      = LEFT_PADDLE;
long last_pressed_at   = 0;
int  cw_was_sent       = 0;
int  state             = STATE_KEYER_WAITING;
int  base_state        = STATE_KEYER_WAITING;
long stop_cw_at        = 0;
byte ditdah_buffer     = B00000000;          // Accumulates dit/dahs for the current character
int  ditdah_buffer_len = 0;                  // Total length of current character
char cw_mapping[256];                        // Stores the associated character for each morse dit/dah set. Keyed on byte value.

void debug_log(char *m) {
  Serial.println(m);
}

void debug_log(int m) {
  Serial.println(m);
}

void setup_for_wpm(int new_wpm) {
  wpm = new_wpm;
  
  long min_in_ms = (long) 1000 * (long) 60;
  
  dit_in_ms = min_in_ms / (CANONICAL_WORD * wpm);
  dah_in_ms = dit_in_ms * 3;
  left_len  = LEFT_PADDLE  * dit_in_ms;
  right_len = RIGHT_PADDLE * dit_in_ms;
  
  debug_log("Setting wpm to ");
  debug_log(wpm);
  
  for (int i=0; i < 256; i++) {
    cw_mapping[i] = '?';
  }
  setup_cw_mappings();
}

int left = 0;
int right = 0;

void setup() {
  pinMode(LEFT_IN, INPUT);
  pinMode(RIGHT_IN, INPUT);
  
  pinMode(TONE_OUT, OUTPUT);
  pinMode(ACTIVITY_LED, OUTPUT);
  
  Serial.begin(9600);
  clear_ditdah_buffer();
  setup_for_wpm(INITIAL_WPM);
}

// Append a dit/dah to our current buffer. buffer is 1-prefixed
// to allow it to be converted to a unique int (otherwise .. and ... 
// aren't distinguishable)
void add_to_ditdah_buffer(int x) {
  if (ditdah_buffer_len < 8) {
    if (x == DAH) {
       bitSet(ditdah_buffer,ditdah_buffer_len);
    } else {
       bitClear(ditdah_buffer, ditdah_buffer_len);
    }
    
    bitSet(ditdah_buffer,ditdah_buffer_len+1);

    ditdah_buffer_len +=1;
  }
}

// Clear the ditdah buffer
void clear_ditdah_buffer() {
   ditdah_buffer = B00000000;
   ditdah_buffer_len = 0;
}

// If we're not already sending a CW pulse, start a pulse and set the timeout
// for the appropriate length
void start_cw(int length) {
  if (state != STATE_SENDING_CW) {    
    last_pressed_at = millis();
    cw_was_sent = 1;
    
    digitalWrite(ACTIVITY_LED,HIGH);
    tone(TONE_OUT, co_tone, 1000); // Never send tone longer than a second...
    stop_cw_at = millis() + length;
    state = STATE_SENDING_CW;
    
    if (length == dit_in_ms) {
        add_to_ditdah_buffer(DIT);
    } else {
        add_to_ditdah_buffer(DAH);
    }
  }
}

// Stop sending a pulse and shift to pausing between dit/dahs
void stop_cw() {
    state = STATE_CW_PAUSE;
    noTone(TONE_OUT);
    digitalWrite(ACTIVITY_LED,LOW);
    stop_cw_at = millis() + dit_in_ms;
}

// Start the appropriate CW pulse for the left paddle
void start_cw_left() {
   start_cw(left_len);
   last_pressed = LEFT_PADDLE;
}

// Convert a byte ditdah buffer into dits and dahs
char* ditdah_to_cw(byte ditdah, int len) {
  char cw[8];
  
  int i = 0;
  
  for (i = 0; i < len; i++) {
    if (bitRead(ditdah,i)==1) {
      cw[i] = '-';
    } else {
      cw[i] = '.';
    }
  }
  
  cw[i] = '\0';
  
  return cw;
}

void handle_new_char() {
  Serial.write("Char: ");
  Serial.print(ditdah_to_cw(ditdah_buffer,ditdah_buffer_len));
  Serial.print(" (");
  Serial.print(byte(cw_mapping[ditdah_buffer]));
  Serial.println(')');
  
  clear_ditdah_buffer();
}

// Start the appropriate CW pulse for the right paddle
void start_cw_right() {
  start_cw(right_len);
  last_pressed = RIGHT_PADDLE;
}

void loop() {
  left = digitalRead(LEFT_IN);
  right = digitalRead(RIGHT_IN);
  
  // Challenge -- single press actualy becomes double press, as long as other paddle is pressed while down.
  switch (state) {
    case STATE_KEYER_WAITING:
      // Waiting for paddle press in CW mode
      if (left == HIGH) {
          start_cw_left();
      } else if (right == HIGH) {
          start_cw_right();
      } else {
        if (cw_was_sent == 1 && millis() > last_pressed_at + dah_in_ms) {
           handle_new_char();
           cw_was_sent = 0;
        }
      }
      break;
    case STATE_SENDING_CW:
      // Currently sending CW dit/dahs 
      if (left == HIGH && right == HIGH) {
          base_state = STATE_KEYER_BOTH_PRESSED;
      }

      if (millis() > stop_cw_at) {
        stop_cw();
      }
      break;
    case STATE_CW_PAUSE:
      // Pausing between CW dit/dahs
      if (left == HIGH && right == HIGH) {
         base_state = STATE_KEYER_BOTH_PRESSED;
      }

      if (millis() > stop_cw_at) {
        state = base_state;
      }
      break;
    case STATE_KEYER_BOTH_PRESSED:
      // Both paddles are down while sending CW
      if (last_pressed == LEFT_PADDLE) {
        start_cw_right();
      } else {
        start_cw_left();
      }
      
      if (left == LOW || right == LOW) {
        base_state = STATE_KEYER_WAITING;
      }
      break;
  }
}

void add_cw_mapping(char* cw, char mapped_char) {
  byte b = B00000000;
  for (int i = 0; i < strlen(cw); i++) {
    if (cw[i] == '-') {
      bitSet(b,i);
    } else {
      bitClear(b,i);
    }
    bitSet(b,i+1);
  }
  
  cw_mapping[b] = mapped_char;
  Serial.println(mapped_char);
  Serial.println(b,BIN);
  Serial.println(b,DEC);
  
}

// Called at init to setup our mapping buffer
void setup_cw_mappings() {
  add_cw_mapping(".-",'A');
  add_cw_mapping("-...",'B');
  add_cw_mapping("-.-.",'C');
  add_cw_mapping("-..",'D');
  add_cw_mapping(".",'E');
}
