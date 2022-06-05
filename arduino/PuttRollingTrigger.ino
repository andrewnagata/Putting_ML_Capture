#include <ArduinoBLE.h>

BLEService myService("1234");
BLEByteCharacteristic switchCharacteristic("5678", BLERead | BLEWrite | BLENotify);
BLEByteCharacteristic responseCharacteristic("4567", BLERead | BLEWrite);

const int ledPin = LED_BUILTIN; // pin to use for the LED
const int triggerPin = 2;

const int OBSERVING = 0;
const int TRIGGERED = 1;
const int WAITING = 2;
int state = 0;

const int OPEN = 1;
const int BLOCKED = 0;
int beamState = 1;

void setup()
{
  Serial.begin(9600);
  //while (!Serial);
  
  pinMode(ledPin, OUTPUT); // use the LED pin as an output

  // begin initialization
  if (!BLE.begin()) {
    Serial.println("starting BLE failed!");

    while (1);
  }

  // set the local name peripheral advertises
  BLE.setLocalName("PuttPeeper");
  // set the UUID for the service this peripheral advertises
  BLE.setAdvertisedService(myService);

  // add the characteristic to the service
  myService.addCharacteristic(switchCharacteristic);
  myService.addCharacteristic(responseCharacteristic);
  
  // add service
  BLE.addService(myService);

  // assign event handlers for connected, disconnected to peripheral
  BLE.setEventHandler(BLEConnected, blePeripheralConnectHandler);
  BLE.setEventHandler(BLEDisconnected, blePeripheralDisconnectHandler);

  // assign event handlers for characteristic
  switchCharacteristic.setEventHandler(BLEWritten, switchCharacteristicWritten);
  // set an initial value for the characteristic
  switchCharacteristic.setValue(0);

  
  // assign event handlers for characteristic
  responseCharacteristic.setEventHandler(BLEWritten, responseCharacteristicWritten);
  // set an initial value for the characteristic
  responseCharacteristic.setValue(0);
  
  // start advertising
  BLE.advertise();

  Serial.println(("Bluetooth device active, waiting for connections..."));
}

void loop()
{
  BLE.poll();
  
  manageState();
}

void manageState()
{
  switch(state)
  {
     case OBSERVING:
     {
        int tPin = digitalRead(triggerPin);
        if(tPin == BLOCKED)
          state = TRIGGERED;
        break;
     }
     case TRIGGERED:
     {
        Serial.println("TRIGGERED");
        switchCharacteristic.writeValue((byte)0x01);
        state = WAITING;
        break;
     }
     case WAITING:

     break;
  }
}

void blePeripheralConnectHandler(BLEDevice central)
{
  // central connected event handler
  Serial.print("Connected event, central: ");
  Serial.println(central.address());
}

void blePeripheralDisconnectHandler(BLEDevice central)
{
  // central disconnected event handler
  Serial.print("Disconnected event, central: ");
  Serial.println(central.address());
}

void responseCharacteristicWritten(BLEDevice central, BLECharacteristic characteristic)
{
  Serial.print("responseCharacteristicWritten event, written: ");
  Serial.println(responseCharacteristic.value());

  if(responseCharacteristic.value() == 1)
  {
    state = OBSERVING;
  }
}

void switchCharacteristicWritten(BLEDevice central, BLECharacteristic characteristic)
{
  // central wrote new value to characteristic, update LED
  Serial.print("switchCharacteristicWritten event, written: ");
  Serial.println(switchCharacteristic.value());
}
