//
//  RWSearchFormViewController.m
//  TwitterInstant
//
//  Created by Colin Eberhardt on 02/12/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import "RWSearchFormViewController.h"
#import "RWSearchResultsViewController.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <Accounts/Accounts.h>
#import <Twitter/Twitter.h>

typedef NS_ENUM(NSUInteger, RWTwitterinstantError) {
    RWTwitterinstantErrorAccessDenied,
    RWTwitterinstantErrorNoTwitterAccounts,
    RWTwitterinstantErrorInvalidResponse,
};

static NSString * const RWTwitterInstantDomain = @"TwitterInstant";

@interface RWSearchFormViewController ()

@property (weak, nonatomic) IBOutlet UITextField *searchText;

@property (strong, nonatomic) RWSearchResultsViewController *resultsViewController;

@property (nonatomic, strong) ACAccountStore *accountStore;
@property (nonatomic, strong) ACAccountType  *twitterAccountType;

@end

@implementation RWSearchFormViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Twitter Instant";

    [self styleTextField:self.searchText];

    self.resultsViewController = self.splitViewController.viewControllers[1];
    
    RAC(self.searchText, backgroundColor) = [self.searchText.rac_textSignal map:^id(NSString *value) {
        return [self isValidSearchText:value] ? [UIColor whiteColor] : [UIColor yellowColor];
    }];
    
    @weakify(self)
    RACSignal *backgroundColorSignal = [self.searchText.rac_textSignal map:^id(NSString *value) {
        return [self isValidSearchText:value] ? [UIColor whiteColor] : [UIColor yellowColor];
    }];
    
    RACDisposable *subscription = [backgroundColorSignal subscribeNext:^(UIColor *color) {
        @strongify(self)
        self.searchText.backgroundColor = color;
    }];
    [subscription dispose];
    
    self.accountStore       = [[ACAccountStore alloc] init];
    self.twitterAccountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [[[[[[[self requestAccessToTwitterSignal]
       // 请求成功后走这一步，失败直接走error
       then:^RACSignal *{
          @strongify(self)
          return self.searchText.rac_textSignal;
    }]
      filter:^BOOL(id value) {
          @strongify(self)
          return [self isValidSearchText:value];
      }]
       throttle:0.5]
      flattenMap:^RACStream *(NSString *text) {
          // flattenMap 会使用内部signal的next，error
          @strongify(self)
          return [self signalForSearchWithText:text];
      }]
     deliverOnMainThread]
     subscribeNext:^(id x) {
         NSLog(@"%@", x);
    }
     error:^(NSError *error) {
         NSLog(@"error: %@", error);
    }];
}

- (RACSignal *)requestAccessToTwitterSignal
{
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self)
        [self.accountStore requestAccessToAccountsWithType:self.twitterAccountType options:nil completion:^(BOOL granted, NSError *error) {
            if (granted)
            {
                [subscriber sendNext:nil];
                [subscriber sendCompleted];
            }
            else
            {
                if (!error)
                {
                    error = [NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterinstantErrorAccessDenied userInfo:nil];
                }
                [subscriber sendError:error];
            }
        }];
        
        
        return nil;
    }];
}

- (SLRequest *)requestForTwitterSearchWithText:(NSString *)text
{
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/search/tweets.json"];
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:@{@"q" : text}];
    return request;
}

- (RACSignal *)signalForSearchWithText:(NSString *)text
{
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
     @strongify(self)
        
        SLRequest *request = [self requestForTwitterSearchWithText:text];
        
        NSArray *twitterAccounts = [self.accountStore accountsWithAccountType:self.twitterAccountType];
        if ([twitterAccounts count] == 0)
        {
            [subscriber sendError:[NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterinstantErrorNoTwitterAccounts userInfo:nil]];
            return nil;
        }
        
        [request setAccount:[twitterAccounts lastObject]];
        
        [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
            if (urlResponse.statusCode == 200)
            {
                NSDictionary *timelineData = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
                [subscriber sendNext:timelineData];
                [subscriber sendCompleted];
            }
            else
            {
                [subscriber sendError:[NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterinstantErrorInvalidResponse userInfo:nil]];
            }
        }];
        
        return nil;
    }];
}

- (void)styleTextField:(UITextField *)textField {

    CALayer *textFieldLayer = textField.layer;
    textFieldLayer.borderColor = [UIColor grayColor].CGColor;
    textFieldLayer.borderWidth = 2.0f;
    textFieldLayer.cornerRadius = 0.0f;
}

- (BOOL)isValidSearchText:(NSString *)text
{
    return text.length > 2;
}

@end
