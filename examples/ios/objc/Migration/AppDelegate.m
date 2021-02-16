////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "AppDelegate.h"
#import <Realm/Realm.h>
#import "Example_v0.h"
#import "Example_v1.h"
#import "Example_v2.h"
#import "Example_v3.h"
#import "Example_v4.h"
#import "Example_v5.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    
    #if CREATE_EXAMPLES
    [self addExampleDataToRealm:exampleData];
    #else
    [self performMigration];
    #endif
    
    return YES;
}

- (void)addExampleDataToRealm:(void (^)(RLMRealm*))examplesData {
    NSURL *url = [self realmUrlFor:schemaVersion usingTemplate:false];
    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
    configuration.fileURL = url;
    configuration.schemaVersion = schemaVersion;
    [RLMRealmConfiguration setDefaultConfiguration:configuration];
    NSError *error;
    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:&error];
    if (error) {
        abort();
    }
    [realm beginWriteTransaction];
    exampleData(realm);
    [realm commitWriteTransaction];
}

// Any version before the current versions will be migrated to check if all version combinations work.
- (void)performMigration {
    for (int oldSchemaVersion=0; oldSchemaVersion<schemaVersion; oldSchemaVersion++) {
        NSURL *realmUrl = [self realmUrlFor:oldSchemaVersion usingTemplate:true];
        RLMRealmConfiguration *realmConfiguration = [RLMRealmConfiguration defaultConfiguration];
        realmConfiguration.fileURL = realmUrl;
        realmConfiguration.schemaVersion = schemaVersion;
        realmConfiguration.migrationBlock = migrationBlock;
        [RLMRealmConfiguration setDefaultConfiguration:realmConfiguration];
        NSError *error;
        [RLMRealm performMigrationForConfiguration:realmConfiguration error:&error];
        if (error) {
            abort();
        }
        RLMRealm *realm = [RLMRealm realmWithConfiguration:realmConfiguration error:&error];
        if (error) {
            abort();
        }
        migrationCheck(realm);
    }
}

- (NSURL*)realmUrlFor:(int)schemaVersion usingTemplate:(BOOL)usingTemplate {
    NSURL *defaultRealmURL = [RLMRealmConfiguration defaultConfiguration].fileURL;
    NSURL *defaultRealmParentURL = [defaultRealmURL URLByDeletingLastPathComponent];
    NSString *fileName = [NSString stringWithFormat:@"default-v%d", schemaVersion];
    NSString *fileExtension = @"realm";
    NSString *fileNameWithExtension = [NSString stringWithFormat:@"%@.%@", fileName, fileExtension];
    NSURL *destinationUrl = [defaultRealmParentURL URLByAppendingPathComponent:fileNameWithExtension];
    if ([[NSFileManager defaultManager] fileExistsAtPath:destinationUrl.path]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:destinationUrl.path error:&error];
        if (error) {
            abort();
        }
    }
    if (usingTemplate) {
        NSURL *bundleUrl = [[NSBundle mainBundle] URLForResource:fileName withExtension:fileExtension];
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:bundleUrl.path toPath:destinationUrl.path error:&error];
        if (error) {
            abort();
        }
    }

    return destinationUrl;
}

@end
