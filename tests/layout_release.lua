-- Run from LycheeUI: lua tests/layout_release.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={}
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Elements','Native','Menu'}) do
 assert(loadfile(file..'.lua'))('LayoutRelease',private)
end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local ctx=LycheeUI:CreateContext({reducedMotion=true})

for _,vertical in ipairs({false,true}) do
 local factory=vertical and ctx.C.Column or ctx.C.Row
 local name=vertical and 'Column' or 'Row'
 for _,phase in ipairs({'unplaced','measured','placed','placedThenMeasured'}) do
  local parent=CreateFrame('Frame',nil,UIParent);parent:SetSize(300,100)
  local child=CreateFrame('Frame',nil,parent);child:SetSize(20,10)
  local observed=setmetatable({},{__mode='v'})
  local layout
  do
   local descriptor={frame=child,width=20,height=10,gapAfter=2}
   local items={descriptor};observed[1],observed[2]=descriptor,items
   layout=factory(parent,items,{width=300,height=100})
  end
  if phase=='measured' then layout:Measure()
  elseif phase=='placed' then layout:Layout()
  elseif phase=='placedThenMeasured' then layout:Layout();layout:Measure() end
  layout:Release();collectgarbage('collect')
  check(next(observed)==nil,name..' '..phase..' releases descriptors and item vector while the controller survives')
  check(child._lycheeLayoutOwner==nil and child._lycheeLayoutPlace==nil,name..' '..phase..' relinquishes native placement')
  check(#ctx.layouts==0,name..' '..phase..' is removed from font refresh layouts')
  layout:Release();collectgarbage('collect')
  check(next(observed)==nil and #ctx.layouts==0,name..' '..phase..' repeated Release retains no old items')
 end

 local parent=CreateFrame('Frame',nil,UIParent);parent:SetSize(300,100)
 local first,second=CreateFrame('Frame',nil,parent),CreateFrame('Frame',nil,parent)
 first:SetSize(20,10);second:SetSize(30,15)
 local layout=factory(parent,{{frame=first},{frame=second}},{width=300,height=100,gap=4})
 local width,height=layout:Layout()
 local record=layout.records[first]
 local writes=0
 for _,child in ipairs({first,second}) do
  for _,method in ipairs({'SetSize','SetWidth','SetHeight','SetPoint','ClearAllPoints'}) do
   local original=child[method]
   child[method]=function(self,...) writes=writes+1;return original(self,...) end
  end
 end
 for _=1,10 do
  local w,h=layout:Layout()
  check(w==width and h==height,name..' stable layout preserves content geometry')
 end
 check(writes==0 and layout.records[first]==record,name..' stable layout preserves its record and writes no native geometry')

 local takeover=factory(parent,{{frame=first,width=25,height=12}},{width=300,height=100,x=7,y=-3})
 takeover:Layout()
 local point,relative,relativePoint,x,y=first:GetPoint()
 writes=0;layout:Release();layout:Release()
 local a,b,c,px,py=first:GetPoint()
 check(first._lycheeLayoutOwner==takeover and first._lycheeLayoutPlace==takeover.records[first].place,name..' old release preserves newer placement ownership')
 check(a==point and b==relative and c==relativePoint and px==x and py==y and writes==0,name..' old release makes no native writes after takeover')
 check(second._lycheeLayoutOwner==nil,name..' old release still relinquishes its remaining child')
 check(#ctx.layouts==1 and ctx.layouts[1]==takeover,name..' old release preserves the active replacement registry')
 takeover:Release()
 check(#ctx.layouts==0 and first._lycheeLayoutOwner==nil,name..' replacement can release normally')
end
print('LycheeUI layout release: '..checks..' checks passed')
