/**
 * XBeeThermostat
 * Author: George Sudarkoff <g@sud.to>
 */

#include <EEPROM.h>
#include <XBee.h>
#include <math.h>

#include <hardwin.h>

// Configuration
#define VERSION "v1.1"
#define DEBUG
#define XBEE
#define T_SENSOR
#define RH_SENSOR

// Pin assignments
int temperatureSensor = 0;          // temperoture sensor, analog pin
int humiditySensor = 2;             // humidity sensor, analog pin

int relay = 4;                      // relay, digital pin
int statusLed = 13;                 // status LED, digital pin

// EEPROM stuff
float temperatureThreshold = 35.0;  // temperature threshold (Celsius)
int temperatureThresholdAddr = 0;   // EEPROM address of the temperature threshold parameter
float humidityThreshold = 85.0;     // humidity threshold (RH%)
int humidityThresholdAddr = temperatureThresholdAddr + sizeof(temperatureThreshold);
                                    // EEPROM address of the humidity threshold parameter
float thermostatHysteresis = 3.0;   // thermostat hysteresis
int thermostatHysteresisAddr = humidityThresholdAddr + sizeof(humidityThreshold);
                                    // EEPROM address of the thermostat hysteresis

// Some globals
double currentTemperature = 0.0;    // last temperature measurement
double currentHumidity = 0.0;       // last humidity measurement (NB! always measure temperature first)
boolean relayState = false;         // true = relay ON, false = OFF

#ifdef DEBUG
long updateFrequency = 10000;       // take measurements every 10 seconds in DEBUG mode
#else
long updateFrequency = 2 * 60000;   // take measurements every 2 minutes
#endif
double lastUpdate = 0.0;            // last time the measurements were taken

boolean switchRelay(boolean state) {
  // change the state only if it differs
  if (relayState == !state) {
    digitalWrite(relay, state==true? HIGH: LOW);
    relayState = state;
  }
}

void setup()
{
  pinMode(temperatureSensor, INPUT);
  pinMode(humiditySensor, INPUT);

  pinMode(statusLed, OUTPUT);
  pinMode(relay, OUTPUT);

  // This is an example of writing values to EEPROM
  //hardwin::EEPROM_write(temperatureThresholdAddr, static_cast<float>(35.0));
  //hardwin::EEPROM_write(humidityThresholdAddr, static_cast<float>(85.0));
  //hardwin::EEPROM_write(thermostatHysteresisAddr, static_cast<float>(3.0));

  hardwin::EEPROM_read(temperatureThresholdAddr, temperatureThreshold,
    static_cast<float>(20.0), static_cast<float>(60.0), static_cast<float>(35.0));
  hardwin::EEPROM_read(humidityThresholdAddr, humidityThreshold,
    static_cast<float>(30.0), static_cast<float>(100.0), static_cast<float>(85.0));
  hardwin::EEPROM_read(thermostatHysteresisAddr, thermostatHysteresis,
    static_cast<float>(1.0), static_cast<float>(10.0), static_cast<float>(3.0));

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
    // Always read T first as we use it to adjust RH for better accuracy
    currentTemperature = readTemperature(3, 500);
    currentHumidity = readHumidity(3, 500);

    if ((currentTemperature > temperatureThreshold) || (currentHumidity > humidityThreshold)) {
      switchRelay(true);
    }
    else if ((currentTemperature < temperatureThreshold - thermostatHysteresis) && 
             (currentHumidity < humidityThreshold - thermostatHysteresis)) {
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

