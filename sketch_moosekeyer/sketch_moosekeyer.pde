 // This sketch drives a combo keyer/code oscilator
// See associated SCHEMATIC file for schematic

#define DIT 1
#define DAH 3

// Sets the code oscilator tone frequency, in hz
#define TONE_IN_HZ      700

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

// Global variablews
int co_tone         = 700;
int wpm             = 0;
int dit_in_ms       = 0;
int left_len        = 0;
int right_len       = 0;
int last_pressed    = LEFT_PADDLE;

void setup_for_wpm(int new_wpm) {
  wpm = new_wpm;
  
  long min_in_ms = (long) 1000 * (long) 60;
  
  dit_in_ms = min_in_ms / (CANONICAL_WORD * wpm);
  left_len  = LEFT_PADDLE  * dit_in_ms;
  right_len = RIGHT_PADDLE * dit_in_ms;
  
  Serial.print("Setting wpm to ");
  Serial.print(wpm);
  Serial.print(". Length is ");
  Serial.println(dit_in_ms);
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
  Serial.println(length);
  
  digitalWrite(ACTIVITY_LED,HIGH);
  tone(TONE_OUT, co_tone);
  delay(length);
  noTone(TONE_OUT);
  digitalWrite(ACTIVITY_LED,LOW);
  
  // Add the spacing
  delay(dit_in_ms);
}

void both_pressed() {
  if (last_pressed == LEFT_PADDLE) {
    right_pressed();
  } else {
    left_pressed();
  }
}

void left_pressed() {
  send_cw(left_len);
  last_pressed = LEFT_PADDLE;
}

void right_pressed() {
  send_cw(right_len);
  last_pressed = RIGHT_PADDLE;
}

void loop() {
  left = digitalRead(LEFT_IN);
  right = digitalRead(RIGHT_IN);
  
  if (left == HIGH && right == HIGH) {
      both_pressed();
  } else if (left == HIGH) {
      left_pressed();
  } else if (right == HIGH) {
      right_pressed();
  }
   
}
