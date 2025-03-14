/*
 Copyright 2019 Square Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

#import "RNSQIPCardEntry.h"
#import "RNSQIPErrorUtilities.h"
#import "RNSQIPBuyerVerification.h"
#import "Converters/SQIPCard+RNSQIPAdditions.h"
#import "Converters/SQIPCardDetails+RNSQIPAdditions.h"
#import "Converters/UIFont+RNSQIPAdditions.h"
#import "Converters/UIColor+RNSQIPAdditions.h"

typedef void (^CompletionHandler)(NSError *_Nullable);


@interface RNSQIPCardEntry ()

@property (strong, readwrite) SQIPTheme *theme;
@property (strong, readwrite) CompletionHandler completionHandler;
@property (strong, readwrite) SQIPCardEntryViewController *cardEntryViewController;
@property (strong, readwrite) NSString *locationId;
@property (strong, readwrite) SQIPBuyerAction *buyerAction;
@property (strong, readwrite) SQIPContact *contact;
@property (strong, readwrite) SQIPCardDetails *cardDetails;

@end

static NSString *const RNSQIPCardEntryCancelEventName = @"cardEntryCancel";
static NSString *const RNSQIPCardEntryCompleteEventName = @"cardEntryComplete";
static NSString *const RNSQIPCardEntryDidObtainCardDetailsEventName = @"cardEntryDidObtainCardDetails";
static NSString *const RNSQIPOnBuyerVerificationSuccessEventName = @"onBuyerVerificationSuccess";
static NSString *const RNSQIPOnBuyerVerificationErrorEventName = @"onBuyerVerificationError";

@implementation RNSQIPCardEntry

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents
{
    return @[ RNSQIPCardEntryCancelEventName, RNSQIPCardEntryCompleteEventName, RNSQIPCardEntryDidObtainCardDetailsEventName, RNSQIPOnBuyerVerificationSuccessEventName, RNSQIPOnBuyerVerificationErrorEventName ];
}

RCT_REMAP_METHOD(startCardEntryFlow,
                 collectPostalCode
                 : (BOOL)collectPostalCode
                 startCardEntryFlowWithResolver
                 : (RCTPromiseResolveBlock)resolve
                     rejecter
                 : (RCTPromiseRejectBlock)reject)
{
    dispatch_async([self methodQueue], ^{
        SQIPCardEntryViewController *cardEntryForm = [self _makeCardEntryForm];
        cardEntryForm.collectPostalCode = collectPostalCode;
        cardEntryForm.delegate = self;
        self.cardEntryViewController = cardEntryForm;

        UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
        if ([rootViewController isKindOfClass:[UINavigationController class]]) {
            [((UINavigationController *)rootViewController) pushViewController:cardEntryForm animated:YES];
        } else {
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:cardEntryForm];
            [rootViewController presentViewController:navigationController animated:YES completion:nil];
        }
        resolve([NSNull null]);
    });
}

RCT_REMAP_METHOD(startCardEntryFlowWithVerification,
                 collectPostalCode
                 : (BOOL)collectPostalCode
                 locationId
                 : (NSString *)locationId
                 buyerActionString
                 : (NSString *)buyerActionString
                 moneyMap
                 : (NSDictionary *)moneyMap
                 contactMap
                 : (NSDictionary *)contactMap
                 startCardEntryFlowWithResolver
                 : (RCTPromiseResolveBlock)resolve
                     rejecter
                 : (RCTPromiseRejectBlock)reject)
{
    dispatch_async([self methodQueue], ^{
        SQIPMoney *money = [[SQIPMoney alloc] initWithAmount:[moneyMap[@"amount"] longValue]
                            currency:[RNSQIPBuyerVerification currencyForCurrencyCode:moneyMap[@"currencyCode"]]];

        SQIPBuyerAction *buyerAction = nil;
        if ([@"Store" isEqualToString:buyerActionString]) {
            buyerAction = [SQIPBuyerAction storeAction];
        } else {
            buyerAction = [SQIPBuyerAction chargeActionWithMoney:money];
        }

        SQIPContact *contact = [[SQIPContact alloc] init];
        contact.givenName = contactMap[@"givenName"];

        if (![contactMap[@"familyName"] isEqual:[NSNull null]]) {
            contact.familyName = contactMap[@"familyName"];
        }

        if (![contactMap[@"email"] isEqual:[NSNull null]]) {
            contact.email = contactMap[@"email"];
        }

        if (![contactMap[@"addressLines"] isEqual:[NSNull null]]) {
            contact.addressLines = contactMap[@"addressLines"];
            NSLog(@"%@", contactMap[@"addressLines"]);
        }

        if (![contactMap[@"city"] isEqual:[NSNull null]]) {
            contact.city = contactMap[@"city"];
        }

        if (![contactMap[@"region"] isEqual:[NSNull null]]) {
            contact.region = contactMap[@"region"];
        }

        if (![contactMap[@"postalCode"] isEqual:[NSNull null]]) {
            contact.postalCode = contactMap[@"postalCode"];
        }

        contact.country = [RNSQIPBuyerVerification countryForCountryCode:contactMap[@"countryCode"]];

        if (![contactMap[@"phone"] isEqual:[NSNull null]]) {
            contact.phone = contactMap[@"phone"];
        }

        self.locationId = locationId;
        self.buyerAction = buyerAction;
        self.contact = contact;
        SQIPCardEntryViewController *cardEntryForm = [self _makeCardEntryForm];
        cardEntryForm.collectPostalCode = collectPostalCode;
        cardEntryForm.delegate = self;
        self.cardEntryViewController = cardEntryForm;

        UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
        if ([rootViewController isKindOfClass:[UINavigationController class]]) {
            [((UINavigationController *)rootViewController) pushViewController:cardEntryForm animated:YES];
        } else {
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:cardEntryForm];
            [rootViewController presentViewController:navigationController animated:YES completion:nil];
        }
        resolve([NSNull null]);
    });
}

RCT_REMAP_METHOD(startGiftCardEntryFlow,
                 startCardEntryFlowWithResolver
                 : (RCTPromiseResolveBlock)resolve
                     rejecter
                 : (RCTPromiseRejectBlock)reject)
{
    dispatch_async([self methodQueue], ^{
        SQIPCardEntryViewController *cardEntryForm = [self _makeGiftCardEntryForm];
        cardEntryForm.delegate = self;
        self.cardEntryViewController = cardEntryForm;

        UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
        if ([rootViewController isKindOfClass:[UINavigationController class]]) {
            [((UINavigationController *)rootViewController) pushViewController:cardEntryForm animated:YES];
        } else {
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:cardEntryForm];
            [rootViewController presentViewController:navigationController animated:YES completion:nil];
        }
        resolve([NSNull null]);
    });
}

RCT_REMAP_METHOD(completeCardEntry,
                 completeCardEntryWithResolver
                 : (RCTPromiseResolveBlock)resolve
                     rejecter
                 : (RCTPromiseRejectBlock)reject)
{
    dispatch_async([self methodQueue], ^{
        if (self.completionHandler) {
            self.completionHandler(nil);
            self.completionHandler = nil;
        }
        resolve([NSNull null]);
    });
}

RCT_REMAP_METHOD(showCardNonceProcessingError,
                 errorMessage
                 : (NSString *)errorMessage
                     showCardNonceProcessingErrorWithResolver
                 : (RCTPromiseResolveBlock)resolve
                     rejecter
                 : (RCTPromiseRejectBlock)reject)
{
    dispatch_async([self methodQueue], ^{
        if (self.completionHandler) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey : errorMessage
            };
            NSError *error = [NSError errorWithDomain:NSGlobalDomain
                                                 code:RNSQIPCardEntryErrorCode
                                             userInfo:userInfo];
            self.completionHandler(error);
        }
        resolve([NSNull null]);
    });
}

RCT_REMAP_METHOD(setTheme,
                 theme
                 : (NSDictionary *)theme
                     setThemeWithResolver
                 : (RCTPromiseResolveBlock)resolve
                     rejecter
                 : (RCTPromiseRejectBlock)reject)
{
    dispatch_async([self methodQueue], ^{
        // Create a new theme with default value
        self.theme = [[SQIPTheme alloc] init];
        if (theme[@"font"]) {
            self.theme.font = [self.theme.font fromJsonDictionary:theme[@"font"]];
        }
        if (theme[@"saveButtonFont"]) {
            self.theme.saveButtonFont = [self.theme.saveButtonFont fromJsonDictionary:theme[@"saveButtonFont"]];
        }
        if (theme[@"backgroundColor"]) {
            self.theme.backgroundColor = [self.theme.backgroundColor fromJsonDictionary:theme[@"backgroundColor"]];
        }
        if (theme[@"foregroundColor"]) {
            self.theme.foregroundColor = [self.theme.foregroundColor fromJsonDictionary:theme[@"foregroundColor"]];
        }
        if (theme[@"textColor"]) {
            self.theme.textColor = [self.theme.textColor fromJsonDictionary:theme[@"textColor"]];
        }
        if (theme[@"placeholderTextColor"]) {
            self.theme.placeholderTextColor = [self.theme.placeholderTextColor fromJsonDictionary:theme[@"placeholderTextColor"]];
        }
        if (theme[@"tintColor"]) {
            self.theme.tintColor = [self.theme.tintColor fromJsonDictionary:theme[@"tintColor"]];
        }
        if (theme[@"messageColor"]) {
            self.theme.messageColor = [self.theme.messageColor fromJsonDictionary:theme[@"messageColor"]];
        }
        if (theme[@"errorColor"]) {
            self.theme.errorColor = [self.theme.errorColor fromJsonDictionary:theme[@"errorColor"]];
        }
        if (theme[@"saveButtonTitle"]) {
            self.theme.saveButtonTitle = theme[@"saveButtonTitle"];
        }
        if (theme[@"saveButtonTextColor"]) {
            self.theme.saveButtonTextColor = [self.theme.saveButtonTextColor fromJsonDictionary:theme[@"saveButtonTextColor"]];
        }
        if (theme[@"keyboardAppearance"]) {
            self.theme.keyboardAppearance = [self _keyboardAppearanceFromString:theme[@"keyboardAppearance"]];
        }
        resolve([NSNull null]);
    });
}

RCT_REMAP_METHOD(verifyBuyerCard,
                 cardId
                 : (NSString *)cardId
                 collectPostalCode
                 : (BOOL)collectPostalCode
                 locationId
                 : (NSString *)locationId
                 buyerActionString
                 : (NSString *)buyerActionString
                 moneyMap
                 : (NSDictionary *)moneyMap
                 contactMap
                 : (NSDictionary *)contactMap
                 startCardEntryFlowWithResolver
                 : (RCTPromiseResolveBlock)resolve
                     rejecter
                 : (RCTPromiseRejectBlock)reject)
{
    dispatch_async([self methodQueue], ^{
        SQIPMoney *money = [[SQIPMoney alloc] initWithAmount:[moneyMap[@"amount"] longValue]
                            currency:[RNSQIPBuyerVerification currencyForCurrencyCode:moneyMap[@"currencyCode"]]];

        SQIPBuyerAction *buyerAction = nil;
        if ([@"Store" isEqualToString:buyerActionString]) {
            buyerAction = [SQIPBuyerAction storeAction];
        } else {
            buyerAction = [SQIPBuyerAction chargeActionWithMoney:money];
        }

        SQIPContact *contact = [[SQIPContact alloc] init];
        contact.givenName = contactMap[@"givenName"];

        if (![contactMap[@"familyName"] isEqual:[NSNull null]]) {
            contact.familyName = contactMap[@"familyName"];
        }

        if (![contactMap[@"email"] isEqual:[NSNull null]]) {
            contact.email = contactMap[@"email"];
        }

        if (![contactMap[@"addressLines"] isEqual:[NSNull null]]) {
            contact.addressLines = contactMap[@"addressLines"];
            NSLog(@"%@", contactMap[@"addressLines"]);
        }

        if (![contactMap[@"city"] isEqual:[NSNull null]]) {
            contact.city = contactMap[@"city"];
        }

        if (![contactMap[@"region"] isEqual:[NSNull null]]) {
            contact.region = contactMap[@"region"];
        }

        if (![contactMap[@"postalCode"] isEqual:[NSNull null]]) {
            contact.postalCode = contactMap[@"postalCode"];
        }

        contact.country = [RNSQIPBuyerVerification countryForCountryCode:contactMap[@"countryCode"]];

        if (![contactMap[@"phone"] isEqual:[NSNull null]]) {
            contact.phone = contactMap[@"phone"];
        }

        self.locationId = locationId;
        self.buyerAction = buyerAction;
        self.contact = contact;

        UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;

        NSString *paymentSourceId = cardId;
        SQIPVerificationParameters *params = [[SQIPVerificationParameters alloc] initWithPaymentSourceID:paymentSourceId
                                                buyerAction:self.buyerAction
                                                locationID:self.locationId
                                                contact:self.contact];

        if ([rootViewController isKindOfClass:[UINavigationController class]]) {
            [rootViewController.navigationController popViewControllerAnimated:YES];
        } else {
            [rootViewController dismissViewControllerAnimated:YES completion:nil];
        }

        [SQIPBuyerVerificationSDK.shared verifyWithParameters:params
            theme:self.theme
            viewController:rootViewController
            success:^(SQIPBuyerVerifiedDetails *_Nonnull verifiedDetails) {
                NSDictionary *verificationResult =
                    @{
                        @"card_id" : cardId,
                        @"token" : verifiedDetails.verificationToken
                    };

                [self sendEventWithName:RNSQIPOnBuyerVerificationSuccessEventName
                    body:verificationResult];
            }
            failure:^(NSError *_Nonnull error) {
                NSString *debugCode = error.userInfo[SQIPErrorDebugCodeKey];
                NSString *debugMessage = error.userInfo[SQIPErrorDebugMessageKey];
                [self sendEventWithName:RNSQIPOnBuyerVerificationErrorEventName
                    body:[RNSQIPErrorUtilities callbackErrorObject:RNSQIPUsageError
                                    message:error.localizedDescription
                                    debugCode:debugCode
                                    debugMessage:debugMessage]];
            }];

        resolve([NSNull null]);
    });
}

#pragma mark - Card Entry delegates Methods
- (void)cardEntryViewController:(SQIPCardEntryViewController *)cardEntryViewController didObtainCardDetails:(SQIPCardDetails *)cardDetails completionHandler:(CompletionHandler)completionHandler
{
    if (self.contact) {
        self.cardDetails = cardDetails;
        // If buyer verification is needed, complete the card entry form so we can verify buyer
        // This is to maintain consistent behavior with Android platform
        completionHandler(nil);
    } else {
        self.completionHandler = completionHandler;
        [self sendEventWithName:RNSQIPCardEntryDidObtainCardDetailsEventName body:[cardDetails jsonDictionary]];
    }
}

- (void)cardEntryViewController:(SQIPCardEntryViewController *)cardEntryViewController didCompleteWithStatus:(SQIPCardEntryCompletionStatus)status
{
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;

    if (self.contact && status == SQIPCardEntryCompletionStatusSuccess) {
        NSString *paymentSourceId = self.cardDetails.nonce;
        SQIPVerificationParameters *params = [[SQIPVerificationParameters alloc] initWithPaymentSourceID:paymentSourceId
                                                buyerAction:self.buyerAction
                                                locationID:self.locationId
                                                contact:self.contact];

        if ([rootViewController isKindOfClass:[UINavigationController class]]) {
            [rootViewController.navigationController popViewControllerAnimated:YES];
        } else {
            [rootViewController dismissViewControllerAnimated:YES completion:nil];
        }

        [SQIPBuyerVerificationSDK.shared verifyWithParameters:params
            theme:self.theme
            viewController:rootViewController
            success:^(SQIPBuyerVerifiedDetails *_Nonnull verifiedDetails) {
                NSDictionary *verificationResult =
                    @{
                        @"nonce" : self.cardDetails.nonce,
                        @"card" : [self.cardDetails.card jsonDictionary],
                        @"token" : verifiedDetails.verificationToken
                    };

                [self sendEventWithName:RNSQIPOnBuyerVerificationSuccessEventName
                    body:verificationResult];
            }
            failure:^(NSError *_Nonnull error) {
                NSString *debugCode = error.userInfo[SQIPErrorDebugCodeKey];
                NSString *debugMessage = error.userInfo[SQIPErrorDebugMessageKey];
                [self sendEventWithName:RNSQIPOnBuyerVerificationErrorEventName
                    body:[RNSQIPErrorUtilities callbackErrorObject:RNSQIPUsageError
                                    message:error.localizedDescription
                                    debugCode:debugCode
                                    debugMessage:debugMessage]];
            }];
        return;
    }

    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        [rootViewController.navigationController popViewControllerAnimated:YES];
        if (status == SQIPCardEntryCompletionStatusCanceled) {
            [self sendEventWithName:RNSQIPCardEntryCancelEventName body:nil];
        } else {
            [self sendEventWithName:RNSQIPCardEntryCompleteEventName body:nil];
        }
    } else {
        if (status == SQIPCardEntryCompletionStatusCanceled) {
            [rootViewController dismissViewControllerAnimated:YES completion:^{
                [self sendEventWithName:RNSQIPCardEntryCancelEventName body:nil];
            }];
        } else {
            [rootViewController dismissViewControllerAnimated:YES completion:^{
                [self sendEventWithName:RNSQIPCardEntryCompleteEventName body:nil];
            }];
        }
    }
}

#pragma mark - Private Methods
- (SQIPCardEntryViewController *)_makeCardEntryForm
{
    if (self.theme == nil) {
        self.theme = [[SQIPTheme alloc] init];
    }

    return [[SQIPCardEntryViewController alloc] initWithTheme:self.theme];
}

- (SQIPCardEntryViewController *)_makeGiftCardEntryForm
{
    if (self.theme == nil) {
        self.theme = [[SQIPTheme alloc] init];
    }

    return [[SQIPCardEntryViewController alloc] initWithTheme:self.theme isGiftCard:true];
}

- (UIKeyboardAppearance)_keyboardAppearanceFromString:(NSString *)keyboardTypeName
{
    if ([keyboardTypeName isEqualToString:@"Dark"]) {
        return UIKeyboardAppearanceDark;
    } else if ([keyboardTypeName isEqualToString:@"Light"]) {
        return UIKeyboardAppearanceLight;
    } else {
        return UIKeyboardAppearanceDefault;
    }
}

@end
