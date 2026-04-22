#import "PluginHelper.h"
#import <objc/runtime.h>

// Sostituto no-op per WebViewFlutterPlugin.register(with:)
// Evita crash SIGSEGV su iOS 26 (null pointer in swift_getObjectType)
static void noopRegister(id self, SEL _cmd, id registrar) {
    NSLog(@"[IdeAI] Skipped %@ registration (iOS 26 workaround)", NSStringFromClass(self));
}

@implementation PluginHelper

+ (void)disableWebViewPlugin {
    NSArray *classNames = @[@"WebViewFlutterPlugin", @"FLTWebViewFlutterPlugin"];
    for (NSString *name in classNames) {
        Class cls = NSClassFromString(name);
        if (cls) {
            SEL sel = NSSelectorFromString(@"registerWithRegistrar:");
            Method method = class_getClassMethod(cls, sel);
            if (method) {
                method_setImplementation(method, (IMP)noopRegister);
                NSLog(@"[IdeAI] Disabled %@ registration", name);
            }
        }
    }
}

@end
