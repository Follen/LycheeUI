-- Standalone fixed-rule ownership regression; no hot theme engine.
local S=dofile("tests/stubs.lua");S.Install()
local private={};local file=assert(io.open("embeds.xml"));local xml=file:read("*a");file:close()
for name in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(name))("OwnershipFixture",private) end
local count=0
local function check(value,message) count=count+1;assert(value,message) end
dofile("tests/elements.lua")(S,private.LycheeUI,check,function(a,b) return math.abs(a-b)<.00001 end)
print("LycheeUI fixed ownership: "..count.." checks passed")
