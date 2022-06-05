//
//  AppDelegate.m
//  PuttRollMLTool
//
//  Created by Andrew Nagata on 12/31/19.
//  Copyright © 2019 Andrew Nagata. All rights reserved.
//

#import "AppDelegate.h"
#import "BLEManager.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    BLEManager *manager = [BLEManager shared];
    
    return YES;
}

@end
