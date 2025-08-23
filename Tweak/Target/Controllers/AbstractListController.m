//
//  AbstractListController.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import "AbstractListController.h"

@implementation AbstractListController
- (void)viewDidLoad {
    [super viewDidLoad];

    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
}

/**
 * Called when the app resigns active.
 *
 * @param notification
 */
- (void)applicationWillResignActive:(NSNotification *)notification {
    // No longer needed since biometric protection is removed
}

/**
 * Called when the app will enter the foreground.
 *
 * @param notification
 */
- (void)applicationWillEnterForeground:(NSNotification *)notification {
    // No longer needed since biometric protection is removed
}

/**
 * Called when the app becomes active.
 *
 * @param notification
 */
- (void)applicationDidBecomeActive:(NSNotification *)notification {
    // No longer needed since biometric protection is removed
}
@end
