/**
 * XBeeThermostat
 * Author: George Sudarkoff <g@sud.to>
 */

#include <EEPROM.h>
#include <XBee.h>
#include <math.h>

// https://github.com/sudarkoff/hardwin
#include <hardwin.h>

#define XBEE
#define T_SENSOR
#define RH_SENSOR

//#define DEBUG

#define VERSION "v1.1"

int temperatureThresholdAddr = 0;   // EEPROM address of the temperature threshold parameter
float temperatureThreshold;         // temperature threshold (Celsius)
int humidityThresholdAddr = 4;      // EEPROM address of the humidity threshold parameter
float humidityThreshold;            // humidity threshold (RH%)
int thermostatHysteresisAddr = 8;   // EEPROM address of the thermostat hysteresis
float thermostatHysteresis = 3.0;   // thermostat hysteresis

int temperatureSensor = 0;          // temperoture sensor, analog pin
int humiditySensor = 2;             // humidity sensor, analog pin

int relay = 4;                      // relay, digital pin
int statusLed = 13;                 // status LED, digital pin

double currentTemperature = 0.0;    // last temperature measurement
double currentHumidity = 0.0;       // last humidity measurement (NB! always measure temperature first)
boolean relayState = false;         // true = relay ON, false = OFF

#ifdef DEBUG
long updateFrequency = 10000;       // take measurements every 10 seconds in DEBUG mode
#else
long updateFrequency = 2 * 60000;   // take measurements every 2 minutes
#endif
double lastUpdate = 0.0;            // last time the measurements were taken

uint8_t payload[] = { 0, 0, 0, 0 };
XBee xbee = XBee();
XBeeAddress64 addr64 = XBeeAddress64(0x0, 0xffff); // broadcast the measurements
ZBTxRequest zbTx = ZBTxRequest(addr64, payload, sizeof(payload));
ZBTxStatusResponse txStatus = ZBTxStatusResponse();

// Read temperature sensor a number of times, average the readings and convert to Celsius
// NB! ALWAYS read temperature first, we use it to adjust humidity for better accuracy
double readTemperature(int samples, int wait) {
#ifdef T_SENSOR
  double T = 0.0;
  // throw away first reading (for some reason it's often junk)
  analogRead(temperatureSensor);
  for (int i = 0; i < samples; i++) {
    delay(wait);
    double sensor = analogRead(temperatureSensor);
    double val = (5.0 * sensor * 100.0) / 1024.0;
#ifndef XBEE
    Serial.print(i);
    Serial.print(" - T reading: "); Serial.print(sensor);
    Serial.print(", T value: "); Serial.println(val);
#endif
    T += val;
  }
  T = T/samples;

  return T;
#else
  return 0.0;
#endif
}

// Read humidity sensor a number of times, average the readings and convert to RH%
// NB! ALWAYS read temperature first, we use it to adjust humidity for better accuracy
double readHumidity(int samples, int wait) {
#ifdef RH_SENSOR
  double RH = 0.0;
  // throw away first reading
  analogRead(humiditySensor);
  for (int i = 0; i < samples; i++) {
    delay(wait);
    double sensor = analogRead(humiditySensor);
    double val = 161 * (sensor / 1024.0) - 25.8;
#ifndef XBEE
    Serial.print(i);
    Serial.print(" - RH reading: "); Serial.print(sensor);
    Serial.print(", RH value: "); Serial.println(val);
#endif
    RH += val;
  }
  // Average RH%
  RH = RH/samples;

  // Adjust for current ambient temperature
  RH /= (1.0546 - 0.0026 * currentTemperature);
  
  return RH;
#else
  return 0.0;
#endif
}

boolean switchRelay(boolean state) {
  // change the state only if it differs
  if (relayState == !state) {
    digitalWrite(relay, state==true? HIGH: LOW);
    relayState = state;
  }
}

void sendMeasurements() {
#ifdef XBEE
  payload[0] = (uint8_t)floor(currentTemperature + 0.5);
  payload[1] = (uint8_t)floor(currentHumidity + 0.5);
  payload[2] = (uint8_t)((relayState==true)? 1: 0);
  xbee.send(zbTx);

  // after sending a tx request, we expect a status response
  // wait up to half second for the status response
  if (xbee.readPacket(500)) {
    // got a response!
    // should be a znet tx status            	
    if (xbee.getResponse().getApiId() == ZB_TX_STATUS_RESPONSE) {
      xbee.getResponse().getZBTxStatusResponse(txStatus);

      // get the delivery status, the fifth byte
      if (txStatus.getDeliveryStatus() == SUCCESS) {
        // success, time to celebrate
        hardwin::flashLed(statusLed, 5, 50);
      } else {
        // the remote XBee did not receive our packet. is it powered on?
        hardwin::flashLed(statusLed, 3, 300);
      }
    }      
  } else {
    // local XBee did not provide a timely TX Status Response -- should not happen
    hardwin::flashLed(statusLed, 2, 50);
  }
#else
#ifdef T_SENSOR
  Serial.print("Temperature: "); Serial.println(currentTemperature);
#endif
#ifdef RH_SENSOR
  Serial.print("Humidity: "); Serial.println(currentHumidity);
#endif
  Serial.print("Relay: "); Serial.println(relayState==true? "ON": "OFF");
#endif
}

void setup()
{
  pinMode(temperatureSensor, INPUT);
  pinMode(humiditySensor, INPUT);

  pinMode(statusLed, OUTPUT);
  pinMode(relay, OUTPUT);

  // This is an example of writing values to EEPROM
  //hardwin::EEPROM_write(temperatureThresholdAddr, 35.0);
  //hardwin::EEPROM_write(humidityThresholdAddr, 85.0);
  //hardwin::EEPROM_write(thermostatHysteresis, 3.0);

#ifdef DEBUG  
  temperatureThreshold = 20;
  humidityThreshold = 30;
  thermostatHysteresis = 1;
#else
#if 0
  hardwin::EEPROM_read(temperatureThresholdAddr, temperatureThreshold,
    static_cast<float>(20.0), static_cast<float>(60.0), static_cast<float>(35.0));
  hardwin::EEPROM_read(humidityThresholdAddr, humidityThreshold,
    static_cast<float>(30.0), static_cast<float>(100.0), static_cast<float>(85.0));
  hardwin::EEPROM_read(thermostatHysteresisAddr, thermostatHysteresis,
    static_cast<float>(0.0), static_cast<float>(30.0), static_cast<float>(3.0));
#endif
#endif

#ifdef XBEE
  xbee.begin(9600);
#else
  Serial.begin(9600);
  Serial.print("Temperature threshold: "); Serial.println(temperatureThreshold);
  Serial.print("Humidity threshold: "); Serial.println(humidityThreshold);
  Serial.print("Thermostat hysteresis: "); Serial.println(thermostatHysteresis);
#endif
}

// MAIN LOOP
void loop()
{
  if ((millis() - lastUpdate) > updateFrequency) {
    // Always read T first as we use it to adjust H for better accuracy
    currentTemperature = readTemperature(3, 500);
    currentHumidity = readHumidity(3, 500);

    // TODO: take humidity into account as well?
    if (currentTemperature > temperatureThreshold) {
      switchRelay(true);
    }
    else if (currentTemperature < temperatureThreshold - thermostatHysteresis) {
      switchRelay(false);
    }

    sendMeasurements();

    lastUpdate = millis();
  }

  // Blink status LED every 7 seconds when the relay is ON
  if (!(millis() % 7000) && relayState) {
    hardwin::flashLed(statusLed, 1, 50);
  }
}

