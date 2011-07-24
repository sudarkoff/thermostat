#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Continuously read the serial port and process IO data received from a remote XBee.
"""

import sys
import time
import atexit
import serial
from xbee import ZigBee

import httplib
import urllib
import urllib2
import mimetools
import mimetypes
import simplejson
import logging

VERSION = "1.0"
retries = 3
retry_in_seconds = 1
server_uri = 'bot.sud.to'
server_port = '80'
#server_uri = 'hermes.local'
#server_port = '8080'
attic1fan_temperature_name = 'attic1fan_temperature'
attic1fan_humidity_name = 'attic1fan_humidity'
attic1fan_fan_name = 'attic1fan_fan'


class APIError(Exception):
    pass

class ServerInfo(object):
    """
    Server connection information.
    """
    def __init__(self, uri, port):
        self.uri = uri
        self.port = port

    def __str__(self):
        return ":".join([self.uri, self.port])


class SudarbotServer(object):
    def __init__(self, server_info):
        self.server_info = server_info
        self.scheme = "http"
        self.extra_headers = {}

    def process_json(self, data):
        """
        Loads in a JSON and returns the data.
        """
        return simplejson.loads(data)

    def request(self, method, path, fields=None, files=None):
        """
        Performs an HTTP method (GET, POST, PUT, DELETE) on the specified path.
        """
        if method not in ['GET', 'POST', 'PUT', 'DELETE']:
            raise Error, 'Unrecognized HTTP method: %s' % method
        logging.debug("HTTP %s %s" % (method, path))

        headers = {}
        body = None
        if method in ['POST', 'PUT']:
            content_type, body = self._encode_multipart_formdata(fields, files)
            headers['Content-Type'] = content_type
            headers['Content-Length'] = str(len(body))
        headers.update(self.extra_headers)

        logging.info("Connecting to '%s:%s'" % (self.server_info.uri, self.server_info.port))
        conn = httplib.HTTPConnection(self.server_info.uri, self.server_info.port)
        retries = globals()["retries"]
        retry_in_seconds = globals()["retry_in_seconds"]
        success = False
        while not success and retries:
            try:
                conn.request(method, path, body, headers)
                success = True
            except Exception, msg:
                logging.warning("%s '%s' failed: %s. Retrying in %s seconds." % (method, path, msg, retry_in_seconds))
                retries = retries - 1
                time.sleep(retry_in_seconds)
                retry_in_seconds = retry_in_seconds + 1

        if not success:
            raise APIError, "%s %s failed." % (method, path)

        response = conn.getresponse()
        # conn.close()
        logging.debug("HTTP %s %s" % (response.status, response.reason))

        if response.status != 200:
            logging.error("Unable to %s %s (%s %s)." % (method, path, response.status, response.reason))
            raise APIError, response.reason

        if method in ['GET', 'POST', 'PUT']:
            data = response.read()
            return self.process_json(data)

    def _encode_multipart_formdata(self, fields, files):
        """
        Encodes data for use in an HTTP POST.
        """
        BOUNDARY = mimetools.choose_boundary()
        content = ""

        fields = fields or {}
        files = files or {}

        for key in fields:
            content += "--" + BOUNDARY + "\r\n"
            content += "Content-Disposition: form-data; name=\"%s\"\r\n" % key
            content += "\r\n"
            content += fields[key] + "\r\n"

        for key in files:
            filename = files[key]['filename']
            value = files[key]['content']
            content += "--" + BOUNDARY + "\r\n"
            content += "Content-Disposition: form-data; name=\"%s\"; " % key
            content += "filename=\"%s\"\r\n" % filename
            content += "\r\n"
            content += value + "\r\n"

        content += "--" + BOUNDARY + "--\r\n"
        content += "\r\n"

        content_type = "multipart/form-data; boundary=%s" % BOUNDARY

        return content_type, content


class Logger:
    def __init__(self, serport):
        logging.info("Initializing the script.")
        self.serport = serport
        server_info = ServerInfo(server_uri, server_port)
        logging.info("Remote server: %s" % server_info)
        self.server = SudarbotServer(server_info)
        atexit.register(self.terminate)

        # TODO: Check that the datastream(s) exist instead of re-creating them
        # all the time (which updates their last_medified timestamp)
        # logging.info("Creating/updating attic1 fan datastreams.")
        # try:
        #     self.server.request('PUT', '/datastream/%s' % attic1fan_temperature_name)
        #     self.server.request('PUT', '/datastream/%s' % attic1fan_humidity_name)
        #     self.server.request('PUT', '/datastream/%s' % attic1fan_fan_name)
        # except Exception, msg:
        #     logging.error("Failed to create/update datastreams: %s" % msg)

    def post_data(self, data):
        logging.info("Data received from the thermostat.")
        temperature = ord(data['rf_data'][0])
        humidity = ord(data['rf_data'][1])
        fan = False
        logging.info(u"T:%sC, RH:%s%%RH, Fan:%s" % (temperature, humidity, fan))
        self.server.request('POST', '/datastream/%s' % attic1fan_temperature_name, {'value':"%s" % temperature})
        self.server.request('POST', '/datastream/%s' % attic1fan_humidity_name, {'value':"%s" % humidity})
        self.server.request('POST', '/datastream/%s' % attic1fan_fan_name, {'value':"%s" % fan})

    def run(self):
        try:
            logging.info("Initializing serial port '%s'." % self.serport)
            self.serial_port = serial.Serial(self.serport, 9600)
            logging.info("Initializing ZigBee radio.")
            self.xbee = ZigBee(self.serial_port, callback=self.post_data, escaped=True)
        except Exception, msg:
            logging.error("Failed to initialize ZigBee radio: %s" % msg)

        while True:
            time.sleep(0.01)

    def terminate(self):
        logging.info("Terminating the script.")
        # self.xbee.halt()
        # self.serial_port.close()
        sys.exit(0)


if __name__ == "__main__":
    log_level = logging.DEBUG
    logging.basicConfig(level=log_level,
        filename='/var/log/sudarbot.log',
        format='%(asctime)s %(levelname)-8s %(message)s',
        datefmt='%a, %d %b %Y %H:%M:%S')

    logger = Logger(serport='/dev/tty.usbserial-A40081sf')
    try:
        logger.run()
    except Exception, msg:
        logger.error("ERROR: %s" % msg)
        logger.terminate()
