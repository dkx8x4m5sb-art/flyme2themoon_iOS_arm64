//
//  FMLuaHost.h
//  关卡脚本宿主：一个 Lua 5.1 状态机 + 协程调度。
//
//  关卡脚本是阻塞式写法（dialog.show / script.delay 会停在那里等），
//  这里用 coroutine.yield 把等待交回原生侧，由 tick 驱动恢复。
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FMLuaWaitKind) {
    FMLuaWaitNone = 0,
    FMLuaWaitDelay = 1,   // script.delay(秒)
    FMLuaWaitDialog = 2,  // dialog.show 系列，等玩家点击或定时关闭
};

@class FMLuaHost;

@protocol FMLuaHostDelegate <NSObject>
// 声音 / 相机 / 输入
- (void)luaPlaySound:(NSString *)soundId;
- (void)luaCameraGoto:(CGPoint)point;
- (void)luaCameraToRole;
- (void)luaSetFollowRoleMode:(BOOL)on;
- (void)luaSetUserInputEnabled:(BOOL)on;
- (void)luaSetLogicPaused:(BOOL)paused;
- (void)luaRestartTiming;
- (BOOL)luaIsRestart;
- (void)luaSuccess;
- (void)luaShowTutorialDiagram:(NSInteger)index;
// 角色
- (void)luaSetIdleActionEnabled:(BOOL)on;
- (void)luaRoleLoadState;
- (void)luaRoleLookLeftRight;
// 存档
- (BOOL)luaGlobalGetBool:(NSString *)key;
- (void)luaGlobalSetBool:(NSString *)key;
- (BOOL)luaIsLevelPassed:(NSInteger)level;
// 回放
- (void)luaSetReplayMode;
- (void)luaSetPlayMode;
- (void)luaLoadTutorialReplay:(NSString *)name;
- (void)luaReplaySkipNonControlFrames;
- (void)luaReplayPause;
- (void)luaSetSkipEnabled:(BOOL)on;
@end

@interface FMLuaHost : NSObject

@property (nonatomic, weak, nullable) id<FMLuaHostDelegate> delegate;

@property (nonatomic, readonly) FMLuaWaitKind waitKind;
@property (nonatomic, readonly) double waitDelay;
@property (nonatomic, copy, readonly, nullable) NSString *waitDialogKey;
@property (nonatomic, copy, readonly, nullable) NSString *waitFace;
@property (nonatomic, readonly) double waitMinTime;
@property (nonatomic, readonly) BOOL waitAutoClose;

@property (nonatomic, copy, readonly, nullable) NSString *lastError;
@property (nonatomic, readonly) BOOL finished;
@property (nonatomic, readonly) BOOL skipEnabled;

- (instancetype)initWithLevel:(NSInteger)level script:(NSString *)script;
- (void)start;
- (void)tick:(double)dt;
- (void)resolveDialogSkipped:(BOOL)skipped;
- (void)callGlobal:(NSString *)name;
- (void)shutdown;
- (void)markFinished;

@end

NS_ASSUME_NONNULL_END
