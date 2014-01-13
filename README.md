*NEW: Check out the [CargoManager Example iOS App](https://github.com/rsanchezsaez/CargoManagerExample).*

# CargoManager
**Implement StoreKit easily**


`CargoManager` is an open source library that helps you implement IAPs for iOS apps in a simple and encapsulated way by using the  by using the [delegate pattern](https://developer.apple.com/library/ios/#documentation/General/Conceptual/DevPedia-CocoaCore/Delegation.html).

[`StoreKit`](http://developer.apple.com/library/ios/#documentation/StoreKit/Reference/StoreKit_Collection/) is the Apple framework for [making In-App Purchases](http://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/StoreKitGuide/Introduction/Introduction.html). It's pretty good but it is very low level and has a few rough edges. [`CargoBay`](https://github.com/mattt/CargoBay) is really nifty, but it keeps coding of In-App Purchases quite at a low level and it still is an involved process. 

`CargoManager` abstracts most details of *StoreKit* and *CargoBay* by providing a simple and pretty much automated manager for your In-App Purchases.

With *CargoManager* you only have to implement two protocols in your own classes. You will need to set these objects as *CargoManager* delegates:
- An object conforming to the `CargoManagerContentDelegate` protocol. This delegate is mandatory. It provides all available Product ID strings to *CargoManager* (which in turn caches the returned products for store population). It also should respond to successful transaction events by providing the user requested content and storing it persistently to disk. Ideally, this delegate should be a singleton and should be alive at all times (a transaction is kept as pending even after relaunching the game, so it can complete even when you are not looking at the store UI).
- An object conforming to the `CargoManagerUIDelegate` protocol. This delegate is optional. It should update the UI on both transaction successful and transaction failed events (if you create a modal "processing IAP screen" you can dismiss it by using this delegate).

Please note that before attempting to use `CargoManager` or `CargoBay` it is strongly recommended that you fully understand how StoreKit works. The [In-App Purchase Programming Guide](http://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/StoreKitGuide/Introduction/Introduction.html) by Apple provides a concise and gentle introduction.

---

In addition to the protocols, you will need to call these provided methods:

```objective-c
// Call this method after setting the contentDelegate
// it setups CargoManager to work with CargoBay and
// launches the initial product request.
- (void)loadStore;

// Get a product from the cached products.
- (SKProduct *)productForIdentifier:(NSString *)identifier;

// Start an In-App purchase.
- (void)buyProduct:(SKProduct *)product;
```

Finally, `CargoManager` provides the following properties:
```objective-c
@property (nonatomic, readonly) BOOL productRequestDidReceiveResponse;
@property (nonatomic, readonly) BOOL productRequestError;
```
and also sends the `CMProductRequestDidReceiveResponseNotification` notification after it caches the products. These are needed because if you enter the store quick enough after the app launches, the initial product request will not have resolved from Apple servers yet, so you won't be able to populate item prices. Instead, you can observe this notification to populate your store UI as soon as they load (you can do that even having the store UI open in your app, as to not artificially delay the user entering the store).

Last but not least, CargoManager includes a category for Apple's SKProduct, which provides the following
```objective-c
@property (nonatomic, readonly) NSString *localizedPrice;
```
which returns the product price formatted as a currency string in the user locale.


## Usage

### Initial setup 

```objective-c
// Your AppDelegate.m
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Initialize CargoManager (you have to implement the contentDelegate first!).
    [CargoManager sharedManager].contentDelegate = [GameData sharedData];

	// This call sends a product request to CargoBay and caches the resulting products.
    [[CargoManager sharedManager] loadStore];

    return YES;
}
```

### contentDelegate sample implementation

```objective-c
// contentDelegate should be a singleton object available at all times through the lifetime of your app
- (NSArray *)productIdentifiers
{
    NSMutableArray *productIdentifiers = [[NSMutableArray alloc] init];

	// Populate the productIdentifiers.
	// YOUR CODE GOES HERE

    // Return a non-mutable copy.
    return [NSArray arrayWithArray:productIdentifiers];
}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier
{
    // Implement the result of a successful IAP
    // on the according productIdentifier.
	// YOUR CODE GOES HERE

    // Save user data to disk.
	// YOUR CODE GOES HERE
}
```

### UIDelegate sample implementation

```objective-c
// UIDelegate is optional. Normally, it will be your StoreViewController.
- (void)transactionDidFinishWithSuccess:(BOOL)success
{
    if ( success )
    {
        // Close store UI ?
		// YOUR CODE GOES HERE
    }
    else
    {
		// Do not close the store ? Further notify the user about the error?
		// YOUR CODE GOES HERE
    }    
}

// You can respond to the CMProductRequestDidReceiveResponseNotification in the following manner.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadStoreProducts:)
                                                 name:CMProductRequestDidReceiveResponseNotification
                                               object:[CargoManager sharedManager]];
}
```

### CargoManagerContentDelegate protocol specification

```objective-c
@protocol CargoManagerContentDelegate <NSObject>

// This method should return an array with all the productIdentifiers used by your App.
- (NSArray *)productIdentifiers;

// Implement this method to provide content.
- (void)provideContentForProductIdentifier:(NSString *)productIdentifier;

@optional

// Use this method if you want to store the transaction for your records.
- (void)recordTransaction:(SKPaymentTransaction *)transaction;

// Use this method to manage download data.
- (void)downloadUpdated:(SKDownload *)download;

@end
```

### CargoManagerUIDelegate protocol specification

```objective-c
@protocol CargoManagerUIDelegate <NSObject>

// Implement this method to update UI after a IAP has finished.
// This method is called both for successful and failed transactions.
- (void)transactionDidFinishWithSuccess:(BOOL)success;

@optional

// Implement this method to update UI after a IAP restore has finished.
// This method is called both for successful and failed restores.
- (void)restoredTransactionsDidFinishWithSuccess:(BOOL)success;

@end
```

## Apps

CargoManager is used by [Trivia Pics Party!](http://appstore.com/triviapicsparty).

If your app and company uses CargoManager and want it listed here, just drop me a line.

## License & Contact

CargoManager is available under the FreeBSD license so you can use it for commercial applications. See the LICENSE file for more info.

It is maintained by [Ricardo Sánchez-Sáez](http://sanchez-saez.com) (rsanchez.saez [at] gmail [dot] com).
