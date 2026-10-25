-- Replays the captured first-acquisition 1x1 fill / 0x0 border transition.
-- Run from LycheeUI: lua tests/native_background_probe.lua
local S=dofile("tests/stubs.lua");S.Install()
local private={};local f=assert(io.open("embeds.xml"));local xml=f:read("*a");f:close()
for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(file))("NativeBackgroundProbe",private) end
local count,failures=0,0
local function check(value,message)
 count=count+1
 if not value then failures=failures+1;print("FAIL: "..message) end
end
dofile("tests/native_background.lua")(private.LycheeUI,S,check)
assert(failures==0,string.format("%d/%d native background checks failed",failures,count))
print("LycheeUI native background: "..count.." checks passed")
