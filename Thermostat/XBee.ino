/*
  
*/

uint8_t payload[] = { 0, 0, 0, 0 };
XBee xbee = XBee();
XBeeAddress64 addr64 = XBeeAddress64(0x0, 0xffff); // broadcast the measurements
ZBTxRequest zbTx = ZBTxRequest(addr64, payload, sizeof(payload));
ZBTxStatusResponse txStatus = ZBTxStatusResponse();

void sendMeasurements() {
#ifdef XBEE
  payload[0] = (uint8_t)floor(currentTemperature + 0.5);
  payload[1] = (uint8_t)floor(currentHumidity + 0.5);
  payload[2] = (uint8_t)((relayState==true)? 1: 0);
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
        hardwin::flashLed(statusLed, 1, 500);
      } else {
        // the remote XBee did not receive our packet. is it powered on?
        hardwin::flashLed(statusLed, 3, 300);
      }
    }      
  } else {
    // local XBee did not provide a timely TX Status Response -- should not happen
    hardwin::flashLed(statusLed, 2, 50);
  }
#else
#ifdef T_SENSOR
  Serial.print("Temperature: "); Serial.println(currentTemperature);
#endif
#ifdef RH_SENSOR
  Serial.print("Humidity: "); Serial.println(currentHumidity);
#endif
  Serial.print("Relay: "); Serial.println(relayState==true? "ON": "OFF");
#endif
}


