"""
Continuously read the serial port and process IO data received from a remote XBee.
"""

from xbee import ZigBee
import serial

ser = serial.Serial('/dev/tty.usbserial-A40081sf', 9600)

xbee = ZigBee(ser)

# Continuously read and print packets
while True:
    try:
        response = xbee.wait_read_frame()
        print response
    except KeyboardInterrupt:
        break

ser.close()
