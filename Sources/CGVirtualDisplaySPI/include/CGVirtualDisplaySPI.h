// SPI bridging header for CGVirtualDisplay.
//
// These four ObjC classes are exported from CoreGraphics.framework but are
// not declared in any public header. Symbols verified at runtime against
// `class_copyMethodList` on macOS 26.3.1 / Apple Silicon (the spike at
// /tmp/wdm-spike). DeskPad's older bridging header used `maxPixelsTall`;
// the current API is `maxPixelsHigh`.
//
// We accept the project's "documented-by-community private SPI" exception
// (see CLAUDE.md and DisplayServicesBridge.swift). At runtime we probe via
// `objc_getClass("CGVirtualDisplay")` and refuse honestly if the class is
// gone in some future macOS — the iron law's unsupported-path policy.

#ifndef CGVirtualDisplaySPI_h
#define CGVirtualDisplaySPI_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(uint32_t)width
                       height:(uint32_t)height
                  refreshRate:(double)refreshRate;
@property(readonly) uint32_t width;
@property(readonly) uint32_t height;
@property(readonly) double refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property(strong) NSArray<CGVirtualDisplayMode *> *modes;
@property(assign) uint32_t hiDPI;
@property(assign) uint32_t rotation;
@property(assign) BOOL isReference;
@end

@interface CGVirtualDisplayDescriptor : NSObject
@property(strong) NSString *name;
@property(assign) uint32_t maxPixelsWide;
@property(assign) uint32_t maxPixelsHigh;
@property(assign) CGSize sizeInMillimeters;
@property(assign) uint32_t serialNum;
@property(assign) uint32_t productID;
@property(assign) uint32_t vendorID;
@property(strong) dispatch_queue_t queue;
@property(strong, nullable) void (^terminationHandler)(id, id);
@end

@interface CGVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@property(readonly) uint32_t displayID;
@property(readonly) uint32_t vendorID;
@property(readonly) uint32_t productID;
@property(readonly) uint32_t serialNum;
@property(readonly) NSString *name;
@property(readonly) CGSize sizeInMillimeters;
@property(readonly) uint32_t maxPixelsWide;
@property(readonly) uint32_t maxPixelsHigh;
@property(readonly) dispatch_queue_t queue;
@property(readonly) unsigned int hiDPI;
@property(readonly) NSArray<CGVirtualDisplayMode *> *modes;
@end

NS_ASSUME_NONNULL_END

#endif /* CGVirtualDisplaySPI_h */
