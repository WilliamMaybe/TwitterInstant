# TwitterInstant
ReactiveCocoa

[ReactiveCocoa Tutorial – The Definitive Introduction: Part 2/2](https://www.raywenderlich.com/62796/reactivecocoa-tutorial-pt2)

##Question

demo中如果网络请求失败，会直接发送error,然后直接dispose掉，这样如果再一次请求网络查询时，就不会在调用函数了，不知道应该如何破解

```
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
```