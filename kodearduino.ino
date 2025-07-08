#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>
#include <time.h>

// WiFi credentials
const char* ssid = "?";
const char* password = "hayoyoyo";

// Firebase config
const char* FIREBASE_API_KEY = "AIzaSyCLHtSN4T_yjCBoqjU0dKPojyxaUT3gNBo";
const char* FIREBASE_EMAIL = "tugasbesar@gmail.com";
const char* FIREBASE_PASSWORD = "tubes1234";
const char* DATABASE_URL = "https://tubesiot-3d0de-default-rtdb.firebaseio.com/";

String idToken = "";

// Waktu batas hadir
int batasJam = 7;
int batasMenit = 30;

// Pin konfigurasi
#define RST_PIN    22
#define SS_PIN     21
#define BUZZER     27
#define LED_HIJAU  14
#define LED_MERAH  12

MFRC522 mfrc522(SS_PIN, RST_PIN);
MFRC522::MIFARE_Key key;
MFRC522::StatusCode status;
int blocks[] = {4, 5, 6, 8, 9};
#define total_blocks  (sizeof(blocks) / sizeof(blocks[0]))

byte buffer[18];

String cleanString(String input) {
  input.trim();
  String result = "";
  for (int i = 0; i < input.length(); i++) {
    char c = input.charAt(i);
    if (isAlphaNumeric(c) || c == ' ' || c == '-' || c == '_') {
      result += c;
    }
  }
  result.trim();
  return result;
}

void setup() {
  Serial.begin(115200);
  SPI.begin(18, 19, 23, SS_PIN);
  mfrc522.PCD_Init();

  pinMode(BUZZER, OUTPUT);
  pinMode(LED_HIJAU, OUTPUT);
  pinMode(LED_MERAH, OUTPUT);

  digitalWrite(BUZZER, LOW);
  digitalWrite(LED_HIJAU, LOW);
  digitalWrite(LED_MERAH, LOW);

  Serial.print("Menghubungkan WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi Terhubung!");

  configTime(7 * 3600, 0, "pool.ntp.org"); // GMT+7
  loginFirebase();
}

void loop() {
  digitalWrite(LED_HIJAU, LOW);
  digitalWrite(LED_MERAH, LOW);

  if (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial()) return;

  String nama = "", nim = "", prodi = "", jurusan = "", jenis_kelamin = "";
  bool dataValid = true;

  for (byte i = 0; i < total_blocks; i++) {
    if (!ReadDataFromBlock(blocks[i], buffer)) {
      dataValid = false;
      break;
    }

    String data = String((char*)buffer);
    data = cleanString(data);

    switch (i) {
      case 0: nama = data; break;
      case 1: nim = data; break;
      case 2: prodi = data; break;
      case 3: jurusan = data; break;
      case 4: jenis_kelamin = data; break;
    }
  }

  if (!dataValid) {
    Serial.println("Gagal membaca data kartu!");
    gagalDeteksiFeedback();
    return;
  }

  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Gagal mendapatkan waktu");
    gagalDeteksiFeedback();
    return;
  }

  char timestamp[25];
  strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", &timeinfo);
  char yearStr[5];
  strftime(yearStr, sizeof(yearStr), "%Y", &timeinfo);

  String tahun = String(yearStr);
  String kelas = cleanString(prodi);
  kelas.replace(" ", "_");
  kelas.toLowerCase();

  String statusHadir = "Tepat Waktu";
  if (timeinfo.tm_hour > batasJam || (timeinfo.tm_hour == batasJam && timeinfo.tm_min > batasMenit)) {
    statusHadir = "Terlambat";
  }

  DynamicJsonDocument doc(512);
  doc["nama"] = nama;
  doc["nim"] = nim;
  doc["class"] = kelas;
  doc["jurusan"] = jurusan;
  doc["gender"] = jenis_kelamin;
  doc["timestamp"] = String(timestamp);
  doc["status"] = statusHadir;

  String jsonData;
  serializeJson(doc, jsonData);

  Serial.println("Data JSON:");
  Serial.println(jsonData);

  if (idToken != "") {
    HTTPClient http;
    String pushUrl = String(DATABASE_URL) + "/attendance/" + kelas + "/" + tahun + ".json?auth=" + idToken;
    http.begin(pushUrl);
    http.addHeader("Content-Type", "application/json");

    int httpResponseCode = http.POST(jsonData);
    Serial.print("HTTP Response Code: ");
    Serial.println(httpResponseCode);

    if (httpResponseCode > 0) {
      digitalWrite(LED_HIJAU, HIGH);
      tone(BUZZER, 1000, 200);
    } else {
      gagalDeteksiFeedback();
    }

    http.end();
  } else {
    gagalDeteksiFeedback();
  }

  delay(500);
  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();
}

bool ReadDataFromBlock(int blockNum, byte buffer[]) {
  memset(buffer, 0, 18);

  for (byte i = 0; i < 6; i++) key.keyByte[i] = 0xFF;

  status = mfrc522.PCD_Authenticate(MFRC522::PICC_CMD_MF_AUTH_KEY_A, blockNum, &key, &(mfrc522.uid));
  if (status != MFRC522::STATUS_OK) {
    Serial.print("Auth failed: ");
    Serial.println(mfrc522.GetStatusCodeName(status));
    return false;
  }

  byte tempBuffer[18];
  byte size = 18;
  status = mfrc522.MIFARE_Read(blockNum, tempBuffer, &size);
  if (status != MFRC522::STATUS_OK) {
    Serial.print("Read failed: ");
    Serial.println(mfrc522.GetStatusCodeName(status));
    return false;
  }

  for (byte i = 0; i < 18; i++) {
    buffer[i] = (tempBuffer[i] >= 32 && tempBuffer[i] <= 126) ? tempBuffer[i] : ' ';
  }
  buffer[17] = '\0';
  return true;
}

void loginFirebase() {
  HTTPClient http;
  String loginUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + String(FIREBASE_API_KEY);
  http.begin(loginUrl);
  http.addHeader("Content-Type", "application/json");

  String payload = "{\"email\":\"" + String(FIREBASE_EMAIL) + "\",\"password\":\"" + String(FIREBASE_PASSWORD) + "\",\"returnSecureToken\":true}";
  int httpCode = http.POST(payload);

  if (httpCode > 0) {
    String response = http.getString();
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, response);
    if (!error) {
      idToken = doc["idToken"].as<String>();
    }
  } else {
    Serial.println("Login Gagal");
    gagalDeteksiFeedback();
  }

  http.end();
}

void gagalDeteksiFeedback() {
  digitalWrite(LED_MERAH, HIGH);
  tone(BUZZER, 500, 200);
  delay(500);
  digitalWrite(LED_MERAH, LOW);
}
