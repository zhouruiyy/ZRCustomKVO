//
//  NSObject+ZRKVO.m
//  ZRCustomKVO
//
//  Created by Zhou,Rui(ART) on 2021/3/22.
//

#import "NSObject+ZRKVO.h"
#import <objc/message.h>

static NSString *const kZRKVOPrefix = @"ZRKVONotifying_";
static NSString *const kZRKVOAssociateKey = @"kZRKVOAssociateKey";

@interface ZRKVOInfo : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, assign) NSKeyValueObservingOptions options;
@property (nonatomic, copy) ZRKVOBlock handler;
@property (nonatomic, strong) id oldValue;


- (instancetype)initWithObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath oldValue:(id)oldValue options:(NSKeyValueObservingOptions)options;

- (instancetype)initWithObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath oldValue:(id)oldValue handler:(ZRKVOBlock)handler;

@end

@implementation ZRKVOInfo

- (instancetype)initWithObserver:(NSObject *)observer
                      forKeyPath:(NSString *)keyPath
                        oldValue:(id)oldValue
                         options:(NSKeyValueObservingOptions)options {
    if (self = [super init]) {
        _observer = observer;
        _keyPath = keyPath;
        _oldValue = oldValue;
        _options = options;
    }
    return self;
}

- (instancetype)initWithObserver:(NSObject *)observer
                      forKeyPath:(NSString *)keyPath
                        oldValue:(id)oldValue
                         handler:(ZRKVOBlock)handler {
    if (self = [super init]) {
        _observer = observer;
        _keyPath = keyPath;
        _oldValue = oldValue;
        _handler = handler;
    }
    return self;
}

@end

@implementation NSObject (ZRKVO)

- (void)zr_addObserver:(NSObject *)observer
            forKeyPath:(NSString *)keyPath
               options:(NSKeyValueObservingOptions)options
               context:(nullable void *)context {
    /// has set func.
    [self hasSetMethodForKeyPath:keyPath];
    
    id oldValue = [self valueForKey:keyPath];
    ZRKVOInfo *info = [[ZRKVOInfo alloc] initWithObserver:observer forKeyPath:keyPath oldValue:oldValue options:options];
    NSMutableArray *arr = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kZRKVOAssociateKey));
    if (!arr) {
        arr = [NSMutableArray arrayWithCapacity:1];
        objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(kZRKVOAssociateKey), arr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [arr addObject:info];
    
    /// automaticallyNotifiesObserversForKey is open.
    BOOL isAutomatically = [self zr_performSelectorWithMethodName:@"automaticallyNotifiesObserversForKey:" withObject:keyPath];
    if (!isAutomatically) return;
    
    Class newClass = [self createChildClassWithKeyPath:keyPath];
    object_setClass(self, newClass);
    
    SEL setSel = NSSelectorFromString(setFromGet(keyPath));
    Method method = class_getInstanceMethod([self class], setSel);
    const char *type = method_getTypeEncoding(method);
    class_addMethod(newClass, setSel, (IMP)zr_set, type);
}

- (void)zr_observeValueForKeyPath:(nullable NSString *)keyPath
                         ofObject:(nullable id)object
                           change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                          context:(nullable void *)context {
    
}

- (void)zr_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    NSMutableArray *arr = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kZRKVOAssociateKey));
    if (arr.count <= 0) {
        return;
    }
    
    for (ZRKVOInfo *info in arr) {
        if ([info.keyPath isEqualToString:keyPath]) {
            [arr removeObject:info];
            objc_setAssociatedObject(self, (__bridge const void *_Nonnull)(kZRKVOAssociateKey), arr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    if (arr.count <= 0) {
        /// reset isa
        Class superClass = [self class];
        object_setClass(self, superClass);
    }
}


- (void)zr_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath handler:(ZRKVOBlock)handler {
    /// has set func.
    [self hasSetMethodForKeyPath:keyPath];
    
    id oldValue = [self valueForKey:keyPath];
    ZRKVOInfo *info = [[ZRKVOInfo alloc] initWithObserver:observer forKeyPath:keyPath oldValue:oldValue handler:handler];
    NSMutableArray *arr = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kZRKVOAssociateKey));
    if (!arr) {
        arr = [NSMutableArray arrayWithCapacity:1];
        objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(kZRKVOAssociateKey), arr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [arr addObject:info];
    
    /// automaticallyNotifiesObserversForKey is open.
    BOOL isAutomatically = [self zr_performSelectorWithMethodName:@"automaticallyNotifiesObserversForKey:" withObject:keyPath];
    if (!isAutomatically) return;
    
    Class newClass = [self createChildClassWithKeyPath:keyPath];
    object_setClass(self, newClass);
    
    SEL setSel = NSSelectorFromString(setFromGet(keyPath));
    Method method = class_getInstanceMethod([self class], setSel);
    const char *type = method_getTypeEncoding(method);
    class_addMethod(newClass, setSel, (IMP)zr_set, type);
}

#pragma mark - private

/// has set func.
- (void)hasSetMethodForKeyPath:(NSString *)keyPath {
    Class currentClass = object_getClass(self);
    SEL setSel = NSSelectorFromString(setFromGet(keyPath));
    Method setMethod = class_getInstanceMethod(currentClass, setSel);
    if (!setMethod) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"ZRKVO - 没有当前%@的set方法", keyPath] userInfo:nil];
    }
}

/// create child class dynamically
- (Class)createChildClassWithKeyPath:(NSString *)keyPath {
    NSString *oldClassName = NSStringFromClass([self class]);
    NSString *newClassName = [NSString stringWithFormat:@"%@%@", kZRKVOPrefix, oldClassName];
    
    Class newClass = NSClassFromString(newClassName);
    if (newClass) {
        return newClass;
    }
    
    newClass = objc_allocateClassPair([self class], newClassName.UTF8String, 0);
    objc_registerClassPair(newClass);
    
    SEL classSel = @selector(class);
    Method classMethod = class_getInstanceMethod([self class], classSel);
    const char *classType = method_getTypeEncoding(classMethod);
    class_addMethod(newClass, classSel, (IMP)zr_class, classType);
    
    SEL deallocSel = NSSelectorFromString(@"dealloc");
    Method deallocMethod = class_getInstanceMethod([self class], deallocSel);
    const char *deallocType = method_getTypeEncoding(deallocMethod);
    class_addMethod(newClass, deallocSel, (IMP)zr_dealloc, deallocType);
    
    return newClass;
}

Class zr_class(id self, SEL _cmd) {
    return class_getSuperclass(object_getClass(self)); // [self class] will endless loop
}

static void zr_set(id self, SEL _cmd, id newValue) {
    NSLog(@"rewrite set func.");
    
    /// willChange
    
    /// set. call super func.
    void (*zr_msgSendSuper)(void *, SEL, id) = (void *)objc_msgSendSuper;
    struct objc_super superStruct = {
            .receiver = self,
            .super_class = class_getSuperclass(object_getClass(self)),
        };
    zr_msgSendSuper(&superStruct, _cmd, newValue);
    
    /// didChange
    
    /// options
    NSString *keyPath = getFromSet(NSStringFromSelector(_cmd));
    NSMutableArray *arr = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kZRKVOAssociateKey));
    for (ZRKVOInfo *info in arr) {
        NSMutableDictionary<NSKeyValueChangeKey, id> *change = [NSMutableDictionary dictionaryWithCapacity:1];
        if ([info.keyPath isEqualToString:keyPath]) {
            if ((info.options & NSKeyValueObservingOptionNew) && (info.options & NSKeyValueObservingOptionOld)) {
                [change setValue:info.oldValue forKey:NSKeyValueChangeOldKey];
                [change setValue:newValue forKey:NSKeyValueChangeNewKey];
            } else {
                [change setValue:newValue forKey:NSKeyValueChangeNewKey];
            }
            
            if (info.observer && [info.observer respondsToSelector:@selector(zr_observeValueForKeyPath:ofObject:change:context:)]) {
                [info.observer zr_observeValueForKeyPath:info.keyPath ofObject:self change:change context:NULL];
            }
        }
    }
    
    
    /// block
//    NSString *keyPath = getFromSet(NSStringFromSelector(_cmd));
//    id oldValue = [self valueForKey:keyPath];
//    NSMutableArray *arr = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kZRKVOAssociateKey));
//    for (ZRKVOInfo *info in arr) {
//        if ([info.keyPath isEqualToString:keyPath] && info.handler) {
//            info.handler(info.observer, info.keyPath, oldValue, newValue);
//        }
//    }
}

void zr_dealloc(id self, SEL _cmd) {
    NSLog(@"%s call", __func__);
    
    Class superClass = [self class];
    object_setClass(self, superClass);
}

- (BOOL)zr_performSelectorWithMethodName:(NSString *)methodName withObject:(id)object {
    if ([[self class] respondsToSelector:NSSelectorFromString(methodName)]) {
#pragma clang disgnositic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        return [[self class] performSelector:NSSelectorFromString(methodName) withObject:object];
#pragma clang disgnositic pop
    }
    return NO;
}

static NSString *setFromGet(NSString *get) {
    if (get.length <= 0) {
        return nil;
    }
    NSString *firstStr = [[get substringToIndex:1] uppercaseString];
    NSString *leaveStr = [get substringFromIndex:1];
    
    return [NSString stringWithFormat:@"set%@%@:", firstStr, leaveStr];
}

static NSString *getFromSet(NSString *set) {
    if (set.length <= 0 || ![set hasPrefix:@"set"] || ![set hasSuffix:@":"]) {
        return nil;
    }
    NSRange range = NSMakeRange(3, set.length - 4);
    NSString *get = [set substringWithRange:range];
    NSString *firstStr = [[get substringToIndex:1] lowercaseString];
    
    return [get stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstStr];
}

@end
