//
//  FMLuaHost.m
//  关卡脚本宿主实现（Lua 5.1.5，只开 base/table/string/math，不碰 io/os/package）。
//

#import "FMLuaHost.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#pragma mark - Lua 侧辅助

static FMLuaHost *FMHostOf(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "fm_host_ptr");
    FMLuaHost *host = (__bridge FMLuaHost *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    return host;
}

static NSString *FMString(lua_State *L, int index) {
    const char *s = lua_tostring(L, index);
    return s ? [NSString stringWithUTF8String:s] : nil;
}

static double FMNumber(lua_State *L, int index) {
    return lua_isnumber(L, index) ? lua_tonumber(L, index) : 0.0;
}

static BOOL FMBool(lua_State *L, int index) {
    return lua_toboolean(L, index) != 0;
}

static int FMRetBool(lua_State *L, BOOL value) {
    lua_pushboolean(L, value ? 1 : 0);
    return 1;
}

#pragma mark - 原生函数

#define FM_DELEGATE(host, call) do { FMLuaHost *fmh = (host); if (fmh.delegate) { [fmh.delegate call]; } } while (0)

static int n_sound_play(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    NSString *s = FMString(L, 1);
    if (h && s.length) FM_DELEGATE(h, luaPlaySound:s);
    return 0;
}

static int n_cam_goto(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaCameraGoto:CGPointMake(FMNumber(L, 1), FMNumber(L, 2)));
    return 0;
}

static int n_cam_role(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaCameraToRole);
    return 0;
}

static int n_cam_follow(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaSetFollowRoleMode:FMBool(L, 1));
    return 0;
}

static int n_set_input(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaSetUserInputEnabled:FMBool(L, 1));
    return 0;
}

static int n_pause(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaSetLogicPaused:YES);
    return 0;
}

static int n_resume(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaSetLogicPaused:NO);
    return 0;
}

static int n_restart_timing(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaRestartTiming);
    return 0;
}

static int n_is_restart(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    return FMRetBool(L, h ? [h.delegate luaIsRestart] : NO);
}

static int n_success(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) {
        [h markFinished];
        FM_DELEGATE(h, luaSuccess);
    }
    return 0;
}

static int n_tutorial(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaShowTutorialDiagram:(NSInteger)FMNumber(L, 1));
    return 0;
}

static int n_set_idle(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaSetIdleActionEnabled:FMBool(L, 1));
    return 0;
}

static int n_load_state(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaRoleLoadState);
    return 0;
}

static int n_look_lr(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaRoleLookLeftRight);
    return 0;
}

static int n_global_get(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    NSString *key = FMString(L, 1);
    return FMRetBool(L, (h && key) ? [h.delegate luaGlobalGetBool:key] : NO);
}

static int n_global_set(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    NSString *key = FMString(L, 1);
    if (h && key) FM_DELEGATE(h, luaGlobalSetBool:key);
    return 0;
}

static int n_is_passed(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    return FMRetBool(L, h ? [h.delegate luaIsLevelPassed:(NSInteger)FMNumber(L, 1)] : NO);
}

static int n_replay_mode(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaSetReplayMode);
    return 0;
}

static int n_play_mode(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaSetPlayMode);
    return 0;
}

static int n_load_rep(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    NSString *name = FMString(L, 1);
    if (h && name) FM_DELEGATE(h, luaLoadTutorialReplay:name);
    return 0;
}

static int n_replay_skip(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaReplaySkipNonControlFrames);
    return 0;
}

static int n_replay_pause(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaReplayPause);
    return 0;
}

static int n_set_skip(lua_State *L) {
    FMLuaHost *h = FMHostOf(L);
    if (h) FM_DELEGATE(h, luaSetSkipEnabled:FMBool(L, 1));
    return 0;
}

#pragma mark - 脚本前置

static const char *FM_PRELUDE =
    "local fm = fm\n"
    "dialog = {}\n"
    "function dialog.show(k, f, m) return coroutine.yield({kind='dialog', key=k, face=f or '', min=m or 0}) end\n"
    "function dialog.showMinTime(k, f, m) return coroutine.yield({kind='dialog', key=k, face=f or '', min=m or 0}) end\n"
    "function dialog.showFixedTime(k, f, m) return coroutine.yield({kind='dialog', key=k, face=f or '', min=m or 0, auto=true}) end\n"
    "function dialog.setSkipEnabled(v) fm.set_skip(v and true or false) end\n"
    "script = {}\n"
    "function script.delay(s) coroutine.yield({kind='delay', s=s}) end\n"
    "sound = {}\n"
    "function sound.play(id) fm.sound_play(id) end\n"
    "camera = {}\n"
    "function camera.gotoPosition(x, y) fm.cam_goto(x, y) end\n"
    "function camera.gotoRole() fm.cam_role() end\n"
    "function camera.setFollowRoleMode(v) fm.cam_follow(v and true or false) end\n"
    "game = {}\n"
    "function game.setUserInputEnabled(v) fm.set_input(v and true or false) end\n"
    "function game.pauseLogic() fm.pause() end\n"
    "function game.resumeLogic() fm.resume() end\n"
    "function game.restartTiming() fm.restart_timing() end\n"
    "function game.isRestart() return fm.is_restart() end\n"
    "function game.success() fm.success() end\n"
    "function game.showTutorialDiagram(n) fm.tutorial(n) end\n"
    "function game.setReplayMode() fm.replay_mode() end\n"
    "function game.setPlayMode() fm.play_mode() end\n"
    "function game.loadTutorialRep(n) fm.load_rep(n) end\n"
    "role = {}\n"
    "function role.setIdleActionEnabled(v) fm.set_idle(v and true or false) end\n"
    "function role.loadState() fm.load_state() end\n"
    "function role.lookLeftRight() fm.look_lr() end\n"
    "global = {}\n"
    "function global.getBool(k) return fm.global_get(k) end\n"
    "function global.setBool(k) fm.global_set(k) end\n"
    "function global.isLevelPassed(n) return fm.is_passed(n) end\n"
    "replay = {}\n"
    "function replay.skipNonControlFrames() fm.replay_skip() end\n"
    "function replay.pause() fm.replay_pause() end\n";

static NSString *const FMFaces[] = {
    @"faceBujie", @"faceDeyi", @"faceJingya", @"faceManyi", @"facePutong", @"faceQidao",
    @"faceRenzhen", @"faceShengqi", @"faceShijin", @"faceWeixiao", @"faceWunai", @"faceZhoumei",
};

#pragma mark - FMLuaHost

@interface FMLuaHost () {
    lua_State *_L;
    lua_State *_active;
    int _activeRef;
    double _delayRemaining;
}
@property (nonatomic, assign) NSInteger level;
@property (nonatomic, copy) NSString *script;
- (void)registerNatives;
- (void)resumeWithArgCount:(int)nargs;
- (void)handleYield;
- (void)resumeDelay;
- (void)releaseActive;
- (void)captureErrorFrom:(lua_State *)state;
- (void)failWithMessage:(NSString *)message;
@end

@implementation FMLuaHost

- (instancetype)initWithLevel:(NSInteger)level script:(NSString *)script {
    self = [super init];
    if (!self) { return nil; }
    _level = level;
    _script = [script copy] ?: @"";
    _activeRef = LUA_NOREF;
    _L = luaL_newstate();
    if (_L == NULL) { return nil; }
    luaopen_base(_L);
    luaopen_table(_L);
    luaopen_string(_L);
    luaopen_math(_L);
    lua_pushlightuserdata(_L, (__bridge void *)self);
    lua_setfield(_L, LUA_REGISTRYINDEX, "fm_host_ptr");
    [self registerNatives];
    return self;
}

- (void)dealloc {
    [self shutdown];
}

- (void)shutdown {
    if (_L) {
        lua_close(_L);
        _L = NULL;
        _active = NULL;
    }
}

- (void)registerNatives {
    struct { const char *name; lua_CFunction fn; } natives[] = {
        {"sound_play", n_sound_play}, {"cam_goto", n_cam_goto}, {"cam_role", n_cam_role},
        {"cam_follow", n_cam_follow}, {"set_input", n_set_input}, {"pause", n_pause},
        {"resume", n_resume}, {"restart_timing", n_restart_timing}, {"is_restart", n_is_restart},
        {"success", n_success}, {"tutorial", n_tutorial}, {"set_idle", n_set_idle},
        {"load_state", n_load_state}, {"look_lr", n_look_lr}, {"global_get", n_global_get},
        {"global_set", n_global_set}, {"is_passed", n_is_passed}, {"replay_mode", n_replay_mode},
        {"play_mode", n_play_mode}, {"load_rep", n_load_rep}, {"replay_skip", n_replay_skip},
        {"replay_pause", n_replay_pause}, {"set_skip", n_set_skip},
    };
    size_t count = sizeof(natives) / sizeof(natives[0]);
    lua_newtable(_L);
    for (size_t i = 0; i < count; i++) {
        lua_pushcfunction(_L, natives[i].fn);
        lua_setfield(_L, -2, natives[i].name);
    }
    lua_setglobal(_L, "fm");

    size_t faceCount = sizeof(FMFaces) / sizeof(FMFaces[0]);
    for (size_t i = 0; i < faceCount; i++) {
        const char *name = [FMFaces[i] UTF8String];
        lua_pushstring(_L, name);
        lua_setglobal(_L, name);
    }
}

#pragma mark - 运行

- (void)start {
    if (!_L) { return; }
    lua_State *L = _L;
    lua_State *T = lua_newthread(L);
    if (T == NULL) { [self failWithMessage:@"无法创建协程"]; return; }
    if (_activeRef != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, _activeRef); }
    _activeRef = luaL_ref(L, LUA_REGISTRYINDEX);
    _active = T;

    NSMutableString *code = [NSMutableString stringWithUTF8String:FM_PRELUDE];
    [code appendString:@"\n"];
    [code appendString:_script];
    NSString *chunk = [NSString stringWithFormat:@"@Level_%03ld.lua", (long)_level];
    const char *utf8 = code.UTF8String;
    int status = luaL_loadbuffer(T, utf8, strlen(utf8), chunk.UTF8String);
    if (status != 0) {
        [self captureErrorFrom:T];
        [self releaseActive];
        return;
    }
    _finished = NO;
    [self resumeWithArgCount:0];
}

- (void)resumeWithArgCount:(int)nargs {
    lua_State *T = _active;
    if (T == NULL) { return; }
    int status = lua_resume(T, nargs);
    if (status == 0) {
        lua_settop(T, 0);
        [self releaseActive];
        return;
    }
    if (status == LUA_YIELD) {
        [self handleYield];
        return;
    }
    [self captureErrorFrom:T];
    lua_settop(T, 0);
    [self releaseActive];
}

- (void)handleYield {
    lua_State *T = _active;
    if (T == NULL) { return; }
    FMLuaWaitKind kind = FMLuaWaitNone;
    double delay = 0;
    NSString *key = nil;
    NSString *face = nil;
    double minTime = 0;
    BOOL autoClose = NO;

    if (lua_gettop(T) >= 1 && lua_istable(T, -1)) {
        int table = lua_gettop(T);
        lua_getfield(T, table, "kind");
        NSString *kindString = FMString(T, -1);
        lua_pop(T, 1);
        lua_getfield(T, table, "key");
        key = FMString(T, -1);
        lua_pop(T, 1);
        lua_getfield(T, table, "face");
        face = FMString(T, -1);
        lua_pop(T, 1);
        lua_getfield(T, table, "min");
        minTime = FMNumber(T, -1);
        lua_pop(T, 1);
        lua_getfield(T, table, "s");
        delay = FMNumber(T, -1);
        lua_pop(T, 1);
        lua_getfield(T, table, "auto");
        autoClose = FMBool(T, -1);
        lua_pop(T, 1);
        if ([kindString isEqualToString:@"delay"]) { kind = FMLuaWaitDelay; }
        else if ([kindString isEqualToString:@"dialog"]) { kind = FMLuaWaitDialog; }
    }
    lua_settop(T, 0);

    _waitKind = kind;
    _waitDialogKey = key;
    _waitFace = face;
    _waitMinTime = minTime;
    _waitAutoClose = autoClose;
    _waitDelay = delay;
    if (kind == FMLuaWaitDelay) {
        _delayRemaining = MAX(0.0, delay);
        if (_delayRemaining <= 0) { [self resumeDelay]; }
    } else if (kind == FMLuaWaitNone) {
        [self resumeWithArgCount:0];
    }
}

- (void)resumeDelay {
    if (_active == NULL || _waitKind != FMLuaWaitDelay) { return; }
    _waitKind = FMLuaWaitNone;
    [self resumeWithArgCount:0];
}

- (void)tick:(double)dt {
    if (_waitKind != FMLuaWaitDelay || _active == NULL) { return; }
    _delayRemaining -= dt;
    if (_delayRemaining <= 0) { [self resumeDelay]; }
}

- (void)resolveDialogSkipped:(BOOL)skipped {
    if (_active == NULL || _waitKind != FMLuaWaitDialog) { return; }
    _waitKind = FMLuaWaitNone;
    _waitDialogKey = nil;
    _waitFace = nil;
    _waitAutoClose = NO;
    lua_pushinteger(_active, skipped ? 1 : 0);
    [self resumeWithArgCount:1];
}

- (void)callGlobal:(NSString *)name {
    if (!_L || name.length == 0) { return; }
    lua_State *L = _L;
    lua_State *T = lua_newthread(L);
    if (T == NULL) { return; }
    if (_activeRef != LUA_NOREF) { luaL_unref(L, LUA_REGISTRYINDEX, _activeRef); }
    _activeRef = luaL_ref(L, LUA_REGISTRYINDEX);
    _active = T;
    _waitKind = FMLuaWaitNone;

    lua_getglobal(L, name.UTF8String);
    if (lua_type(L, -1) != LUA_TFUNCTION) {
        lua_pop(L, 1);
        [self releaseActive];
        return;
    }
    lua_xmove(L, T, 1);
    [self resumeWithArgCount:0];
}

- (void)markFinished {
    _finished = YES;
}

- (void)releaseActive {
    if (!_L) { return; }
    if (_activeRef != LUA_NOREF) {
        luaL_unref(_L, LUA_REGISTRYINDEX, _activeRef);
        _activeRef = LUA_NOREF;
    }
    _active = NULL;
    _waitKind = FMLuaWaitNone;
}

- (void)captureErrorFrom:(lua_State *)L {
    NSString *message = FMString(L, -1);
    if (message.length == 0) { message = @"未知 Lua 错误"; }
    _lastError = message;
    NSLog(@"[FM][Lua] level %ld: %@", (long)_level, message);
}

- (void)failWithMessage:(NSString *)message {
    _lastError = message;
    NSLog(@"[FM][Lua] %@", message);
}

@end
