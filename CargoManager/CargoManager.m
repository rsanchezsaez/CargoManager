//
//  CargoManager.m
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

#import "CargoManager.h"

#import "CargoBay.h"


NSString *const CMProductRequestDidReceiveResponseNotification = @"CMProductRequestDidReveiveResponseNotification";


NSString *const CMTransactionFailedAlertTitle = @"In App Purchase failed";
NSString *const CMTransactionFailedAlertMessage = @"The purchase failed due to an error. Please, try again later.";

NSString *const CMCannotMakePaymentsAlertTitle = @"In App Purchases are disabled";
NSString *const CMCannotMakePaymentsAlertMessage = @"You can enable them again in Settings.";

NSString *const CMAlertCancelButtonTitle = @"Ok";


@interface CargoManager ()

@property (nonatomic) BOOL productRequestDidReceiveResponse;
@property (nonatomic) BOOL productRequestError;
@property (nonatomic) NSArray *cachedProducts;

@end

@implementation CargoManager

static CargoManager *_storeKitManager = nil;

+ (CargoManager *)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
    ^
    {
        _storeKitManager = [[CargoManager alloc] init];
    });
    return _storeKitManager;
}

- (id)init
{
    if (_storeKitManager)
    {
        return _storeKitManager;
    }

    if ( !(self = [super init]) )
    {
        return nil;
    }

    self.productRequestDidReceiveResponse = NO;

    return self;
}

- (void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:[CargoBay sharedManager]];
}

// Call this method once in your AppDelegate's -(void)application:didFinishLaunchingWithOptions: method
- (void)loadStore
{
    // Set CargoBay as App Store transaction observer
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[CargoBay sharedManager]];

    [self loadProducts];
    
    __weak CargoManager *weakSelf = self;
    [[CargoBay sharedManager] setPaymentQueueUpdatedTransactionsBlock:
    ^(SKPaymentQueue *queue, NSArray *transactions)
    {
        for (SKPaymentTransaction *transaction in transactions)
        {
            [weakSelf transactionUpdated:transaction];
        }
        
    }];
    
    [[CargoBay sharedManager] setPaymentQueueRemovedTransactionsBlock:
     ^(SKPaymentQueue *queue, NSArray *transactions)
    {
        for (SKPaymentTransaction *transaction in transactions)
        {
            [weakSelf transactionRemoved:transaction];
        }
    }];
    
    [[CargoBay sharedManager] setPaymentQueueRestoreCompletedTransactionsWithSuccess:
     ^(SKPaymentQueue *queue)
    {
        [self restoredCompletedTransactionsWithError:nil];
    } failure:
     ^(SKPaymentQueue *queue, NSError *error)
    {
        [weakSelf restoredCompletedTransactionsWithError:error];
    }];
    
    [[CargoBay sharedManager] setPaymentQueueUpdatedDownloadsBlock:
     ^(SKPaymentQueue *queue, NSArray *downloads)
    {
        for (SKDownload *download in downloads)
        {
            [weakSelf downloadUpdated:download];
        }        
    }];
}

- (void)loadProducts
{
    NSArray *identifiers = [self.contentDelegate productIdentifiers];

    __weak CargoManager *weakSelf = self;
    [[CargoBay sharedManager] productsWithIdentifiers:[NSSet setWithArray:identifiers]
                                              success:
     ^(NSArray *products, NSArray *invalidIdentifiers)
    {
         // Store cached products and send notification
         weakSelf.cachedProducts = products;
         weakSelf.productRequestDidReceiveResponse = YES;
         weakSelf.productRequestError = NO;

         [weakSelf _postProductRequestDidReceiveResponseNotificationWithError:nil];

         // DLog(@"Products: %@", products);
         // DLog(@"Invalid Identifiers: %@", invalidIdentifiers);
     }
                                              failure:
     ^(NSError *error)
    {
         // Note error and send notification
         weakSelf.productRequestDidReceiveResponse = YES;
         weakSelf.productRequestError = YES;

         [weakSelf _postProductRequestDidReceiveResponseNotificationWithError:error];

         // DLog(@"Error: %@", error);
     }];
}

// Posts the products received notification.
// If there was an error, it creates the userInfo dictionary and adds the error there
- (void)_postProductRequestDidReceiveResponseNotificationWithError:(NSError *)error
{
    NSDictionary *notificationInfo = nil;
    if (error)
    {
        notificationInfo = @{ @"error" : error };
    }
    NSNotification *notification = [NSNotification notificationWithName:CMProductRequestDidReceiveResponseNotification
                                                                 object:self
                                                               userInfo:notificationInfo];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void)transactionUpdated:(SKPaymentTransaction *)transaction
{
    // DLog(@"{ transaction.transactionState: %d }", transaction.transactionState);
    switch (transaction.transactionState)
    {
        case SKPaymentTransactionStatePurchased:
        {
            __weak CargoManager *weakSelf = self;
            [[CargoBay sharedManager] verifyTransaction:transaction
                                               password:nil
                                                success:
             ^(NSDictionary *receipt)
            {
                // DLog(@"Transaction verified.");
                [weakSelf completeTransaction:transaction];
            }
                                                failure:
             ^(NSError *error)
            {
                // DLog(@"Transaction vertification failed.");
                [weakSelf transactionFailed:transaction];
            }];
        } break;
        case SKPaymentTransactionStateFailed:
            [self transactionFailed:transaction];
            break;
        case SKPaymentTransactionStateRestored:
            [self restoreTransaction:transaction];
        default:
            break;
    }    
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction
{
    // DLog(@"");

    [self recordTransaction:transaction];
    [self.contentDelegate provideContentForProductIdentifier:transaction.payment.productIdentifier];
    
    // Remove the transaction from the payment queue
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction
{
    // DLog(@"");

    [self recordTransaction:transaction];
    [self.contentDelegate provideContentForProductIdentifier:transaction.originalTransaction.payment.productIdentifier];
    
    // Remove the transaction from the payment queue
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)transactionFailed:(SKPaymentTransaction *)transaction
{
    // DLog(@"{ transaction.error: %@ }", transaction.error);

    if (transaction.error.code != SKErrorPaymentCancelled) {
        // Display a transaction error here
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:CMTransactionFailedAlertTitle
                                                        message:CMTransactionFailedAlertMessage
                                                       delegate:nil
                                              cancelButtonTitle:CMAlertCancelButtonTitle
                                              otherButtonTitles:nil];
        [alert show];
    }
    
    // Remove the transaction from the payment queue
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)transactionRemoved:(SKPaymentTransaction *)transaction
{
    // DLog(@"{ transaction.transactionState: %d transaction.error: %@ }",
    //     transaction.transactionState,
    //     transaction.error);

    switch (transaction.transactionState)
    {
        case SKPaymentTransactionStatePurchased:
        case SKPaymentTransactionStateRestored:
            // DBLog(@" Successfull transaction removed.");

            [self.UIDelegate transactionDidFinishWithSuccess:YES];
            break;
        case SKPaymentTransactionStateFailed:
        default:
            // DBLog(@" Failed transaction removed.");

            [self.UIDelegate transactionDidFinishWithSuccess:NO];
            break;
    }
}

- (void)recordTransaction:(SKPaymentTransaction *)transaction
{
    if ( [self.contentDelegate respondsToSelector:@selector(recordTransaction:)] )
    {
        [self.contentDelegate recordTransaction:transaction];
    }
}

- (void)restoredCompletedTransactionsWithError:(NSError *)error
{
    if ( [self.UIDelegate respondsToSelector:@selector(restoredTransactionsDidFinishWithSuccess:)] )
    {
        [self.UIDelegate restoredTransactionsDidFinishWithSuccess:( error == nil )];
    }
}

- (void)downloadUpdated:(SKDownload *)download
{
    if ( [self.contentDelegate respondsToSelector:@selector(downloadUpdated:)] )
    {
        [self.contentDelegate downloadUpdated:download];
    }
}

- (SKProduct *)productForIdentifier:(NSString *)identifier
{
    for (SKProduct *product in self.cachedProducts)
    {
        if ( [product.productIdentifier isEqualToString:identifier] )
        {
            return product;
        }
    }
    return nil;
}

- (void)buyProduct:(SKProduct *)product
{
    if ([SKPaymentQueue canMakePayments])
    {
        // DLog(@"Queuing payment.")
        // Queue payment
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
    else
    {
        // DLog(@"IAP are disabled.")
        // Warn the user that purchases are disabled.
        // Display a transaction error here
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:CMCannotMakePaymentsAlertTitle
                                                        message:CMCannotMakePaymentsAlertMessage
                                                       delegate:nil
                                              cancelButtonTitle:CMAlertCancelButtonTitle
                                              otherButtonTitles:nil];
        [alert show];
    }
}

@end
 

@implementation SKProduct (LocalizedPrice)

- (NSString *)localizedPrice
{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    // Needed in case the default behaviour has been set elsewhere
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:self.priceLocale];
    return [numberFormatter stringFromNumber:self.price];
}

@end
