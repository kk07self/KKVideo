//
//  DemoListViewController.m
//  KKVideo
//
//  Created by tutu on 2019/7/16.
//  Copyright © 2019 KK. All rights reserved.
//

#import "DemoListViewController.h"
#import "SimpleCameraViewController.h"

@interface DemoListViewController ()

/**
 demolist
 */
@property (nonatomic, strong) NSArray *demoList;

@end

@implementation DemoListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    _demoList = @[@"SimpleCamera"];
}

#pragma mark - Table view data source


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _demoList.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.text = _demoList[indexPath.row];
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.row == 0) {
        SimpleCameraViewController *simple = [[SimpleCameraViewController alloc] init];
        [self showViewController:simple sender:nil];
    }
}

@end
