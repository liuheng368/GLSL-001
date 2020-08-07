//
//  ViewController.m
//  GLSL-001
//
//  Created by Henry on 2020/8/6.
//  Copyright © 2020 刘恒. All rights reserved.
//

#import "ViewController.h"
#import "HyView.h"
@interface ViewController ()
@property (nonatomic,strong)HyView *hyView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hyView = (HyView *)self.view;
}


@end
