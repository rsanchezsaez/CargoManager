//
//  CargoManager.h
//
//  Copyright (c) 2013 Ricardo Sánchez-Sáez (http://sanchez-saez.com/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <StoreKit/StoreKit.h>


extern NSString *const SMProductRequestDidReceiveResponseNotification;


@class SKProduct;
@protocol CargoManagerUIDelegate;
@protocol CargoManagerContentDelegate;


@interface CargoManager : NSObject

@property (nonatomic, readonly) BOOL productRequestDidReceiveResponse;
@property (nonatomic, readonly) BOOL productRequestError;

@property (nonatomic, weak) id <CargoManagerContentDelegate>  contentDelegate;
@property (nonatomic, weak) id <CargoManagerUIDelegate>  UIDelegate;

+ (CargoManager *)sharedManager;

- (void)loadStore;
- (SKProduct *)productForIdentifier:(NSString *)identifier;

- (void)buyProduct:(SKProduct *)product;

@end


@protocol CargoManagerContentDelegate <NSObject>

// This method should return an array with all the productIdentifiers used by your App
- (NSArray *)productIdentifiers;
// Implement this method to provide content
- (void)provideContentForProductIdentifier:(NSString *)productIdentifier;

@optional

// Use this method if you want to store the transaction for your records
- (void)recordTransaction:(SKPaymentTransaction *)transaction;

// Use this method to manage download data
- (void)downloadUpdated:(SKDownload *)download;

@end


@protocol CargoManagerUIDelegate <NSObject>

// Implement this method to update UI after a IAP has finished
// This method is called both for successful and failed transactions
- (void)transactionDidFinishWithSuccess:(BOOL)success;

@optional

// Implement this method to update UI after a IAP restore has finished
// This method is called both for successful and failed restores
- (void)restoredTransactionsDidFinishWithSuccess:(BOOL)success;

@end


@interface SKProduct (LocalizedPrice)

@property (nonatomic, readonly) NSString *localizedPrice;

@end