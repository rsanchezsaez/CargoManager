# CargoBayManager
**The Essential CargoBay Companion**

[`StoreKit`](http://developer.apple.com/library/ios/#documentation/StoreKit/Reference/StoreKit_Collection/) is the Apple framework for [making In-App Purchases](http://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/StoreKitGuide/Introduction/Introduction.html). It's pretty good, but it is ver low level and has a few rough edges. [CargoBay](https://github.com/mattt/CargoBay) is really nifty, but it keeps coding of In-App Purchases quite at a low level and it still is an involved process. 

`CargoBayManager` abstracts everything, by providing a simple and pretty much automated manager for your In-App Purchases. With `CargoBayManager` you only have to implement two protocols in your own classes. You will need these as `CargoBayManager` delegates:
- An object conforming to the `CargoBayManagerContentDelegate` protocol. This delegate is mandatory. It provides all available ProductID strings to CargoBay, and caches the returned products (for store population). It also should respond to successful transaction events by providing the user requested content and storing it persistently to disk. Ideally, this delegate should be a singleton and should be alive at all times (a transaction is kept as pending even after relaunching the game, so it can complete even when you are not looking at the store UI).
- An object conforming to the `CargoBayManagerUIDelegate` protocol. This delegate is optional. It should update the UI on both transaction successful and transaction failed events (if you create a modal "processing IAP screen" you can dismiss it by using this delegate).

In addition to the protocols, CargoBayManager provides these methods:

```objective-c
// Call this method after setting the contentDelegate
// it setups CargoBayManager to work with CargoBay and
// launches the initial product request.
- (void)loadStore;

// Get a product from the cached products
- (SKProduct *)productForIdentifier:(NSString *)identifier;

// Start an In-App purchase
- (void)buyProduct:(SKProduct *)product;
```

Finally, CargoBayManager provides the productRequestDidReceiveResponse and productRequestError BOOL properties and also sends the 'SMProductRequestDidReceiveResponseNotification' notification after it caches the products. These are needed because if you enter the store quick enough after the app launches, the initial product request will not have resolved from Apple servers yet, so you won't be able to populate item prices. Instead, you can observe this notification to populate your store UI as soon as they load (you can do that even having the store UI open in your app, as to not artificially delay the user entering the store).

Last but not least, CargoBayManager includes a category for Apple's SKProduct, which provides the following
```objective-c
@property (nonatomic, readonly) NSString *localizedPrice;
```
which returns the product price formatted as a currency string in the user locale.


## Usage

### Initial setup

**AppDelegate.m**

```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Initialize CargoBayManager (you have to implement the contentDelegate first!)
    [CargoBayManager sharedManager].contentDelegate = [GameData sharedData];
	// This call sends a product request to CargoBay and caches the resulting products
    [[CargoBayManager sharedManager] loadStore];

    return YES;
}
```

### contentDelegate sample implementation

```objective-c
- (NSArray *)productIdentifiers
{
    NSMutableArray *productIdentifiers = [[NSMutableArray alloc] init];

	// Populate the productIdentifiers

    // Return a non-mutable copy
    return [NSArray arrayWithArray:productIdentifiers];
}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier
{
    // Implement the result of a successful IAP
    // on the according productIdentifier

    // Save user data to disk
}
```

### UIDelegate sample implementation

```objective-c
- (void)transactionDidFinishWithSuccess:(BOOL)success
{
    if ( success )
    {
        // Close store UI ?
    }
    else
    {
		// Do not close the store ? Further notify the user about the error?
    }    
}
```

### CargoBayManagerContentDelegate protocol specification

```objective-c
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
```

### CargoBayManagerUIDelegate protocol specification

```objective-c
@protocol CargoBayManagerUIDelegate <NSObject>

// Implement this method to update UI after a IAP has finished
// This method is called both for successful and failed transactions
- (void)transactionDidFinishWithSuccess:(BOOL)success;

@optional

// Implement this method to update UI after a IAP restore has finished
// This method is called both for successful and failed restores
- (void)restoredTransactionsDidFinishWithSuccess:(BOOL)success;

@end
```

### Contact

[Ricardo Sánchez-Sáez](http://sanchez-saez.com)  

## License

CargoBayManager is available under the MIT license. See the LICENSE file for more info.
