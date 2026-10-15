#import <assert.h>
#import <bare.h>
#import <js.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>
#import <registry.h>

#import <UIKit/UIKit.h>

// UIKit only delivers a touch that carries the digitizer event it was made
// from, and neither the event nor the setters on `UITouch` and `UIEvent` are
// public. The declarations follow KIF, which tracks them across releases.

typedef struct __IOHIDEvent *IOHIDEventRef;

#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

enum {
  bare_ui_kit_touch__transducer_hand = 3,
};

enum {
  bare_ui_kit_touch__digitizer_range = 1 << 0,
  bare_ui_kit_touch__digitizer_touch = 1 << 1,
  bare_ui_kit_touch__digitizer_position = 1 << 2,
};

enum {
  bare_ui_kit_touch__field_is_display_integrated = (11 << 16) + 25,
};

extern IOHIDEventRef
IOHIDEventCreateDigitizerEvent(CFAllocatorRef allocator, AbsoluteTime timestamp, uint32_t type, uint32_t index, uint32_t identity, uint32_t event_mask, uint32_t button_mask, IOHIDFloat x, IOHIDFloat y, IOHIDFloat z, IOHIDFloat tip_pressure, IOHIDFloat barrel_pressure, Boolean range, Boolean touch, uint32_t options);

extern IOHIDEventRef
IOHIDEventCreateDigitizerFingerEventWithQuality(CFAllocatorRef allocator, AbsoluteTime timestamp, uint32_t index, uint32_t identity, uint32_t event_mask, IOHIDFloat x, IOHIDFloat y, IOHIDFloat z, IOHIDFloat tip_pressure, IOHIDFloat twist, IOHIDFloat minor_radius, IOHIDFloat major_radius, IOHIDFloat quality, IOHIDFloat density, IOHIDFloat irregularity, Boolean range, Boolean touch, uint32_t options);

extern void
IOHIDEventAppendEvent(IOHIDEventRef event, IOHIDEventRef child);

extern void
IOHIDEventSetIntegerValue(IOHIDEventRef event, uint32_t field, int value);

@interface UITouch (BareUIKitTouch)

- (void)setWindow:(UIWindow *)window;
- (void)setView:(UIView *)view;
- (void)setTapCount:(NSUInteger)count;
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)setPhase:(UITouchPhase)phase;
- (void)setGestureView:(UIView *)view;
- (void)_setLocationInWindow:(CGPoint)location resetPrevious:(BOOL)reset;
- (void)_setIsFirstTouchForView:(BOOL)first;
- (void)_setIsTapToClick:(BOOL)tap;
- (void)_setHidEvent:(IOHIDEventRef)event;

@end

@interface UIEvent (BareUIKitTouch)

- (void)_clearTouches;
- (void)_addTouch:(UITouch *)touch forDelayedDelivery:(BOOL)delayed;
- (void)_setHIDEvent:(IOHIDEventRef)event;

@end

@interface UIApplication (BareUIKitTouch)

- (UIEvent *)_touchesEvent;

@end

static IOHIDEventRef
bare_ui_kit_touch__hid_event(UITouch *touch) {
  uint64_t now = mach_absolute_time();

  AbsoluteTime timestamp = {.hi = (UInt32) (now >> 32), .lo = (UInt32) now};

  IOHIDEventRef hand = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, timestamp, bare_ui_kit_touch__transducer_hand, 0, 0, bare_ui_kit_touch__digitizer_touch, 0, 0, 0, 0, 0, 0, false, true, 0);

  IOHIDEventSetIntegerValue(hand, bare_ui_kit_touch__field_is_display_integrated, 1);

  uint32_t mask = touch.phase == UITouchPhaseMoved ? bare_ui_kit_touch__digitizer_position : bare_ui_kit_touch__digitizer_range | bare_ui_kit_touch__digitizer_touch;

  Boolean touching = touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled;

  CGPoint location = [touch locationInView:touch.window];

  IOHIDEventRef finger = IOHIDEventCreateDigitizerFingerEventWithQuality(kCFAllocatorDefault, timestamp, 1, 2, mask, location.x, location.y, 0, 0, 0, 5, 5, 1, 1, 1, touching, touching, 0);

  IOHIDEventSetIntegerValue(finger, bare_ui_kit_touch__field_is_display_integrated, 1);

  IOHIDEventAppendEvent(hand, finger);

  CFRelease(finger);

  return hand;
}

static void
bare_ui_kit_touch__send(UITouch *touch, UITouchPhase phase) {
  [touch setTimestamp:[NSProcessInfo processInfo].systemUptime];
  [touch setPhase:phase];

  IOHIDEventRef hid = bare_ui_kit_touch__hid_event(touch);

  [touch _setHidEvent:hid];

  UIApplication *application = [UIApplication sharedApplication];

  UIEvent *event = [application _touchesEvent];

  [event _clearTouches];
  [event _setHIDEvent:hid];
  [event _addTouch:touch forDelayedDelivery:NO];

  CFRelease(hid);

  [application sendEvent:event];
}

static js_value_t *
bare_ui_kit_touch_begin(js_env_t *env, js_callback_info_t *info) {
  int err;

  size_t argc = 3;
  js_value_t *argv[3];

  bare_foundation_registry_t *registry;
  err = js_get_callback_info(env, info, &argc, argv, NULL, (void **) &registry);
  assert(err == 0);

  assert(argc == 3);

  void *handle;
  if (bare_foundation_read_type(env, registry, argv[0], "window", [UIWindow class], &handle) < 0) return NULL;

  double x;
  err = js_get_value_double(env, argv[1], &x);
  assert(err == 0);

  double y;
  err = js_get_value_double(env, argv[2], &y);
  assert(err == 0);

  js_value_t *result;

  @autoreleasepool {
    UIWindow *window = (UIWindow *) handle;

    CGPoint location = CGPointMake(x, y);

    UIView *view = [window hitTest:location withEvent:nil];

    UITouch *touch = [[[UITouch alloc] init] autorelease];

    // Setting the window resets the rest, so it goes first.
    [touch setWindow:window];
    [touch setView:view];
    [touch setTapCount:1];
    [touch _setLocationInWindow:location resetPrevious:YES];

    if ([touch respondsToSelector:@selector(setGestureView:)]) [touch setGestureView:view];

    if ([touch respondsToSelector:@selector(_setIsFirstTouchForView:)]) {
      [touch _setIsFirstTouchForView:YES];
    } else {
      [touch _setIsTapToClick:YES];

      // The setter is gone in recent releases, but the flag is still the
      // first bit of the flags.
      Ivar flags = class_getInstanceVariable(object_getClass(touch), "_touchFlags");

      if (flags != NULL) *((char *) touch + ivar_getOffset(flags)) |= 1;
    }

    bare_ui_kit_touch__send(touch, UITouchPhaseBegan);

    result = bare_foundation_bridge(env, registry, touch);
  }

  return result;
}

static js_value_t *
bare_ui_kit_touch_move(js_env_t *env, js_callback_info_t *info) {
  int err;

  size_t argc = 3;
  js_value_t *argv[3];

  bare_foundation_registry_t *registry;
  err = js_get_callback_info(env, info, &argc, argv, NULL, (void **) &registry);
  assert(err == 0);

  assert(argc == 3);

  void *handle;
  if (bare_foundation_read_type(env, registry, argv[0], "touch", [UITouch class], &handle) < 0) return NULL;

  double x;
  err = js_get_value_double(env, argv[1], &x);
  assert(err == 0);

  double y;
  err = js_get_value_double(env, argv[2], &y);
  assert(err == 0);

  @autoreleasepool {
    UITouch *touch = (UITouch *) handle;

    [touch _setLocationInWindow:CGPointMake(x, y) resetPrevious:NO];

    bare_ui_kit_touch__send(touch, UITouchPhaseMoved);
  }

  return NULL;
}

static js_value_t *
bare_ui_kit_touch_end(js_env_t *env, js_callback_info_t *info) {
  int err;

  size_t argc = 2;
  js_value_t *argv[2];

  bare_foundation_registry_t *registry;
  err = js_get_callback_info(env, info, &argc, argv, NULL, (void **) &registry);
  assert(err == 0);

  assert(argc == 2);

  void *handle;
  if (bare_foundation_read_type(env, registry, argv[0], "touch", [UITouch class], &handle) < 0) return NULL;

  bool cancelled;
  err = js_get_value_bool(env, argv[1], &cancelled);
  assert(err == 0);

  @autoreleasepool {
    bare_ui_kit_touch__send((UITouch *) handle, cancelled ? UITouchPhaseCancelled : UITouchPhaseEnded);
  }

  return NULL;
}

static js_value_t *
bare_ui_kit_touch_exports(js_env_t *env, js_value_t *exports) {
  int err;

  bare_foundation_registry_t *registry = bare_foundation_registry_create(env, exports);

#define V(name, fn) \
  { \
    js_value_t *val; \
    err = js_create_function(env, name, -1, fn, registry, &val); \
    assert(err == 0); \
    err = js_set_named_property(env, exports, name, val); \
    assert(err == 0); \
  }

  V("claim", bare_foundation_claim)
  V("wrapper", bare_foundation_wrapper)
  V("adopt", bare_foundation_adopt)

  V("touchBegin", bare_ui_kit_touch_begin)
  V("touchMove", bare_ui_kit_touch_move)
  V("touchEnd", bare_ui_kit_touch_end)
#undef V

  return exports;
}

BARE_MODULE(bare_ui_kit_touch, bare_ui_kit_touch_exports)
