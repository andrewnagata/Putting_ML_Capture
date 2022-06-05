//
//  BLEManager.h
//  PuttRollMLTool
//
//  Created by Andrew Nagata on 12/31/19.
//  Copyright © 2019 Andrew Nagata. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoreBluetooth/CoreBluetooth.h"

NS_ASSUME_NONNULL_BEGIN

@interface BLEManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
{
    
}

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *hrmPeripheral;

+ (id)shared;
- (void)resetTrigger;

@end

extern NSString* const kDidConnectPeripheral;
extern NSString* const kDidDisconnectPeripheral;
extern NSString* const kDidDiscoverPeripheral;
extern NSString* const kDidUpdateValueForCharacteristic;
extern NSString* const kTriggered;

NS_ASSUME_NONNULL_END
