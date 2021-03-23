//
//  NSObject+ZRKVO.h
//  ZRCustomKVO
//
//  Created by Zhou,Rui(ART) on 2021/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ZRKVOBlock)(id observer, NSString *keyPath, id oldValue, id newValue);

@interface NSObject (ZRKVO)

- (void)zr_addObserver:(NSObject *)observer
            forKeyPath:(NSString *)keyPath
               options:(NSKeyValueObservingOptions)options
               context:(nullable void *)context;
- (void)zr_observeValueForKeyPath:(nullable NSString *)keyPath
                         ofObject:(nullable id)object
                           change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                          context:(nullable void *)context;
- (void)zr_removeObserver:(NSObject *)observer
               forKeyPath:(NSString *)keyPath;

- (void)zr_addObserver:(NSObject *)observer
            forKeyPath:(NSString *)keyPath
               handler:(ZRKVOBlock)handler;

@end

NS_ASSUME_NONNULL_END
