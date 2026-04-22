#import "SafePluginRegistrant.h"
#import "GeneratedPluginRegistrant.h"

@implementation SafePluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry> *)registry {
    @try {
        [GeneratedPluginRegistrant registerWithRegistry:registry];
    }
    @catch (NSException *exception) {
        NSLog(@"[IdeAI] Plugin registration exception: %@ — %@", exception.name, exception.reason);
    }
}

@end
