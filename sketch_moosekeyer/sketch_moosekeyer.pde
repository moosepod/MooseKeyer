#define LEFT_IN    7
#define RIGHT_IN   6

// This sketch drives a combo keyer/code oscilator
// See associated SCHEMATIC file for schematic

int left = 0;
int right = 0;

void setup() {
  pinMode(LEFT_IN, INPUT);
  pinMode(RIGHT_IN, INPUT);
  
  Serial.begin(9600);
  Serial.println("Loaded");
}

void both_pressed() {
  Serial.println("lr");
}

void left_pressed() {
  Serial.println("l");
}

void right_pressed() {
  Serial.println("r");
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
