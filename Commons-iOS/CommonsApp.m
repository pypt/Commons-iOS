//
//  CommonsApp.m
//  Commons-iOS
//
//  Created by Brion on 1/25/13.
//  Copyright (c) 2013 Wikimedia. All rights reserved.
//

#import "CommonsApp.h"

@implementation CommonsApp

static CommonsApp *singleton_;

+ (CommonsApp *)singleton
{
    if (singleton_ == nil) {
        singleton_ = [[CommonsApp alloc] init];
    }
    return singleton_;
}

- (void)initializeApp
{
    [self loadCredentials];
    [self setupData];
    [self fetchUploadRecords];
}

- (void)loadCredentials
{
    self.username = [self getKeychainValueForEntry:@"org.wikimedia.username"];
    self.password = [self getKeychainValueForEntry:@"org.wikimedia.password"];
}

- (void)saveCredentials
{
    [self setKeychainValue:self.username forEntry:@"org.wikimedia.username"];
    [self setKeychainValue:self.password forEntry:@"org.wikimedia.password"];
}

- (BOOL)setKeychainValue:(NSString *)value forEntry:(NSString *)entry
{
    NSData *encodedName = [entry dataUsingEncoding:NSUTF8StringEncoding];
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService: [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"],
    (__bridge id)kSecAttrGeneric: encodedName,
    (__bridge id)kSecAttrAccount: encodedName,
    (__bridge id)kSecValueData: valueData,
    (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlocked,
    };
    
    // Create the keychain item, if it doesn't yet exist...
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)dict, NULL);
    if (status == errSecSuccess) {
        return YES;
    } else if (status == errSecDuplicateItem) {
        // Exists! Pass through to update.
        return [self updateKeychainValue:value forEntry:entry];
    } else {
        NSLog(@"Keychain: Something exploded; SecItemAdd returned %i", (int)status);
        return NO;
    }
}

- (BOOL)updateKeychainValue:(NSString *)value forEntry:(NSString *)entry
{
    NSData *encodedName = [entry dataUsingEncoding:NSUTF8StringEncoding];
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService: [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"],
    (__bridge id)kSecAttrGeneric: encodedName,
    (__bridge id)kSecAttrAccount: encodedName
    };
    NSDictionary *dataDict = @{
    (__bridge id)kSecValueData: valueData
    };
    
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)dict, (__bridge CFDictionaryRef)dataDict);
    if (status == errSecSuccess) {
        return YES;
    } else {
        NSLog(@"Keychain: SecItemUpdate returned %i", (int)status);
        return NO;
    }
}

- (NSString *)getKeychainValueForEntry:(NSString *)entry
{
    NSData *encodedName = [entry dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService: [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"],
    (__bridge id)kSecAttrGeneric: encodedName,
    (__bridge id)kSecAttrAccount: encodedName,
    (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue
    };
    
    // Fetch username and password from keychain
    CFTypeRef found = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)dict, &found);
    if (status == noErr) {
        NSData *result = (__bridge_transfer NSData *)found;
        return [[NSString alloc] initWithData: result encoding:NSUTF8StringEncoding];
    } else {
        NSLog(@"Keychain: SecItemCopyMatching returned %i", (int)status);
        return @"";
    }
}

- (void)setupData
{
    NSManagedObjectModel *managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
    
    NSArray* documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentRootPath = [documentPaths objectAtIndex:0];
    NSString* dataPath = [documentRootPath stringByAppendingString:@"/uploads.sqlite"];
    NSLog(@"data path: %@", dataPath);
    NSURL *url = [NSURL fileURLWithPath:dataPath];
    
    NSError *error;
    if ([persistentStoreCoordinator addPersistentStoreWithType: NSSQLiteStoreType configuration:nil URL:url options:nil error:&error]) {
        NSLog(@"Created persistent store.");
    } else {
        NSLog(@"Error creating persistent store coordinator: %@", error.localizedFailureReason);
    }
    self.context = [[NSManagedObjectContext alloc] init];
    self.context.persistentStoreCoordinator = persistentStoreCoordinator;
}

- (void)saveData
{
    NSError *error;
    BOOL success = [self.context save:&error];
    if (success) {
        NSLog(@"Saved database.");
    } else {
        NSLog(@"Error saving database: %@", error.localizedFailureReason);
    }
}

- (FileUpload *)createUploadRecord
{
    return [NSEntityDescription insertNewObjectForEntityForName:@"FileUpload" inManagedObjectContext:self.context];
}

- (NSArray *)fetchUploadRecords
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES selector:nil];
    fetchRequest.sortDescriptors = @[sortDescriptor];
    
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"FileUpload"
                                              inManagedObjectContext:self.context];
    [fetchRequest setEntity:entity];
    NSError *error = nil;
    NSArray *fetchedObjects = [self.context
                               executeFetchRequest:fetchRequest error:&error];
    
    for (FileUpload *file in fetchedObjects) {
        NSLog(@"found: %@", file.title);
    }
    return fetchedObjects;
}

- (void)prepareImage:(UIImage *)image
{
    self.image = image;
}

@end
