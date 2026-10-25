-- Exact successful native pairs transfer with the actual field/point owner.
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do local dir=arg and arg[1]=='embedded-layout' and file=='Layouts' and '../LycheeGroup/addon/LycheeGroup/Libs/LycheeUI/' or '';assert(loadfile(dir..file..'.lua'))('InheritedPairs',private) end
local checks,failures=0,{}
local function check(value,message) checks=checks+1;if not value then failures[#failures+1]=message;print('[FAIL] '..message) end end
local function single(value) if value==0 then return 0 end;local sign=value<0 and -1 or 1;local m,e=math.frexp(math.abs(value));return sign*math.ldexp(math.floor(m*16777216+.5)/16777216,e) end
local function read(value,origin,scale) return single((single(origin+value*scale)-single(origin))/scale) end
local writes={width=0,height=0,points=0}
local function frame(parent,w,h)
 local f=CreateFrame('Frame',nil,parent or UIParent);f:SetSize(w or 20,h or 16);f.GetStringWidth=false;f.GetStringHeight=false
 return f
end
local function quantized(parent)
 local f=frame(parent);local width,height,point,getPoint=f.SetWidth,f.SetHeight,f.SetPoint,f.GetPoint
 f.GetWidth=function(self) return read(self.w,500+(self._x or 0)*self:GetEffectiveScale(),self:GetEffectiveScale()) end
 f.GetHeight=function(self) return read(self.h,700+(self._y or 0)*self:GetEffectiveScale(),self:GetEffectiveScale()) end
 f.GetSize=function(self) return self:GetWidth(),self:GetHeight() end
 f.SetWidth=function(self,v) writes.width=writes.width+1;return width(self,v) end
 f.SetHeight=function(self,v) writes.height=writes.height+1;return height(self,v) end
 f.SetPoint=function(self,a,b,c,x,y) writes.points=writes.points+1;self._x,self._y=x,y;return point(self,a,b,c,x,y) end
 f.GetPoint=function(self) local a,b,c,x,y=getPoint(self);if a then return a,b,c,read(x,1000,self:GetEffectiveScale()),read(y,700,self:GetEffectiveScale()) end end
 return f
end
local previousPhysical=GetPhysicalScreenSize;GetPhysicalScreenSize=function() return 2560,1440 end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,300,100);host:SetScale(.71111112833023071)
 local items={};for i=1,24 do items[i]={frame=quantized(host),width=20,height=16} end
 local first=ui.C.Row(host,items,{mode='flex',gap=3});first:Layout();writes.width,writes.height,writes.points=0,0,0
 local second=ui.C.Row(host,items,{mode='flex',gap=3});local ticks=0;debug.sethook(function() ticks=ticks+1 end,'',100);second:Layout();debug.sethook()
 print('same owner handoff native writes: width='..writes.width..' height='..writes.height..' points='..writes.points)
 print('same owner handoff instructions='..(ticks*100))
 check(writes.width==0 and writes.height==0,'same successful native request/readback pairs avoid duplicate dimension writes on new owners')
 check(writes.points==0,'same successful native anchor/readback pair avoids duplicate placement on new owner')
 collectgarbage('stop');local before=collectgarbage('count');for _=1,20 do second:Layout() end;local after=collectgarbage('count');collectgarbage('restart')
 check(after==before,'stable layouts allocate no temporary Lua objects after handoff')
 local child=items[2].frame;child.w=88;child:ClearAllPoints();child:SetPoint('BOTTOMLEFT',host,'BOTTOMLEFT',3,4)
 writes.width,writes.height,writes.points=0,0,0
 local third=ui.C.Row(host,items,{mode='flex',gap=3});third:Layout()
 check(writes.width>0 and writes.points>0 and child.w==third.records[child].committedW,'external native mutations cannot inherit stale readbacks')
 first:Release();second:Release();third:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);host:SetScale(.71111112833023071);local child=quantized(host)
 local old=ui.C.Row(host,{{frame=child,width=20,height=16}},{mode='flex'});old:Layout()
 local setter=child.SetWidth;child.SetWidth=function() error('native write rejected before changing geometry') end
 old:SetItems({{frame=child,width=30,height=16}});check(not pcall(old.Layout,old),'old owner can retain a last successful pair after a failed new request')
 child.SetWidth=setter;writes.width=0
 local clean=ui.C.Row(host,{{frame=child,width=20,height=16}},{mode='flex'});clean:Layout()
 check(writes.width>0,'a failed old owner cannot supply inherited pairs even when its older native geometry still matches')
 old:Release();clean:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,300,100);host:SetScale(.71111112833023071);local child=quantized(host)
 local a=ui.C.Row(host,{{frame=child,width=20,height=16}},{mode='flex'});a:Layout()
 local b=ui.C.Row(host,{{frame=child,manageWidth=false,height=18,managePoints=false}},{mode='flex'});b:Layout()
 writes.width,writes.height,writes.points=0,0,0
 local c=ui.C.Row(host,{{frame=child,width=20,height=18}},{mode='flex'});c:Layout()
 check(writes.width==0 and writes.height==0,'split current width and height owners supply only their own exact committed pair')
 child:SetScale(1.25);writes.width,writes.height=0,0
 local scaled=ui.C.Row(host,{{frame=child,width=20,height=18}},{mode='flex'});scaled:Layout()
 check(writes.width>0 and writes.height>0 and child.w==scaled.records[child].committedW,'changed child scale cannot reuse an incompatible old pair')
 local other=frame(nil,300,100);other:SetScale(host:GetScale());writes.width,writes.height,writes.points=0,0,0
 local moved=ui.C.Row(other,{{frame=child,width=20,height=18}},{mode='flex'});moved:Layout()
 check(writes.width>0 and writes.points>0 and select(2,child:GetPoint())==other,'changed layout parent cannot inherit old parent placement or dimension pairs')
 a:Release();b:Release();c:Release();scaled:Release();moved:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);host:SetScale(.71111112833023071);local child=quantized(host)
 local first=ui.C.Row(host,{{frame=child,width=20,height=16}},{mode='flex'});first:Layout()
 local setter=child.SetWidth;local successor;local nested=false
 local retry=ui.C.Row(host,{{frame=child,width=30,height=16}},{mode='flex'})
 child.SetWidth=function(self,value)
  setter(self,value)
  if not nested then nested=true;successor=ui.C.Row(host,{{frame=child,width=30,height=16}},{mode='flex'});successor:Layout();error('outer setter failed after a different owner committed the same target') end
 end
 check(not pcall(retry.Layout,retry) and retry.failedInputGeneration~=nil,'failed outer setter retains retry status after a successor committed matching native geometry')
 check(not retry.ownerSnapshots and retry.records[child].ownerWidth==nil,'setter failure releases prepared owner references')
 child.SetWidth=setter;writes.width=0;retry:Layout()
 check(writes.width>0 and not retry.dirty,'a failed batch retry cannot bypass its setter via an inherited successful pair')
 first:Release();successor:Release();retry:Release()
end
do
 local host=frame(nil,100,40);local child=frame(host);child.GetSize=function(self) return self.w,self.h end
 local nextUI=LycheeUI:CreateContext({reducedMotion=true});local live
 local weak=setmetatable({},{__mode='v'})
 do
  local oldUI=LycheeUI:CreateContext({reducedMotion=true});local old=oldUI.C.Row(host,{{frame=child,width=20,height=16}},{mode='flex'});old:Layout()
  weak[1],weak[2]=oldUI,old
  live=nextUI.C.Row(host,{{frame=child,width=20,height=16}},{mode='flex'});live:Layout();old:Release()
 end
 live:Layout();collectgarbage('collect');collectgarbage('collect')
 check(weak[1]==nil and weak[2]==nil,'successful stable layout does not retain a prepared previous owner or its Context')
 live:Release()
end
do
 local nextUI=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local child=frame(host)
 local weak=setmetatable({},{__mode='v'});local pending
 do
  local oldUI=LycheeUI:CreateContext({reducedMotion=true});local old=oldUI.C.Row(host,{child},{mode='flex'});old:Layout();weak[1],weak[2]=oldUI,old
  pending=nextUI.C.Row(host,{child},{mode='flex'});pending:PrepareLayout()
  check(pending.records[child].ownerWidth==old,'live prepared batches keep their owner snapshot until the lease is checked')
  old:Release()
 end
 collectgarbage('collect');check(weak[1]~=nil,'prepared lease snapshot intentionally keeps the prior owner alive before commit')
 pending:CommitLayout();collectgarbage('collect');collectgarbage('collect')
 check(pending.dirty and weak[1]==nil and weak[2]==nil,'rejected commit releases the now-terminal owner snapshot and Context')
 pending:Layout();pending:PrepareLayout();pending:Invalidate('cancel prepared pass')
 check(not pending.ownerSnapshots and pending.records[child].ownerWidth==nil,'explicit cancellation releases prepared owner snapshots')
 pending:PrepareLayout();pending:Measure()
 check(not pending.ownerSnapshots and pending.records[child].ownerWidth==nil,'measurement releases its non-placement owner snapshots')
 local bad=frame(host);pending:SetItems({child,{frame=bad,width='invalid-declaration'}})
 check(not pcall(pending.PrepareLayout,pending) and not pending.ownerSnapshots and pending.records[child].ownerWidth==nil,'preparation error releases snapshots captured before the failing item')
 pending:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local child=frame(host);local l=ui.C.Row(host,{{frame=child,width=20,height=16}},{mode='flex'});l:Layout()
 local setter=child.SetWidth;child.SetWidth=function(self,value) setter(self,value);l:CommitLayout() end
 l:SetItems({{frame=child,width=40,height=22}});l:Layout()
 check(not l.dirty and child.w==40 and child.h==l.records[child].committedH,'nested no-op commit cannot clear an active outer batch owner snapshot')
 child.SetWidth=setter;l:Release()
end
GetPhysicalScreenSize=previousPhysical
assert(#failures==0,table.concat(failures,'; '));print('LycheeUI inherited native pairs: '..checks..' checks passed')
