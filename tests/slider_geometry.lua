-- Shared slider geometry follows the shell without replaying value callbacks.
local S=dofile("tests/stubs.lua");S.Install()
local private={}
local manifest=assert(io.open("embeds.xml"));local xml=manifest:read("*a");manifest:close()
for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(file))("SliderGeometry",private) end
local C=LycheeUI:CreateContext({reducedMotion=true}).C
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local changes=0
local ordinary=C.Slider(UIParent,100,0,100,1,function() changes=changes+1 end)
ordinary:SetValue(100);ordinary:SetWidth(153)
check(ordinary.progress:GetWidth()==153,"ordinary fill follows resized shell at maximum")
ordinary:SetValue(50);ordinary:SetWidth(200)
check(ordinary.progress:GetWidth()==100,"ordinary fill preserves its ratio on resize")
check(ordinary:GetValue()==50 and changes==0,"resizing does not dispatch a value change")
local previews=0
local manual=C.Slider(UIParent,100,0,100,1,function() changes=changes+1 end,
 {commitOnRelease=true,onPreview=function() previews=previews+1 end})
manual:SetValue(75);local previous=previews;manual:SetWidth(200)
check(manual.slider:GetWidth()==200,"manual hit track follows resized shell")
check(manual.progress:GetWidth()==150,"manual fill follows resized track")
check(select(4,manual.thumb:GetPoint())==150,"manual thumb follows resized track")
check(manual:GetValue()==75 and previews==previous and changes==0,"resize does not replay preview or commit callbacks")
check(not manual:IsDragging() and manual.slider:GetScript("OnUpdate")==nil,"resizing adds no drag sampler")
print("LycheeUI slider geometry: "..count.." checks passed")
