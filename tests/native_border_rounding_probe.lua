-- Replay the native one-pixel readback captured on 2026-10-27.
-- lua tests/native_border_rounding_probe.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={};local file=assert(io.open('embeds.xml'));local xml=file:read('*a');file:close()
for path in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(path))('NativeBorderRoundingProbe',private) end
local count,failures=0,0
local function Check(value,message)
 count=count+1
 if not value then failures=failures+1;print('FAIL: '..message) end
end
dofile('tests/native_border_rounding.lua')(private.LycheeUI,S,Check)
assert(failures==0,string.format('%d/%d border rounding checks failed',failures,count))
print('LycheeUI native border rounding: '..count..' checks passed')
