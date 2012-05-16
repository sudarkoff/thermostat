template <typename T>
class Sensor {
  public:
    Sensor() : samples_(3), wait_(500), lastReading_(T()) {}
    Sensor(int samples, int wait) : samples_(samples), wait_(wait), lastReading_(T()) {}
    virtual ~Sensor() {}

    virtual T const& read() = 0;
    virtual void print() { Serial.print(lastReading_); }

  private:
    int samples_;
    int wait_;

    T lastReading_;
};

class Temperature : public Sensor<double> {
  public:
    enum Scale { Celsius, Fahrenheit };
    Temperature() : scale_(Celsius) {}
    Temperature(Scale scale) : scale_(scale) {}

    virtual double const& read();

  private:
    Scale scale_;
}

// Read temperature sensor 'samples' times, average the readings and convert to 'scale'.
double const& Temperature::read()
{
#ifdef T_SENSOR
  double t = 0.0;
  // throw away first reading (for some reason it's often junk)
  analogRead(temperatureSensor);
  for (int i = 0; i < samples_; i++) {
    delay(wait_);
    double sensorReading = analogRead(temperatureSensor);
    double val = (5.0 * sensorReading * 100.0) / 1024.0;
    t += val;
  }
  t = t/samples_;

  return t;
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


