-- Focused native-anchor behavior and allocation loop. Run in LycheeUI:
-- lua tests/setpoint-cost.lua [optional alternate Styles.lua path]
local S=dofile("tests/stubs.lua");S.Install()
local manifest=assert(io.open("embeds.xml"));local xml=manifest:read("*a");manifest:close()
local private={}
for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(file=="Styles.lua" and arg[1] or file))("LycheeUI",private) end
local L=LycheeUI
local ctx=L:CreateContext({reducedMotion=true,elementDefaults={anchor={template=true,slotKinds={root="box"}},other={slotKinds={root="box"}}}})
local C=ctx.C;local parent=CreateFrame("Frame",nil,UIParent);local frame=CreateFrame("Frame",nil,parent)
local checks=0
local function Check(value,label) checks=checks+1;assert(value,label) end
local function Point(index,a,b,c,x,y)
 local pa,pb,pc,px,py=frame:GetPoint(index or 1)
 Check(pa==a and pb==b and pc==c and px==x and py==y,"expected native anchor "..a)
end
C.SetPoint(frame,"LEFT",parent,"LEFT",4,5);Point(1,"LEFT",parent,"LEFT",4,5)
frame:ClearAllPoints();C.SetPoint(frame,"LEFT",parent,"LEFT",4,5);Point(1,"LEFT",parent,"LEFT",4,5)
C.SetPoint(frame,"RIGHT",parent,"RIGHT",-4,5);Check(frame:GetNumPoints()==2,"new anchor names append")
C.SetPoint(frame,"LEFT",parent,"LEFT",8,9);Point(1,"LEFT",parent,"LEFT",8,9);Point(2,"RIGHT",parent,"RIGHT",-4,5)
frame:ClearAllPoints();C.SetPoint(frame,"LEFT",parent,"LEFT",8,9);Check(frame:GetNumPoints()==1,"clearing native anchors removes earlier bound names")
frame:SetPoint("LEFT",parent,"RIGHT",40,50)
C.SetPoint(frame,"LEFT",parent,"LEFT",8,9);Point(1,"LEFT",parent,"LEFT",8,9)
Check(not frame._lycheeStyleState,"native point convenience retains no generic restoration history")
frame:ClearAllPoints();C.SetPoint(frame,"LEFT",parent,"LEFT","gap",0);Point(1,"LEFT",parent,"LEFT",ctx.Theme.gap,0)
Check(not pcall(C.SetPoint,frame,"LEFT",parent,"LEFT","invalid-point-token",0),"unknown point tokens reject")

-- Native C methods do not allocate Lua records. Reuse the stub's native
-- records here so its table implementation does not obscure library costs.
local target=CreateFrame("Frame",nil,parent);local records={};local points={}
function target:ClearAllPoints() for index=#points,1,-1 do points[index]=nil end end
function target:SetPoint(a,b,c,x,y)
 local selected=#points+1;for index,p in ipairs(points) do if p[1]==a then selected=index;break end end
 local p=records[selected] or {};records[selected]=p;points[selected]=p
 p[1],p[2],p[3],p[4],p[5]=a,b,c,x,y
end
function target:GetNumPoints() return #points end
function target:GetPoint(index) return unpack(points[index or 1] or {}) end
local function Measure(name,multiple)
 for index=1,2 do target:ClearAllPoints();C.SetPoint(target,"LEFT",parent,"LEFT","gap",0);if multiple then C.SetPoint(target,"RIGHT",parent,"RIGHT",-4,0) end end
 collectgarbage("collect");collectgarbage("stop")
 local before=collectgarbage("count");local start=os.clock()
 for index=1,1000 do target:ClearAllPoints();C.SetPoint(target,"LEFT",parent,"LEFT","gap",0);if multiple then C.SetPoint(target,"RIGHT",parent,"RIGHT",-4,0) end end
 local cost,elapsed=collectgarbage("count")-before,os.clock()-start
 collectgarbage("restart")
 print(string.format("%s iterations=1000 allocatedKiB=%.3f cpuMs=%.3f",name,cost,elapsed*1000))
end
Measure("clear-single",false);Measure("clear-double",true)
print("SetPoint: "..checks.." focused assertions passed")
