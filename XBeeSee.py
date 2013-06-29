#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Continuously read the serial port and process IO data received from a remote XBee.
"""

import time
import serial
from xbee import ZigBee
port_name = '/dev/tty.usbserial-A40081sf'
serial_port = serial.Serial(port_name, 9600)
import logging

logger = logging.getLogger('XBeeThermostatLogger')
hdlr = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)
logger.addHandler(hdlr) 
logger.setLevel(logging.INFO)

def log_to_file(data):
    logger.info(u"T:%s°C, RH:%s%%RH" % ( ord(data['rf_data'][0]), ord(data['rf_data'][1]) ))

xbee = ZigBee(serial_port, callback=log_to_file, escaped=True)
logger.info("ZigBee %s initialized successfully." % port_name)

while True:
    try:
        time.sleep(0.01)
    except KeyboardInterrupt:
        logger.debug("Logger terminated.")
        break

xbee.halt()
serial_port.close()
