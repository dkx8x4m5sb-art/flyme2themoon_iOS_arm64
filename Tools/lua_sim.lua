#!/usr/bin/env lua
-- 本地（Linux/macOS）跑一遍关卡脚本，确认 prelude 覆盖了脚本用到的全部接口。
-- 用法: lua Tools/lua_sim.lua <Resources/data/lua>
local luaDir = arg[1] or "Resources/data/lua"

local counts = {}
local function note(name) counts[name] = (counts[name] or 0) + 1 end

fm = {}
fm.sound_play = function(id) note("sound") end
fm.cam_goto = function() note("cam_goto") end
fm.cam_role = function() note("cam_role") end
fm.cam_follow = function() note("cam_follow") end
fm.set_input = function() note("set_input") end
fm.pause = function() note("pause") end
fm.resume = function() note("resume") end
fm.restart_timing = function() note("restart_timing") end
fm.is_restart = function() return false end
fm.success = function() note("success") end
fm.tutorial = function() note("tutorial") end
fm.set_idle = function() note("set_idle") end
fm.load_state = function() note("load_state") end
fm.look_lr = function() note("look_lr") end
fm.global_get = function() return false end
fm.global_set = function() note("global_set") end
fm.is_passed = function() return false end
fm.replay_mode = function() note("replay_mode") end
fm.play_mode = function() note("play_mode") end
fm.load_rep = function() note("load_rep") end
fm.replay_skip = function() note("replay_skip") end
fm.replay_pause = function() note("replay_pause") end
fm.set_skip = function() note("set_skip") end

local prelude = [[
local fm = fm
dialog = {}
function dialog.show(k, f, m) return coroutine.yield({kind='dialog', key=k, face=f or '', min=m or 0}) end
function dialog.showMinTime(k, f, m) return coroutine.yield({kind='dialog', key=k, face=f or '', min=m or 0}) end
function dialog.showFixedTime(k, f, m) return coroutine.yield({kind='dialog', key=k, face=f or '', min=m or 0, auto=true}) end
function dialog.setSkipEnabled(v) fm.set_skip(v and true or false) end
script = {}
function script.delay(s) coroutine.yield({kind='delay', s=s}) end
sound = {}
function sound.play(id) fm.sound_play(id) end
camera = {}
function camera.gotoPosition(x, y) fm.cam_goto(x, y) end
function camera.gotoRole() fm.cam_role() end
function camera.setFollowRoleMode(v) fm.cam_follow(v and true or false) end
game = {}
function game.setUserInputEnabled(v) fm.set_input(v and true or false) end
function game.pauseLogic() fm.pause() end
function game.resumeLogic() fm.resume() end
function game.restartTiming() fm.restart_timing() end
function game.isRestart() return fm.is_restart() end
function game.success() fm.success() end
function game.showTutorialDiagram(n) fm.tutorial(n) end
function game.setReplayMode() fm.replay_mode() end
function game.setPlayMode() fm.play_mode() end
function game.loadTutorialRep(n) fm.load_rep(n) end
role = {}
function role.setIdleActionEnabled(v) fm.set_idle(v and true or false) end
function role.loadState() fm.load_state() end
function role.lookLeftRight() fm.look_lr() end
global = {}
function global.getBool(k) return fm.global_get(k) end
function global.setBool(k) fm.global_set(k) end
function global.isLevelPassed(n) return fm.is_passed(n) end
replay = {}
function replay.skipNonControlFrames() fm.replay_skip() end
function replay.pause() fm.replay_pause() end
]]

local faces = {"faceBujie","faceDeyi","faceJingya","faceManyi","facePutong","faceQidao",
               "faceRenzhen","faceShengqi","faceShijin","faceWeixiao","faceWunai","faceZhoumei"}
for _, name in ipairs(faces) do _G[name] = name end

-- 用协程驱动：遇到 yield 一律按“玩家点了继续”回 0
local function drive(co, label)
  local yields = 0
  local ok, value = coroutine.resume(co)
  while true do
    if not ok then
      io.stderr:write(("%s => %s\n"):format(label, tostring(value)))
      return false, yields
    end
    if coroutine.status(co) == "dead" then return true, yields end
    yields = yields + 1
    if yields > 4000 then
      io.stderr:write(label .. " => yield 次数过多\n")
      return false, yields
    end
    ok, value = coroutine.resume(co, 0)
  end
end

local failed = 0
local ran = 0
for i = 1, 60 do
  local path = string.format("%s/Level_%03d.lua", luaDir, i)
  local f = io.open(path, "rb")
  if not f then
    io.stderr:write("缺脚本 " .. path .. "\n")
    failed = failed + 1
  else
    local body = f:read("*a")
    f:close()
    local fn, err = loadstring(prelude .. "\n" .. body, "@Level_" .. i)
    if not fn then
      io.stderr:write(("Level_%03d 语法错误: %s\n"):format(i, tostring(err)))
      failed = failed + 1
    else
      ran = ran + 1
      local co = coroutine.create(function() fn() end)
      local ok = drive(co, ("Level_%03d 主流程"):format(i))
      if not ok then
        failed = failed + 1
      else
        for _, cb in ipairs({"onRoleReachedMoon", "onRoleDied"}) do
          local g = _G[cb]
          if type(g) == "function" then
            local co2 = coroutine.create(function() g() end)
            if not drive(co2, ("Level_%03d %s"):format(i, cb)) then
              failed = failed + 1
            end
          end
        end
      end
    end
  end
end

io.write(("跑完 %d 个脚本，失败 %d 个\n"):format(ran, failed))
io.write(("统计：success=%d tutorial=%d dialog.setSkip=%d load_rep=%d\n"):
  format(counts.success or 0, counts.tutorial or 0, counts.set_skip or 0, counts.load_rep or 0))
os.exit(failed == 0 and 0 or 1)
