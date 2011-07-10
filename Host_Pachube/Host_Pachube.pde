/*
 * Draws a set of thermometers for incoming XBee Sensor data
 * by Rob Faludi http://faludi.com
 */

// used for Pachube connection http://pachube.com
// JPachube library available at http://code.google.com/p/jpachube/
import Pachube.*;

// used for communication via xbee api
import processing.serial.*; 

// xbee api libraries available at http://code.google.com/p/xbee-api/
// Download the zip file, extract it, and copy the xbee-api jar file 
// and the log4j.jar file (located in the lib folder) inside a "code" 
// folder under this Processing sketch’s folder (save this sketch, then 
// click the Sketch menu and choose Show Sketch Folder).
import com.rapplogic.xbee.api.ApiId;
import com.rapplogic.xbee.api.PacketListener;
import com.rapplogic.xbee.api.XBee;
import com.rapplogic.xbee.api.XBeeResponse;
import com.rapplogic.xbee.api.zigbee.ZNetRxResponse;

String version = "1.04";

// *** REPLACE WITH THE SERIAL PORT (COM PORT) FOR YOUR LOCAL XBEE ***
String mySerialPort = "/dev/tty.usbserial-A40081sf";

// *** REPLACE WITH YOUR OWN PACHUBE API KEY AND FEED ID ***
String apiKey="fOmRNbERaEyNGpaARKsDA1MmxgNNPFLJ-KIHknPrisc";
int feedID=26507;

// create and initialize a new xbee object
XBee xbee = new XBee();

int error=0;

// used to record time of last data post
float lastUpdate;

// make an array list of thermometer objects for display
ArrayList thermometers = new ArrayList();
// create a font for display
PFont font;

// Globals
int g_winW             = 820;   // Window Width
int g_winH             = 600;   // Window Height
boolean g_enableFilter = true;  // Enables simple filter to help smooth out data.
cGraph g_graph         = new cGraph(10, 190, 800, 400);

void setup() {
  size(g_winW, g_winH, P2D); // screen size
  smooth(); // anti-aliasing for graphic display

  // You’ll need to generate a font before you can run this sketch.
  // Click the Tools menu and choose Create Font. Click Sans Serif,
  // choose a size of 10, and click OK.
  font =  loadFont("SansSerif-10.vlw");
  textFont(font); // use the font for text

  // The log4j.properties file is required by the xbee api library, and 
  // needs to be in your data folder. You can find this file in the xbee
  // api library you downloaded earlier
  PropertyConfigurator.configure(dataPath("")+"log4j.properties"); 
  // Print a list in case the selected one doesn't work out
  println("Available serial ports:");
  println(Serial.list());
  try {
    // opens your serial port defined above, at 9600 baud
    xbee.open(mySerialPort, 9600);
  }
  catch (XBeeException e) {
    println("** Error opening XBee port: " + e + " **");
    println("Is your XBee plugged in to your computer?");
    println(
      "Did you set your COM port in the code near line 27?");
    error=1;
  }
}


// draw loop executes continuously
void draw() {
  background(224); // draw a light gray background
  // report any serial port problems in the main window
  if (error == 1) {
    fill(0);
    text("** Error opening XBee port: **\n"+
      "Is your XBee plugged in to your computer?\n" +
      "Did you set your COM port in the code near line 20?", width/3, height/2);
  }
  SensorData data = new SensorData(); // create a data object
  data = getData(); // put data into the data object

  // check that actual data came in:
  if (data.address != null) {
    // check to see if a thermometer object already exists for this sensor
    int i;
    boolean foundIt = false;
    for (i=0; i <thermometers.size(); i++) {
      if ( ((Thermometer) thermometers.get(i)).address.equals(data.address) ) {
        foundIt = true;
        break;
      }
    }

    float temperatureCelsius = data.temperature;
    print(" temp: " + round(temperatureCelsius) + "˚C");
    float humidityRH = data.humidity;
    print(", RH: " + round(humidityRH) + "%");
    println(", relay: " + (data.relayStatus != 0?"ON":"OFF"));

    // update the thermometer if it exists, otherwise create a new one
    if (!foundIt) {
      thermometers.add(new Thermometer(data.address, data.numericAddr, 35, 450, (thermometers.size()) * 75 + 40, 20));
    }
    ((Thermometer) thermometers.get(i)).temperature.addVal(temperatureCelsius);
    ((Thermometer) thermometers.get(i)).humidity.addVal(humidityRH);
    ((Thermometer) thermometers.get(i)).relayStatus = (data.relayStatus > 0);

    strokeWeight(1);
    fill(255, 255, 255);
    g_graph.drawGraphBox();

    // draw the thermometers on the screen
    for (int j =0; j<thermometers.size(); j++) {
      ((Thermometer) thermometers.get(j)).render();
    }

    // post data to Pachube every minute
    if ((millis() - lastUpdate) > 60000) {
      for (int j =0; j<thermometers.size(); j++) {
        ((Thermometer) thermometers.get(j)).dataPost();
      }
      lastUpdate = millis();
    }
  }
} // end of draw loop


// defines the data object
class SensorData {
  String address;
  long numericAddr;

  int temperature;
  int humidity;
  int relayStatus;
}


// defines the thermometer objects
class Thermometer {
  int sizeX, sizeY, posX, posY;
  int maxTemp = 40; // max of scale in degrees Celsius
  int minTemp = -10; // min of scale in degress Celsius

  cDataArray temperature = new cDataArray(200);
  cDataArray humidity = new cDataArray(200);
  boolean relayStatus;

  String address; // stores the address locally
  long numAddr; // stores the numeric version of the address

  Thermometer(String _address, long _numAddr, int _sizeX, int _sizeY, int _posX, int _posY) { // initialize thermometer object
    address = _address;
    numAddr = _numAddr;

    sizeX = _sizeX;
    sizeY = _sizeY;
    posX = _posX;
    posY = _posY;
  }

  void dataPost() {
    // add and tag a datastream
    int thermometerFeedID = (int) numAddr;
    println("thermometerFeedID: " + thermometerFeedID);
    int humidityFeedID = (int) numAddr + 10000;
    println("humidityFeedID: " + humidityFeedID);
    int relayFeedID = (int) numAddr + 20000;
    println("relayFeedID: " + relayFeedID);

    //initialize Pachube and Feed objects
    try {
      Pachube p = new Pachube(apiKey);
      // get the feed by its ID
      Feed f = p.getFeed(feedID);

      Data t = new Data();
      t.setId(thermometerFeedID);
      t.setMaxValue(40d);
      t.setMinValue(-10d);
      t.setTag("temperature");

      Data h = new Data();
      h.setId(humidityFeedID);
      h.setMaxValue(100d);
      h.setMinValue(0d);
      h.setTag("humidity");

      Data r = new Data();
      r.setId(relayFeedID);
      r.setTag("relay");

      //attempt to create it
      try {
        f.createDatastream(t);
        f.createDatastream(h);
        f.createDatastream(r);
      }
      catch (PachubeException e) {
        // Not a problem; this just means the feed for this
        // thermometer ID exists, and we're adding more data
        // to it now.
        if (e.errorMessage.equals("HTTP/1.1 400 Bad Request")) {
          println("feed already exists");
        }
        else {
          println(e.errorMessage);
        }
      }

      println("posting to Pachube...");
      f.updateDatastream(thermometerFeedID, (double) temperature.getVal(temperature.getCurSize()-1));
      f.updateDatastream(humidityFeedID, (double) humidity.getVal(humidity.getCurSize()-1));
      f.updateDatastream(relayFeedID, (double) (relayStatus?1:0));
    }
    catch (PachubeException e) {
      println(e.errorMessage);
    }
  }

  void render() { // draw thermometer on screen
    strokeWeight(1.5);

    stroke(255, 0, 0);
    g_graph.drawLine(temperature, -10, 40);
    stroke(0, 255, 0);
    g_graph.drawLine(humidity, 0, 100);

    /*
    // show text
    textAlign(LEFT);
    fill(0);
    textSize(10);

    // show sensor address:
    text(address, posX-10, posY + sizeY + bulbSize + stemSize + 4, 65, 40);

    // show temperature:
    text(round(temp) + " ˚C", posX+2,posY+(sizeY * mercury+ 14));
    */
  }
}

// queries the XBee for incoming I/O data frames 
// and parses them into a data object
SensorData getData() {

  SensorData data = new SensorData();
  int value = -1;      // returns an impossible value if there's an error
  String address = ""; // returns a null value if there's an error

  try {			
    // we wait here until a packet is received.
    XBeeResponse response = xbee.getResponse();
    // uncomment next line for additional debugging information
    println("Received response " + response.toString()); 

    if (response.getApiId() == ApiId.ZNET_RX_RESPONSE && !response.isError()) {
      ZNetRxResponse rxResponse = 
        (ZNetRxResponse)(XBeeResponse) response;

      // get the sender's 64-bit address
      int[] addressArray = rxResponse.getRemoteAddress64().getAddress();
      // parse the address int array into a formatted string
      String[] hexAddress = new String[addressArray.length];
      for (int i=0; i<addressArray.length;i++) {
        // format each address byte with leading zeros:
        hexAddress[i] = String.format("%02x", addressArray[i]);
      }

      // join the array together with colons for readability:
      String senderAddress = join(hexAddress, ":"); 
      print("Sender address: " + senderAddress);
      data.address = senderAddress;
      data.numericAddr = unhex(data.address.replaceAll(":", ""));

      // get the values
      data.temperature = rxResponse.getData()[0];
      data.humidity = rxResponse.getData()[1];
      //data.relayStatus = rxResponse.getData()[2];
    }
    else if (!response.isError()) {
      println("Got error in data frame");
    }
    else {
      println("Got non-i/o data frame");
    }
  }
  catch (XBeeException e) {
    println("Error receiving response: " + e);
  }
  return data; // sends the data back to the calling function
}

// This class helps mangage the arrays of data I need to keep around for graphing.
class cDataArray
{
  float[] m_data;
  int m_maxSize;
  int m_startIndex = 0;
  int m_endIndex = 0;
  int m_curSize;
  
  cDataArray(int maxSize)
  {
    m_maxSize = maxSize;
    m_data = new float[maxSize];
  }
  
  void addVal(float val)
  {
    
    if (g_enableFilter && (m_curSize != 0))
    {
      int indx;
      
      if (m_endIndex == 0)
        indx = m_maxSize-1;
      else
        indx = m_endIndex - 1;
      
      m_data[m_endIndex] = getVal(indx)*.5 + val*.5;
    }
    else
    {
      m_data[m_endIndex] = val;
    }
    
    m_endIndex = (m_endIndex+1)%m_maxSize;
    if (m_curSize == m_maxSize)
    {
      m_startIndex = (m_startIndex+1)%m_maxSize;
    }
    else
    {
      m_curSize++;
    }
  }
  
  float getVal(int index)
  {
    return m_data[(m_startIndex+index)%m_maxSize];
  }
  
  int getCurSize()
  {
    return m_curSize;
  }
  
  int getMaxSize()
  {
    return m_maxSize;
  }
}

// This class takes the data and helps graph it
class cGraph
{
  float m_gWidth, m_gHeight;
  float m_gLeft, m_gBottom, m_gRight, m_gTop;
  
  cGraph(float x, float y, float w, float h)
  {
    m_gWidth     = w;
    m_gHeight    = h;
    m_gLeft      = x;
    m_gBottom    = g_winH - y;
    m_gRight     = x + w;
    m_gTop       = g_winH - y - h;
  }
  
  void drawGraphBox()
  {
    stroke(0, 0, 0);
    rectMode(CORNERS);
    rect(m_gLeft, m_gBottom, m_gRight, m_gTop);
  }
  
  void drawLine(cDataArray data, float minRange, float maxRange)
  {
    float graphMultX = m_gWidth/data.getMaxSize();
    float graphMultY = m_gHeight/(maxRange-minRange);
    
    for(int i=0; i<data.getCurSize()-1; ++i)
    {
      float x0 = i*graphMultX+m_gLeft;
      float y0 = m_gBottom-((data.getVal(i)-minRange)*graphMultY);
      float x1 = (i+1)*graphMultX+m_gLeft;
      float y1 = m_gBottom-((data.getVal(i+1)-minRange)*graphMultY);
      line(x0, y0, x1, y1);
    }
  }
}


