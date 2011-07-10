"""
Continuously read the serial port and process IO data received from a remote XBee.
"""

import time
import serial
from xbee import ZigBee

serial_port = serial.Serial('/dev/tty.usbserial-A40081sf', 9600)

def print_data(data):
    """
    This method is called whenever data is received from the associated
    XBee device. Its first and 3 only argument is the data contained within
    the frame.
    """
    print data

xbee = ZigBee(serial_port, callback=print_data, escaped=True)

while True:
    try:
        time.sleep(0.001)
    except KeyboardInterrupt:
        break

xbee.halt()
serial_port.close()
