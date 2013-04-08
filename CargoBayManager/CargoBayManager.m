//
//  CargoBayManager.m
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

#import "CargoBayManager.h"

#import "CargoBay.h"


NSString *const SMProductRequestDidReceiveResponseNotification = @"SMProductRequestDidReveiveResponseNotification";


NSString *const SMTransactionFailedAlertTitle = @"In App Purchase failed";
NSString *const SMTransactionFailedAlertMessage = @"The purchase failed due to an error. Please, try again later.";

NSString *const SMCannotMakePaymentsAlertTitle = @"In App Purchases are disabled";
NSString *const SMCannotMakePaymentsAlertMessage = @"You can enable them again in Settings.";

NSString *const SMAlertCancelButtonTitle = @"Ok";


@interface CargoBayManager ()

@property (nonatomic) BOOL productRequestDidReceiveResponse;
@property (nonatomic) BOOL productRequestError;
@property (nonatomic) NSArray *cachedProducts;

@end

@implementation CargoBayManager

static CargoBayManager *_storeKitManager = nil;

+ (CargoBayManager *)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _storeKitManager = [[CargoBayManager alloc] init];
    });
    return _storeKitManager;
}

- (id)init
{
    if (_storeKitManager) {
        return _storeKitManager;
    }

    if ( !(self = [super init]) ) {
        return nil;
    }

    self.productRequestDidReceiveResponse = NO;

    return self;
}

// Call this method once in your AppDelegate's -(void)application:didFinishLaunchingWithOptions: method
- (void)loadStore
{
    // Set CargoBay as App Store transaction observer
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[CargoBay sharedManager]];

    [self loadProducts];
    
    __weak CargoBayManager *weakSelf = self;
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

    [[NSNotificationCenter defaultCenter] addObserver:nil selector:nil name:UIWindowDidBecomeKeyNotification object:nil];

    __weak CargoBayManager *weakSelf = self;
    [[CargoBay sharedManager] productsWithIdentifiers:[NSSet setWithArray:identifiers]
                                              success:
     ^(NSArray *products, NSArray *invalidIdentifiers) {
         // Store cached products and send notification
         weakSelf.cachedProducts = products;
         weakSelf.productRequestDidReceiveResponse = YES;
         weakSelf.productRequestError = NO;

         [weakSelf _postProductRequestDidReceiveResponseNotificationWithError:nil];

         // DLog(@"Products: %@", products);
         // DLog(@"Invalid Identifiers: %@", invalidIdentifiers);
     }
                                              failure:
     ^(NSError *error) {
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
    if (error) {
        notificationInfo = @{ @"error" : error };
    }
    NSNotification *notification = [NSNotification notificationWithName:SMProductRequestDidReceiveResponseNotification
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
            __weak CargoBayManager *weakSelf = self;
            [[CargoBay sharedManager] verifyTransaction:transaction
                                               password:nil
                                                success:
             ^(NSDictionary *receipt)
            {
                // DLog(@"Transaction verified.");
                [weakSelf completeTransaction:transaction];
            } failure:
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
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SMTransactionFailedAlertTitle
                                                        message:SMTransactionFailedAlertMessage
                                                       delegate:nil
                                              cancelButtonTitle:SMAlertCancelButtonTitle
                                              otherButtonTitles:nil];
        [alert show];
    }
    
    // Remove the transaction from the payment queue
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)transactionRemoved:(SKPaymentTransaction *)transaction
{
    // DLog(@"{ transaction.transactionState: %d transaction.error: %@ }",
         transaction.transactionState,
         transaction.error);

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
    if ([SKPaymentQueue canMakePayments]) {
        // DLog(@"Queuing payment.")
        // Queue payment
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    } else {
        // DLog(@"IAP are disabled.")
        // Warn the user that purchases are disabled.
        // Display a transaction error here
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SMCannotMakePaymentsAlertTitle
                                                        message:SMCannotMakePaymentsAlertMessage
                                                       delegate:nil
                                              cancelButtonTitle:SMAlertCancelButtonTitle
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
