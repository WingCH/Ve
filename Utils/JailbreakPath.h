#ifndef VE_JAILBREAK_PATH_H
#define VE_JAILBREAK_PATH_H

#import <Foundation/Foundation.h>

#if __has_include(<roothide.h>)
#import <roothide.h>

NS_INLINE NSString *VEJailbreakRootPath(NSString *path) {
    return jbroot(path);
}
#else
#import <rootless.h>

NS_INLINE NSString *VEJailbreakRootPath(NSString *path) {
    return ROOT_PATH_NS_VAR(path);
}
#endif

#endif
