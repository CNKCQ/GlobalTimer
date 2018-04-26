
//  GTimer.m
//  Pods-GlobalTimer_Example
//
//  Created by Steve on 25/01/2018.
//

#import "GTimer.h"
#import "GEvent.h"
#import <libkern/OSAtomic.h>
#import <pthread.h>

#if !__has_feature(objc_arc)
#error GTimer is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#if OS_OBJECT_USE_OBJC
#define gt_gcd_property_qualifier strong
#define gt_release_gcd_object(object)
#else
#define gt_gcd_property_qualifier assign
#define gt_release_gcd_object(object) dispatch_release(object)
#endif

#define gtweakify(var) __weak typeof(var) gtweak_##var = var;

#define gtstrongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = gtweak_##var; \
_Pragma("clang diagnostic pop")

#define LOCK(...)  do {\
dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);\
__VA_ARGS__;\
dispatch_semaphore_signal(_lock);\
} while (0);

// Function to return gcd of a and b
NSTimeInterval gcd(NSTimeInterval a, NSTimeInterval b)
{
    if (a == 0)
        return b;
    return gcd(fmod(b, a), a);
}

// Function to find gcd of array of
// numbers
NS_INLINE NSTimeInterval findGCD(NSTimeInterval arr[], NSUInteger n)
{
    int result = arr[0];
    for (int i=1; i<n; i++)
        result = gcd(arr[i], result);
    return result;
}

// Function to return gcd of a and b
NSTimeInterval lcm(NSTimeInterval a, NSTimeInterval b)
{
    return a*b/gcd(fmod(b, a), a);
}


// Function to find lcm of array of
// numbers
NS_INLINE NSTimeInterval findLCM(NSTimeInterval arr[], NSUInteger n)
{
    int result = arr[0];
    for (int i=1; i<n; i++)
        result = lcm(arr[i], result);
    return result;
}


@interface GTimer()
{
    struct
    {
        uint32_t timerIsInvalidated;
    } _timerFlags;
}

@property (nonatomic, assign) NSTimeInterval defaultTimeInterval;

@property (nonatomic, strong) NSMutableArray<GEvent *> *events;

@property (nonatomic, assign) BOOL repeats;

@property (nonatomic, gt_gcd_property_qualifier) dispatch_queue_t privateConcurrentQueue;

@property (nonatomic, gt_gcd_property_qualifier) dispatch_source_t timer;

@property (nonatomic, assign) NSTimeInterval indexInterval;

@property (atomic, assign) NSTimeInterval tolerance;

@end


@implementation GTimer {
    dispatch_semaphore_t _lock;
}

@synthesize tolerance = _tolerance;

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static GTimer *_instance = nil;
    dispatch_once(&onceToken, ^{
        _instance = [[GTimer alloc] init];
    });
    return _instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    if (self) {
        _lock = dispatch_semaphore_create(1);
        self.defaultTimeInterval = 1;
        self.indexInterval = 0;
        self.events = [NSMutableArray array];
        self.privateConcurrentQueue = nil;
        NSString *privateQueueName = [NSString stringWithFormat:@"com.globaltimer.%p", self];
        self.privateConcurrentQueue = dispatch_queue_create([privateQueueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                            0,
                                            0,
                                            self.privateConcurrentQueue);
        [self schedule];
    }
}

- (void)scheduledWith: (NSString *)identifirer timeInterval: (NSTimeInterval)interval repeat:(BOOL)repeat block:(GTBlock)block userinfo:(NSDictionary *)userinfo {
    @autoreleasepool {
        LOCK(
             NSArray<GEvent *> *tempEvents = [self.events copy];
             BOOL shouldSkip = NO;
             for(GEvent *obj in tempEvents) {
#ifdef DEBUG
                 NSString *desc = [NSString stringWithFormat:@"Duplicate rawValue definition for identifirer '%@'", identifirer];
                 NSAssert(obj.identifirer != identifirer, desc);
#else
                 shouldSkip = obj.identifirer == identifirer;
                 if (shouldSkip == YES) {
                     break;
                 }
#endif
             }
             if (shouldSkip == YES) {
                 dispatch_semaphore_signal(_lock);
                 return;
             };
             dispatch_async(self.privateConcurrentQueue, ^{
                block(userinfo);
            });
             if (!repeat) {
                 return;
             }
             GEvent *event = [GEvent eventWith:identifirer];
             event.interval = interval;
             event.creatAt = self.indexInterval;
             event.block = block;
             event.userinfo = userinfo;
             event.repeat = repeat;
             [self.events addObject:event]
             );
    }
    [self updateDefaultTimeIntervalIfNeeded];
}

- (void)updateEventWith: (NSString  * _Nonnull )identifirer timeInterval: (NSTimeInterval)interval {
    [self updateEventWith:identifirer timeInterval:interval repeat:YES block:nil userinfo:nil];
}


- (void)updateEventWith: (NSString  * _Nonnull )identifirer timeInterval: (NSTimeInterval)interval repeat:(BOOL)repeat block:(GTBlock _Nullable )block userinfo:(NSDictionary * _Nullable)userinfo {
    LOCK(
         NSArray<GEvent *> *tempEvents = [self.events copy];
         for (GEvent *event in tempEvents) {
             if ([event.identifirer isEqualToString:identifirer]) {
                 event.interval = interval != 0 ? interval : event.interval;
                 event.repeat = repeat;
                 event.block = block != nil ? block : event.block;
                 event.userinfo = userinfo != nil ? userinfo : event.userinfo;
             }
         }
         );
    [self updateDefaultTimeIntervalIfNeeded];
}

- (void)activeEventWith:(NSString *)identifirer {
    LOCK(
         NSArray<GEvent *> *tempEvents = [self.events copy];
         for (GEvent *event in tempEvents) {
             if ([event.identifirer isEqualToString:identifirer]) {
                 event.isActive = YES;
             }
         }
         );
}

- (void)pauseEventWith:(NSString *)identifirer {
    LOCK(
         NSArray<GEvent *> *tempEvents = [self.events copy];
         for (GEvent *event in tempEvents) {
             if ([event.identifirer isEqualToString:identifirer]) {
                 event.isActive = NO;
             }
         }
         );
}

- (void)removeEventWith:(NSString *)identifirer {
    LOCK(
         NSArray<GEvent *> *tempEvents = [self.events copy];
         for (GEvent *event in tempEvents) {
             if ([event.identifirer isEqualToString:identifirer]) {
                 [self.events removeObject:event];
             }
         }
         );
    [self updateDefaultTimeIntervalIfNeeded];
}

- (void)updateDefaultTimeIntervalIfNeeded {
    NSTimeInterval gcdInterval = [self gcdInterval];
    if (self.defaultTimeInterval != gcdInterval) {
        LOCK(
             self.defaultTimeInterval = gcdInterval;
             [self resetTimer];
             );
    }
}

- (NSTimeInterval)gcdInterval {
    NSArray<GEvent *> *tempEvents = [self.events copy];
    NSUInteger count = [tempEvents count];
    NSTimeInterval intervals[sizeof(NSTimeInterval)*count];
    for (int i = 0; i < tempEvents.count; i++) {
        intervals[i] = tempEvents[i].interval;
    }
    return findGCD(intervals, count);
}

- (NSTimeInterval)lcmInterval {
    NSArray<GEvent *> *tempEvents = [self.events copy];
    NSUInteger count = [tempEvents count];
    NSTimeInterval intervals[sizeof(NSTimeInterval)*count];
    for (NSUInteger i = 0; i < tempEvents.count; i++) {
        intervals[i] = tempEvents[i].interval;
    }
    return findLCM(intervals, count);
}

- (void)resetTimer
{
    int64_t intervalInNanoseconds = (int64_t)(self.defaultTimeInterval * NSEC_PER_SEC);
    int64_t toleranceInNanoseconds = (int64_t)(self.tolerance * NSEC_PER_SEC);
    dispatch_source_set_timer(
                              self.timer,
                              dispatch_time(DISPATCH_TIME_NOW, intervalInNanoseconds),
                              (uint64_t)intervalInNanoseconds,
                              toleranceInNanoseconds
                              );
}

- (void)schedule
{
    [self resetTimer];
    gtweakify(self);
    dispatch_source_set_event_handler(self.timer, ^{
        gtstrongify(self);
        [self fire];
    });
    dispatch_resume(self.timer);
}

-(void)fire {
    // Checking attomatically if the timer has already been invalidated.
    if (OSAtomicAnd32OrigBarrier(1, &_timerFlags.timerIsInvalidated))
    {
        return;
    }
    @autoreleasepool {
        LOCK(self.indexInterval += self.defaultTimeInterval;);
        NSArray<GEvent *> *tempEvents = [self.events copy];
        gtweakify(self);
        [tempEvents enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(GEvent * _Nonnull event, NSUInteger idx, BOOL * _Nonnull stop) {
            gtstrongify(self);
            dispatch_queue_t blockqueue = dispatch_queue_create("globalTimer-queue", DISPATCH_QUEUE_CONCURRENT);
            dispatch_async(blockqueue, ^{
                if (fmod(self.indexInterval - event.creatAt, event.interval) == 0.0 && event.isActive == YES) {
                    event.block(event.userinfo);
                }
            });
        }];
        if (self.indexInterval > [self lcmInterval]) {
            LOCK(self.indexInterval = fmod(self.indexInterval, [self lcmInterval]));
        }
    }
}

-(void)invalidate {
    // We check with an atomic operation if it has already been invalidated. Ideally we would synchronize this on the private queue,
    // but since we can't know the context from which this method will be called, dispatch_sync might cause a deadlock.
    if (!OSAtomicTestAndSetBarrier(7, &_timerFlags.timerIsInvalidated))
    {
        dispatch_source_t timer = self.timer;
        dispatch_async(self.privateConcurrentQueue, ^{
            dispatch_source_cancel(timer);
            gt_release_gcd_object(timer);
        });
    }
}

- (NSArray<NSString *> *)eventList {
    NSMutableArray<NSString *> *eventLists = [NSMutableArray array];
    NSArray<GEvent *> *tempEvents = [self.events copy];
    for (GEvent *event in tempEvents) {
        [eventLists addObject:event.identifirer];
    }
    return [eventLists copy];
}

-(void)dealloc {
    [self invalidate];
}

@end





