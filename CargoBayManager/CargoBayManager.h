//
//  CargoBayManager.h
//
//  Copyright (c) 2013 Ricardo Sánchez-Sáez (http://sanchez-saez.com/)
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, this
//     list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//      and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <StoreKit/StoreKit.h>


extern NSString *const CMProductRequestDidReceiveResponseNotification;


@class SKProduct;
@protocol CargoBayManagerUIDelegate;
@protocol CargoBayManagerContentDelegate;


@interface CargoBayManager : NSObject

@property (nonatomic, readonly) BOOL productRequestDidReceiveResponse;
@property (nonatomic, readonly) BOOL productRequestError;

@property (nonatomic, weak) id <CargoBayManagerContentDelegate>  contentDelegate;
@property (nonatomic, weak) id <CargoBayManagerUIDelegate>  UIDelegate;

+ (CargoBayManager *)sharedManager;

- (void)loadStore;
- (SKProduct *)productForIdentifier:(NSString *)identifier;

- (void)buyProduct:(SKProduct *)product;

@end


@protocol CargoBayManagerContentDelegate <NSObject>

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


@protocol CargoBayManagerUIDelegate <NSObject>

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