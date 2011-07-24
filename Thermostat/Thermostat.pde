/**
 * XBeeThermostat v1.0
 * Author: George Sudarkoff <g@sud.to>
 */

#include <EEPROM.h>
#include <XBee.h>
#include <math.h>

#include "utils.h"

int temperatureThresholdAddr = 0;   // EEPROM address of the temperature threshold parameter
float temperatureThreshold;         // temperature threshold (Celsius)
int humidityThresholdAddr = 4;      // EEPROM address of the humidity threshold parameter
float humidityThreshold;            // humidity threshold (RH%)

int humiditySensor = 0;             // humidity sensor, analog pin
int temperatureSensor = 1;          // temperoture sensor, analog pin
int relay = 4;                      // relay, digital pin
int statusLed = 13;                 // status LED, digital pin

double currentTemperature = 0.0;    // last temperature measurement
double currentHumidity = 0.0;       // last humidity measurement (NB! always measure temperature first)
boolean relayState = false;         // true = relay ON, false = OFF
long updateFrequency = 20 * 1000;   // take measurements every 20 seconds
double lastUpdate = 0.0;            // last time the measurements were taken

uint8_t payload[] = { 0, 0 };
XBee xbee = XBee();
XBeeAddress64 addr64 = XBeeAddress64(0x0, 0xffff); // broadcast the measurements
ZBTxRequest zbTx = ZBTxRequest(addr64, payload, sizeof(payload));
ZBTxStatusResponse txStatus = ZBTxStatusResponse();

// Read temperature sensor a number of times, average the readings and convert to Celsius
// NB! ALWAYS read temperature first, we use it to adjust humidity for better accuracy
double readTemperature(int samples, int wait) {
  double val = 0.0;
  double T = 0.0;
  for (int i = 0; i < samples; i++) {
    val = (5.0 * analogRead(temperatureSensor) * 100.0) / 1024.0;
    T += val;
    delay(wait);
  }
  T = T/samples;

  return T;
}

// Read humidity sensor a number of times, average the readings and convert to RH%
// NB! ALWAYS read temperature first, we use it to adjust humidity for better accuracy
double readHumidity(int samples, int wait) {
  double val = 0.0;
  double RH = 0.0;
  for (int i = 0; i < samples; i++) {
    val = 161 * (analogRead(humiditySensor) / 1024.0) - 25.8;
    RH += val;
    delay(wait);
  }
  // Average RH%
  RH = RH/samples;

  // Adjust for current ambient temperature
  RH /= (1.0546 - 0.0026 * currentTemperature);
  
  return RH;
}

boolean switchRelay(boolean state) {
  // change the state only if it differs
  if (relayState == !state) {
    digitalWrite(relay, state==true? HIGH: LOW);
    relayState = state;
  }
}

void sendMeasurements() {
  payload[0] = (uint8_t)floor(currentTemperature + 0.5);
  payload[1] = (uint8_t)floor(currentHumidity + 0.5);
  //payload[2] = (uint8_t)(relayState==true?1:0);
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
        flashLed(statusLed, 5, 50);
      } else {
        // the remote XBee did not receive our packet. is it powered on?
        flashLed(statusLed, 3, 300);
      }
    }      
  } else {
    // local XBee did not provide a timely TX Status Response -- should not happen
    flashLed(statusLed, 2, 50);
  }
}

void setup()
{
  pinMode(statusLed, OUTPUT);
  pinMode(relay, OUTPUT);

  //writeThreshold(temperatureThresholdAddr, 35.0);
  //writeThreshold(humidityThresholdAddr, 85.0);
  
  temperatureThreshold = readThreshold(temperatureThresholdAddr, 20.0, 60.0, 35.0);
  humidityThreshold = readThreshold(humidityThresholdAddr, 30.0, 100.0, 85.0);

  xbee.begin(9600);
}

// MAIN LOOP
void loop()
{
  if ((millis() - lastUpdate) > updateFrequency) {
    // Always read T first as we use it to adjust H for better accuracy
    currentTemperature = readTemperature(5, 500);
    currentHumidity = readHumidity(2, 500);

    // TODO: take humidity into account as well
    if (currentTemperature > temperatureThreshold) {
      switchRelay(true);
    }
    else {
      switchRelay(false);
    }

    sendMeasurements();

    lastUpdate = millis();
  }

  // Blink status LED every 7 seconds if the relay is ON
  if (!(millis() % 7000) && relayState) {
    flashLed(statusLed, 1, 50);
  }
}

