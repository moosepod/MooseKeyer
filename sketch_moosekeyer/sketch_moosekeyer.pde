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

// Global variablews
int co_tone         = 700;
int wpm             = 0;
int dit_in_ms       = 0;
int left_len        = 0;
int right_len       = 0;
int last_pressed    = LEFT_PADDLE;
int state           = STATE_KEYER_WAITING;
int base_state      = STATE_KEYER_WAITING;
int stop_cw_at      = 0;

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
  left_len  = LEFT_PADDLE  * dit_in_ms;
  right_len = RIGHT_PADDLE * dit_in_ms;
  
  debug_log("Setting wpm to ");
  debug_log(wpm);
}

int left = 0;
int right = 0;

void setup() {
  pinMode(LEFT_IN, INPUT);
  pinMode(RIGHT_IN, INPUT);
  
  pinMode(TONE_OUT, OUTPUT);
  pinMode(ACTIVITY_LED, OUTPUT);
  
  Serial.begin(9600);
  setup_for_wpm(INITIAL_WPM);
}

void send_cw(int length) {
  digitalWrite(ACTIVITY_LED,HIGH);
  tone(TONE_OUT, co_tone);
  delay(length);
  noTone(TONE_OUT);
  digitalWrite(ACTIVITY_LED,LOW);
  
  // Add the spacing
  delay(dit_in_ms);
}

void both_pressed() {
  debug_log("B");
  if (last_pressed == LEFT_PADDLE) {
    right_pressed();
    left_pressed();
  } else {
    left_pressed();
    right_pressed();
  }
  debug_log("  end b");
}

void left_pressed() {
  debug_log("L");
  send_cw(left_len);
  last_pressed = LEFT_PADDLE;
}

void right_pressed() {
  debug_log("R");
  send_cw(right_len);
  last_pressed = RIGHT_PADDLE;
}

void start_cw(int length) {
  if (state != STATE_SENDING_CW) {
    digitalWrite(ACTIVITY_LED,HIGH);
    tone(TONE_OUT, co_tone, 1000); // Never send tone longer than a second...
    stop_cw_at = millis() + length;
    state = STATE_SENDING_CW;
  }
}

void stop_cw() {
    state = base_state;
    noTone(TONE_OUT);
    digitalWrite(ACTIVITY_LED,LOW);
    delay(dit_in_ms);
}

void start_cw_left() {
   start_cw(left_len);
   last_pressed = LEFT_PADDLE;
}

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
      if (left == HIGH) {
          start_cw_left();
      } else if (right == HIGH) {
          start_cw_right();
      }
      break;
    case STATE_SENDING_CW:
      if (millis() > stop_cw_at) {
        stop_cw();
      }
      
      if (left == HIGH && right == HIGH) {
          base_state = STATE_KEYER_BOTH_PRESSED;
      }
      
      break;
    case STATE_KEYER_BOTH_PRESSED:
      if (last_pressed == LEFT_PADDLE) {
        start_cw_right();
      } else {
        start_cw_left();
      }
      
      if (left == LOW || right == LOW) {
        base_state = STATE_KEYER_WAITING;
      }
  }
}
