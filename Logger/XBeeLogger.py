#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Listen to incoming traffic and print out the received data.
"""

import sys, time, serial, logging
from xbee import ZigBee

# Setup logger
logger = logging.getLogger('XBeeLogger')
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
console_handler = logging.StreamHandler()
console_handler.setFormatter(formatter)
logger.addHandler(console_handler) 
logger.setLevel(logging.DEBUG)

def log(data):
    logger.info(u"%s" % data)

port = '/dev/tty.usbserial-A40081sf'
if len(sys.argv) > 1:
    port = sys.argv[1]

logger.debug("Initializing serial port %s" % port)
serial_port = serial.Serial(port, 9600)
logger.debug("Initializing XBee on port %s" % port)
xbee = ZigBee(serial_port, callback=log, escaped=True)
logger.debug("Listening to incoming traffic...")

while True:
    try:
        time.sleep(0.01)
    except KeyboardInterrupt:
        xbee.halt()
        serial_port.close()
        logger.debug("Logger terminated.")
        break
