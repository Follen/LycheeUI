-- Deterministic Lua-work evidence, not a substitute for native CPU gates.
-- Run from LycheeUI: lua tests/flex_work.lua
-- Optional `embedded` reads the current consuming copy, not a pinned baseline.
local S=dofile('tests/stubs.lua');S.Install()
local private={}
local prefix=arg and arg[1]=='embedded' and '../LycheeGroup/addon/LycheeGroup/Libs/LycheeUI/' or arg and arg[1]=='round4' and '../LycheeGroup/.lycheedev/responsive-layout/before-memory-LycheeUI/' or ''
local useSize=arg and (arg[1]=='size' or arg[2]=='size')
local legacy=arg and (arg[1]=='legacy' or arg[2]=='legacy' or arg[3]=='legacy')
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(prefix..file..'.lua'))('FlexWork',private) end
local function instructions(fn)
 local ticks=0;debug.sethook(function() ticks=ticks+1 end,'',100);fn();debug.sethook();return ticks*100
end
for _,vertical in ipairs({false,true}) do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
 local parent=CreateFrame('Frame',nil,UIParent);parent:SetSize(720,640)
 if useSize then parent.GetSize=function(self) return self.w,self.h end end
 local items={};local native={reads=0,writes=0,measure=0};local fieldCalls=0
 local field=C.LayoutValue;C.LayoutValue=function(...) fieldCalls=fieldCalls+1;return field(...) end
 for i=1,24 do
  local f
  if i%2==0 then f=C.Text(parent,'Mixed item '..i,14) else f=CreateFrame('Frame',nil,parent);f.GetStringWidth=false;f.GetStringHeight=false end
  f:SetSize(20,16);items[i]={frame=f,width=20,height=16}
  if useSize then f.GetSize=function(self) return self.w,self.h end end
  for _,name in ipairs({'GetWidth','GetHeight','GetPoint','GetNumPoints','GetEffectiveScale','IsShown','GetSize'}) do local original=f[name];if original then f[name]=function(self,...) native.reads=native.reads+1;return original(self,...) end end end
  for _,name in ipairs({'SetWidth','SetHeight','SetPoint','ClearAllPoints'}) do local original=f[name];f[name]=function(self,...) native.writes=native.writes+1;return original(self,...) end end
  for _,name in ipairs({'GetStringHeight','GetUnboundedStringWidth'}) do local original=f[name];if original then f[name]=function(self,...) native.measure=native.measure+1;return original(self,...) end end end
 end
 local factory=vertical and C.Column or C.Row;local layout=factory(parent,items,{mode=not legacy and 'flex' or nil,gap=3,height=640});layout:Layout()
 for _,scene in ipairs({'fixed','width','stable'}) do
  for i,item in ipairs(items) do item.width=scene=='width' and (vertical or i==1) and 'fill' or 20 end
  layout:SetItems(items);layout:Layout()
  native.reads,native.writes,native.measure,fieldCalls=0,0,0,0
  local count=instructions(function() for i=1,20 do
   if scene=='fixed' then layout:SetItems(items) elseif scene=='width' then parent:SetWidth(i%2==0 and 720 or 960) end
   layout:Layout()
  end end)
  print((vertical and 'column_' or 'row_')..scene..' instructions='..count..' fields='..fieldCalls..' nativeReads='..native.reads..' nativeWrites='..native.writes..' measurements='..native.measure)
  if scene=='stable' then assert(native.writes==0 and native.measure==0,'stable layout must not write geometry or measure text') end
  if prefix=='' and not legacy then assert(count<(scene=='fixed' and 300000 or scene=='width' and 700000 or 140000),'plain layout Lua work exceeded its recorded regression budget') end
 end
 layout:Release()
end
