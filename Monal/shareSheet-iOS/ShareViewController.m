//
//  ShareViewController.m
//  shareSheet
//
//  Created by Anurodh Pokharel on 9/10/18.
//  Copyright © 2018 Monal.im. All rights reserved.
//

#import "ShareViewController.h"
#import "MLSelectionController.h"

#import "UIColor+Theme.h"
#import "MLContact.h"
#import "MLConstants.h"
#import "HelperTools.h"

static void logException(NSException* exception)
{
    [DDLog flushLog];
    DDLogError(@"*** CRASH: %@", exception);
    [DDLog flushLog];
    DDLogError(@"*** Stack Trace: %@", [exception callStackSymbols]);
    [DDLog flushLog];
}

@interface ShareViewController ()

@property (nonatomic, strong) NSDictionary* account;
@property (nonatomic, strong) NSString* recipient;

@property (nonatomic, strong) NSArray* accounts;
@property (nonatomic, strong) NSMutableArray* recipients;


@end

@implementation ShareViewController

+(void) initialize
{
    [HelperTools configureLogging];
    
    //log unhandled exceptions
    NSSetUncaughtExceptionHandler(&logException);
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    [self.navigationController.navigationBar setBackgroundColor:[UIColor monaldarkGreen]];
    self.navigationController.navigationItem.title = NSLocalizedString(@"Monal", @"");
}

- (void)presentationAnimationDidFinish {
    DDLogInfo(@"Monal ShareViewController presentationAnimationDidFinish");
    
    self.accounts = [[HelperTools defaultsDB] objectForKey:@"accounts"];
    NSData* recipientsData = [[HelperTools defaultsDB] objectForKey:@"recipients"];
    
    NSError* error;
    NSSet* objClasses = [NSSet setWithArray:@[[NSMutableArray class], [NSMutableDictionary class]]];
    self.recipients = [NSKeyedUnarchiver unarchivedObjectOfClasses:objClasses fromData:recipientsData error:&error];
    if(error) {
        DDLogError(@"Monal ShareViewController: %@", error);
    }

    self.recipient = [[HelperTools defaultsDB] objectForKey:@"lastRecipient"];
    self.account = [[HelperTools defaultsDB] objectForKey:@"lastAccount"];
    [self reloadConfigurationItems];
}

- (BOOL)isContentValid {
    if(self.recipient.length>0 && self.account!=nil)
    return YES;
    else return NO;
}

- (void)didSelectPost {
    NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
    
    NSExtensionItem* item = self.extensionContext.inputItems.firstObject;
    DDLogVerbose(@"Attachments = %@", item.attachments);
    
    for (NSItemProvider* provider in item.attachments)
    {
       if([provider hasItemConformingToTypeIdentifier:@"public.url"])
       {
           [provider loadItemForTypeIdentifier:@"public.url" options:NULL completionHandler:^(NSURL<NSSecureCoding>*  _Nullable item, NSError * _Null_unspecified error) {
               [payload setObject:item.absoluteString forKey:@"url"];
               if(self.contentText) [payload setObject:self.contentText forKey:@"comment"];
               [payload setObject:self.account forKey:@"account"];
               [payload setObject:self.recipient forKey:@"recipient"];
               
               NSMutableArray *outbox=[[[HelperTools defaultsDB] objectForKey:@"outbox"] mutableCopy];
               if(!outbox) outbox =[[NSMutableArray alloc] init];
               
               [outbox addObject:payload];
               [[HelperTools defaultsDB] setObject:outbox forKey:@"outbox"];
               
               // Save last used account / recipient
               [[HelperTools defaultsDB] setObject:self.account forKey:@"lastAccount"];
               [[HelperTools defaultsDB] setObject:self.recipient forKey:@"lastRecipient"];
               
               [[HelperTools defaultsDB] synchronize];
           }];
       }
    }
    
    
//    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"https://monal.im/wakeios"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//
//
//    }] resume];

     [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

- (NSArray *)configurationItems {
    NSMutableArray *toreturn = [[NSMutableArray alloc] init];
    if(self.accounts.count > 1) {
        SLComposeSheetConfigurationItem* accountSelector = [[SLComposeSheetConfigurationItem alloc] init];
        accountSelector.title=@"Account";

        accountSelector.value=[NSString stringWithFormat:@"%@@%@",[self.account objectForKey:@"username"],[self.account objectForKey:@"domain"]];
        accountSelector.tapHandler = ^{
            UIStoryboard* iosShareStoryboard = [UIStoryboard storyboardWithName:@"iosShare" bundle:nil];
            MLSelectionController* controller = (MLSelectionController*)[iosShareStoryboard instantiateViewControllerWithIdentifier:@"accounts"];
            controller.options= self.accounts;
            controller.completion = ^(NSDictionary *selectedAccount)
            {
                if(selectedAccount) {
                    self.account=selectedAccount;
                }
                else {
                    self.account=nil;
                }
                self.recipient=@"";
                [self reloadConfigurationItems];
            };
            
            [self pushConfigurationViewController:controller];
        };
        [toreturn addObject:accountSelector];
    }
    
    if(!self.account && self.accounts.count>0) {
        self.account = [self.accounts objectAtIndex:0];
        
    }
    
    SLComposeSheetConfigurationItem *recipient = [[SLComposeSheetConfigurationItem alloc] init];
    recipient.title=@"Recipient";
    recipient.value=self.recipient;
    recipient.tapHandler = ^{
        UIStoryboard* iosShareStoryboard = [UIStoryboard storyboardWithName:@"iosShare" bundle:nil];
        MLSelectionController *controller = (MLSelectionController *)[iosShareStoryboard instantiateViewControllerWithIdentifier:@"contacts"];

        // Create list of recipients for the selected account
        NSMutableArray *recipientsToShow = [[NSMutableArray alloc] init];
        for (NSMutableDictionary* row in self.recipients) {
            if([[row objectForKey:@"account_id"] integerValue] == [[self.account objectForKey:@"account_id"] integerValue])
            {
                MLContact* contact = [MLContact contactFromDictionary:row];
                [recipientsToShow addObject:@{@"contact": contact}];
            }
        }

        controller.options = recipientsToShow;
        controller.completion = ^(NSDictionary *selectedRecipient)
        {
            MLContact* contact = [selectedRecipient objectForKey:@"contact"];
            if(contact) {
                self.recipient = contact.contactJid;
            }
            else {
                self.recipient = @"";
            }
            [self reloadConfigurationItems];
        };
        
        [self pushConfigurationViewController:controller];
    };
    [toreturn addObject:recipient];
    [self validateContent];
    return toreturn;
}

@end
