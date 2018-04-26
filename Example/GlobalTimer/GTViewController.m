//
//  GTViewController.m
//  GlobalTimer
//
//  Created by wangchengqvan@gmail.com on 01/25/2018.
//  Copyright (c) 2018 wangchengqvan@gmail.com. All rights reserved.
//

#import "GTViewController.h"
#import <GlobalTimer/GlobalTimer.h>

@interface GTViewController ()

@end

@implementation GTViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    // will spend 0.1 mb memory
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(100, 120, 50, 30)];
    [button setBackgroundColor:[UIColor redColor]];
    [button addTarget:self action:@selector(test) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    [[GTimer shared] scheduledWith:@"first" timeInterval:2 repeat:YES block:^(NSDictionary *userinfo) {
        NSLog(@"🇺🇸%@", userinfo[@"test"]);
    } userinfo:@{@"test": @"ok"}];
    
    [self performSelector:@selector(test) withObject:nil afterDelay:2];

//    [[GTimer shared] scheduledWith:@"second" timeInterval:6 repeat:YES block:^(NSDictionary *userinfo) {
//        NSLog(@"🐯%@--%@", userinfo[@"cnkcq"], [NSThread currentThread]);
//    } userinfo:@{@"cnkcq": @"king"}];
    
    [[GTimer shared] scheduledWith:@"hello" timeInterval:4 repeat:YES block:^(NSDictionary *userinfo) {
        NSLog(@"🌺%@--%@", userinfo[@"cnkcq"], [NSThread currentThread]);
    } userinfo:@{}];
    

//    [[GTimer shared] scheduledWith:@"secondfk" timeInterval:9 repeat:YES block:^(NSDictionary *userinfo) {
//        NSLog(@"🇺🇸%@--%@", userinfo[@"cnkcq"], [NSThread currentThread]);
//    } userinfo:@{@"cnkcq": @"king"}];


//    [[GTimer shared] scheduledWith:@"dog" timeInterval:8 repeat:YES block:^(NSDictionary *userinfo) {
//        NSLog(@"🐶%@", userinfo[@"dog"]);
//    } userinfo:@{@"dog": @"旺财"}];
//    for (int i = 1; i < 10000; i++) {
//        [[GTimer shared] scheduledWith:[NSString stringWithFormat:@"fourth%d", i] timeInterval:2 repeat:YES block:^(NSDictionary *userinfo) {
//            NSLog(@"🐱%@", userinfo[@"cat"]);
//        } userinfo:@{@"cat": @"咪咪"}];
//    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"pausedog" style:UIBarButtonItemStylePlain target:self action:@selector(pauseDog)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"activedog" style:UIBarButtonItemStylePlain target:self action:@selector(activeDog)];
}

- (void)pauseDog {
    [[GTimer shared] pauseEventWith:@"dog"];
    NSLog(@"%@", [[GTimer shared] eventList]);
}

- (void)activeDog {
    [[GTimer shared] activeEventWith:@"dog"];
    [[GTimer shared] removeEventWith:@"fourth"];
}

- (void)test {
//    [[GTimer shared] scheduledWith:@"secondffuc" timeInterval:3 repeat:YES block:^(NSDictionary *userinfo) {
//        NSLog(@"🚀%@--%@", userinfo[@"cnkcq"], [NSThread currentThread]);
//    } userinfo:@{@"cnkcq": @"king"}];
    [[GTimer shared] scheduledWith:@"seHcond" timeInterval:6 repeat:YES block:^(NSDictionary *userinfo) {
        NSLog(@"🐯%@--%@", userinfo[@"cnkcq"], [NSThread currentThread]);
    } userinfo:@{@"cnkcq": @"king"}];

}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
