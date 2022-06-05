//
//  BLEManager.m
//  PuttRollMLTool
//
//  Created by Andrew Nagata on 12/31/19.
//  Copyright © 2019 Andrew Nagata. All rights reserved.
//

#import "BLEManager.h"

#define TRIGGER_SERVICE_UUID @"1234"
#define TRIGGER_CHARACTERISTIC_UUID @"5678"
#define RESPONSE_CHARACTERISTIC_UUID @"4567"

NSString* const kDidConnectPeripheral = @"didConnectPeripheral";
NSString* const kDidDisconnectPeripheral = @"didDisconnectPeripheral";
NSString* const kDidDiscoverPeripheral = @"didDiscoverPeripheral";
NSString* const kDidUpdateValueForCharacteristic = @"didUpdateValueForCharacteristic";
NSString* const kTriggered = @"triggered";

@interface BLEManager()

@end

@implementation BLEManager

+ (id)shared
{
    static CBManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (id)init
{
    if (self = [super init])
    {
        // Create the CoreBluetooth CentralManager //
        CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        self.centralManager = centralManager;
    }
    return self;
}

#pragma mark - CBCentralManagerDelegate

// Method called whenever you have successfully connected to the BLE peripheral //
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    // Set the delegate of the peripheral //
    [peripheral setDelegate:self];
    
    // Tell the peripheral to discover services //
    // When the peripheral discovers one or more services, it calls the peripheral:didDiscoverServices: method //
    [peripheral discoverServices:nil];
    
    NSString *connected = [NSString stringWithFormat:@"Connected: %@", peripheral.state == CBPeripheralStateConnected ? @"YES" : @"NO"];
    
    NSLog(@"%@", connected);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidConnectPeripheral object:nil userInfo:@{@"peripheral":peripheral}];
}

// Method called when an existing connection with a peripheral is disconnected //
// If the disconnection was not initiated by cancelPeripheralConnection: the cause is detailed in error //
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSString *connected = [NSString stringWithFormat:@"Connected: %@", peripheral.state == CBPeripheralStateConnected ? @"YES" : @"NO"];
    
    NSLog(@"%@", connected);
    
    [self startScan];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidDisconnectPeripheral object:nil userInfo:@{@"peripheral":peripheral}];
}

// Method called with the CBPeripheral class as its main input parameter //
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    // Check to make sure that the device has a non-empty local name //
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    if ([localName length] > 0){
        NSLog(@"Found the service: %@", localName);
        
        // Stop scanning //
        [self.centralManager stopScan];
        
        // Store peripheral //
        self.hrmPeripheral = peripheral;
        peripheral.delegate = self;
        
        // Connect to peripheral //
        [self.centralManager connectPeripheral:peripheral options:nil];
        
    }
    else{
        NSLog(@"Device with no localName");
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidDiscoverPeripheral object:nil userInfo:@{@"peripheral":peripheral}];
}

// Method called whenever the device state changes //
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    // Determine the state of the CentralManager //
    // (To make sure this iOS device is Bluetooth low energy compliant and it can be used as the CentralManager) //
    if ([central state] == CBCentralManagerStatePoweredOff) {
        NSLog(@"CoreBluetooth BLE hardware is powered off");
    }
    else if ([central state] == CBCentralManagerStatePoweredOn) {
        NSLog(@"CoreBluetooth BLE hardware is powered on and ready");
        
        [self startScan];
        
    }
    else if ([central state] == CBCentralManagerStateUnauthorized) {
        NSLog(@"CoreBluetooth BLE state is unauthorized");
    }
    else if ([central state] == CBCentralManagerStateUnknown) {
        NSLog(@"CoreBluetooth BLE state is unknown");
    }
    else if ([central state] == CBCentralManagerStateUnsupported) {
        NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
    }
}

- (void)startScan
{
    // Create an array with Bluetooth-services you wish to detect //
    NSArray *services = @[[CBUUID UUIDWithString:TRIGGER_SERVICE_UUID]];
    // Start scanning for services //
    [self.centralManager scanForPeripheralsWithServices:services options:nil];
}

#pragma mark - CBPeripheralDelegate

// Method called when the peripheral's available services are discovered //
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    // Walk through all services //
    for (CBService *service in peripheral.services){
        NSLog(@"Discovered service: %@", service.UUID);
        
        // Ask to discover characteristics for service //
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// Method called when the characteristics of a specified service are discovered //
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Check if service is HeartRate service //
    if ([service.UUID isEqual:[CBUUID UUIDWithString:TRIGGER_SERVICE_UUID]]){
        
        // If so, iterate through the characteristics array and determine if the characteristic is a HeartRateMeasurement characteristic //
        // If so, you subscribe to this characteristic //
        
        for (CBCharacteristic *aChar in service.characteristics)
        {
            // Request HeartRateMeasurement notifications //
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:TRIGGER_CHARACTERISTIC_UUID]])
            {
                [self.hrmPeripheral setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found triggering characteristic");
            }
            
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:RESPONSE_CHARACTERISTIC_UUID]])
            {
                NSLog(@"Found RESPONSE characteristic");
            }
        }
    }
}

// Method called when you retrieve a specified characteristic's value //
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    // New value for HeartRateMeasurement received //
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRIGGER_CHARACTERISTIC_UUID]])
    {
        // Get HeartRate data //
        [self getTriggerState:characteristic error:error];
    }
}

- (void)resetTrigger
{
    int i = 1;
    NSData *data = [NSData dataWithBytes: &i length: sizeof(i)];
    CBCharacteristic *rChar = [self characteristicWithUUID:[CBUUID UUIDWithString:RESPONSE_CHARACTERISTIC_UUID] forServiceUUID:[CBUUID UUIDWithString:TRIGGER_SERVICE_UUID] inPeripheral:_hrmPeripheral];
    [_hrmPeripheral writeValue:data forCharacteristic:rChar type:CBCharacteristicWriteWithResponse];
}

#pragma mark - CBCharacteristic helpers

- (void)getTriggerState:(CBCharacteristic *)characteristic error:(NSError *)error
 {
     NSData *data = [characteristic value];
     
     // Get the byte sequence of the data-object //
     const uint8_t *reportData = [data bytes];
     
     if(reportData[0] == 1)
     {
         [[NSNotificationCenter defaultCenter] postNotificationName:kTriggered object:nil userInfo:@{@"data":[NSNumber numberWithInt:reportData[0]]}];
         
         NSLog(@"Triggered. SAve the frame and then move on...");
     }
 }

- (CBCharacteristic *)characteristicWithUUID:(CBUUID *)characteristicUUID forServiceUUID:(CBUUID *)serviceUUID inPeripheral:(CBPeripheral *)peripheral
{
    CBCharacteristic *returnCharacteristic  = nil;
    for (CBService *service in peripheral.services) {

       if ([service.UUID isEqual:serviceUUID]) {
           for (CBCharacteristic *characteristic in service.characteristics) {

                if ([characteristic.UUID isEqual:characteristicUUID]) {

                    returnCharacteristic = characteristic;
                }
            }
        }
    }
    return returnCharacteristic;
}

@end
