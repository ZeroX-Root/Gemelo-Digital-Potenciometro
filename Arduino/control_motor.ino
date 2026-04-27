#include <SoftwareSerial.h>

// =========================
// Pines HC-05
// =========================
const int BT_RX = 2;
const int BT_TX = 3;
SoftwareSerial bluetooth(BT_RX, BT_TX);

// =========================
// Pines puente H (Canal A)
// ENA, IN1, IN2 → OUT1, OUT2
// =========================
const int ENA = 10;   // PWM
const int IN1 = 8;   // Dirección
const int IN2 = 9;   // Dirección

// =========================
// Potenciómetro
// =========================
const int POT_PIN = A0;

// =========================
// Variables de control
// =========================
int currentMode = 0; // 0 = físico, 1 = app
int appSpeed = 0;
int potValue255 = 0;
int lastSentPotValue = -1;
String inputBuffer = "";

// =========================
// Configuración
// =========================
void setup() {
  pinMode(ENA, OUTPUT);
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(POT_PIN, INPUT);

  Serial.begin(9600);
  bluetooth.begin(9600);

  // Dirección fija
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  analogWrite(ENA, 0);

  Serial.println("Sistema iniciado (Canal A)");
  bluetooth.println("READY");
}

// =========================
// Loop principal
// =========================
void loop() {
  readBluetoothCommands();

  if (currentMode == 0) {
    handlePhysicalMode();
  } else {
    handleAppMode();
  }
}

// =========================
// Leer Bluetooth
// =========================
void readBluetoothCommands() {
  while (bluetooth.available()) {
    char c = bluetooth.read();
    if (c == '\n') {
      inputBuffer.trim();
      if (inputBuffer.length() > 0) {
        processCommand(inputBuffer);
      }
      inputBuffer = "";
    } else {
      inputBuffer += c;
    }
  }
}

// =========================
// Procesar comandos
// =========================
void processCommand(String cmd) {
  Serial.print("Comando recibido: ");
  Serial.println(cmd);

  if (cmd == "M1") {
    currentMode = 0;
    Serial.println("Modo Fisico activado");
  }
  else if (cmd == "M2") {
    currentMode = 1;
    Serial.println("Modo App activado");
    applyMotorSpeed(appSpeed);
  }
  else if (cmd.startsWith("V")) {
    int value = cmd.substring(1).toInt();
    value = constrain(value, 0, 255);
    appSpeed = value;
    Serial.print("Velocidad App: ");
    Serial.println(appSpeed);
    if (currentMode == 1) {
      applyMotorSpeed(appSpeed);
    }
  }
  else if (cmd == "START") {
    Serial.println("Comando START recibido");
  }
}

// =========================
// Modo físico (potenciómetro)
// =========================
void handlePhysicalMode() {
  int rawPot = analogRead(POT_PIN);
  potValue255 = map(rawPot, 0, 1023, 0, 255);
  potValue255 = constrain(potValue255, 0, 255);

  applyMotorSpeed(potValue255);

  if (abs(potValue255 - lastSentPotValue) >= 2) {
    bluetooth.print("P");
    bluetooth.println(potValue255);
    Serial.print("Enviado a app: P");
    Serial.println(potValue255);
    lastSentPotValue = potValue255;
  }

  delay(50);
}

// =========================
// Modo app
// =========================
void handleAppMode() {
  applyMotorSpeed(appSpeed);
  delay(20);
}

// =========================
// Aplicar velocidad
// =========================
void applyMotorSpeed(int speedValue) {
  speedValue = constrain(speedValue, 0, 255);
  analogWrite(ENA, speedValue);
}