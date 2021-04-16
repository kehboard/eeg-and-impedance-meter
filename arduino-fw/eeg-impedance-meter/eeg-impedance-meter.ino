#include <Wire.h>
#include "AD5933.h"

#define START_FREQ  (80000)
#define FREQ_INCR   (1000)
#define NUM_INCR    (1)
#define REF_RESIST  (10000)

double gain[NUM_INCR+1];
int phase[NUM_INCR+1];

void setup(void)
{
  // Begin I2C
  Wire.begin();

  // Begin serial at 9600 baud for output
  Serial.begin(9600);
  //Serial.println("AD5933 Test Started!");

  // Perform initial configuration. Fail if any one of these fail.
  if (!(AD5933::reset() &&
        AD5933::setInternalClock(true) &&
        AD5933::setStartFrequency(START_FREQ) &&
        AD5933::setIncrementFrequency(FREQ_INCR) &&
        AD5933::setNumberIncrements(NUM_INCR) &&
        AD5933::setPGAGain(PGA_GAIN_X1)))
        {
            Serial.println("FAILED in initialization!");
            while (true) ;
        }

  // Perform calibration sweep
  AD5933::calibrate(gain, phase, REF_RESIST, NUM_INCR+1);
  /*
    //Serial.println("Calibrated!");
  else
    //Serial.println("Calibration failed...");*/
}

void loop(void)
{
  Serial.print(frequencySweepEasy());
  Serial.print(" ");
  Serial.println(float(analogRead(A0)));
}

// Easy way to do a frequency sweep. Does an entire frequency sweep at once and
// stores the data into arrays for processing afterwards. This is easy-to-use,
// but doesn't allow you to process data in real time.
double frequencySweepEasy() {
    // Create arrays to hold the data
    int real[NUM_INCR+1], imag[NUM_INCR+1];
    // Perform the frequency sweep
    if (AD5933::frequencySweep(real, imag, NUM_INCR+1)) {
      double magnitude = sqrt(pow(real[0], 2) + pow(imag[0], 2));
      double impedance = 1/(magnitude*gain[0]);
      // Serial.print("  |Z|=");
      return impedance;
    } else {
      return -1.0;
    }
    return -1.0;
}
