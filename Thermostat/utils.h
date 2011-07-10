template <typename T>
int EEPROM_write(int ee, const T& value)
{
    const byte* p = reinterpret_cast<byte const* const>(reinterpret_cast<void const* const>(&value));
    int i;
    for (i = 0; i < sizeof(value); i++) {
	  EEPROM.write(ee++, *p++);
    }
    return i;
}

template <typename T>
int EEPROM_read(int ee, T& value)
{
    byte* p = reinterpret_cast<byte*>(reinterpret_cast<void*>(&value));
    int i;
    for (i = 0; i < sizeof(value); i++) {
	  *p++ = EEPROM.read(ee++);
    }
    return i;
}

float readThreshold(int addr, float minimumValue, float maximumValue, float defaultValue)
{
  float value;
  EEPROM_read(addr, value);
  // if the value is out of range ...
  if ((value < minimumValue) || (value > maximumValue)) {
    // ... replace it with default value
    value = defaultValue;
    EEPROM_write(addr, value);
  }
  return value;
}

void writeThreshold(int addr, float value)
{
  EEPROM_write(addr, value);
}

void flashLed(int pin, int times, int wait) {
  for (int i = 0; i < times; i++) {
    digitalWrite(pin, HIGH);
    delay(wait);
    digitalWrite(pin, LOW);

    if (i + 1 < times) {
      delay(wait);
    }
  }
}


