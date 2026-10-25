-- Recursive read-only preparation cancels the active placement identity.
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do local path=file=='Layouts' and arg and arg[1] or file..'.lua';assert(loadfile(path))('RecursivePrepare',private) end
local checks,failures=0,{}
local function check(value,message) checks=checks+1;if not value then failures[#failures+1]=message;print('[FAIL] '..message) end end
local function frame(parent,w,h) local f=CreateFrame('Frame',nil,parent or UIParent);f:SetSize(w or 20,h or 16);f.GetStringWidth=false;f.GetStringHeight=false;f.GetSize=function(self) return self.w,self.h end;return f end
for _,action in ipairs({'measure','prepare','prepare-commit','measure-prepare-commit'}) do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local child=frame(host);local notices=0
 local l=ui.C.Row(host,{{frame=child,width=40,height=22}},{mode='flex',onLayout=function() notices=notices+1 end})
 local setter=child.SetWidth;local once=false
 child.SetWidth=function(self,value)
  setter(self,value)
  if not once then once=true
   if action=='measure' or action=='measure-prepare-commit' then local w,h=l:Measure();check(w==40 and h==22,action..' returns its measured content') end
   if action~='measure' then l:PrepareLayout() end
   if action=='prepare-commit' or action=='measure-prepare-commit' then l:CommitLayout() end
   check(self.h==16,action..' stays read-only inside the setter')
  end
 end
 l:Layout();child.SetWidth=setter
 check(l.dirty and notices==0 and l.records[child].committedW==nil,action..' cannot promote the cancelled outer cache or notify')
 check(child.w==40 and child.h==16,action..' prevents the outer batch later height write')
 l:Layout();check(not l.dirty and child.w==40 and child.h==22 and notices==1,action..' permits one normal retry');l:Release()
end
for _,direct in ipairs({false,true}) do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local a,b=frame(host),frame(host,30,16);local notices=0
 local l=ui.C.Row(host,{{frame=a,grow=1,height=16},{frame=b,grow=1,height=16}},{mode='flex',onLayout=function() notices=notices+1 end})
 local setter=a.SetWidth;local once=false;a.SetWidth=function(self,value) setter(self,value);if not once then once=true;l:Layout() end end
 if direct then l:PrepareLayout();l:CommitLayout() else l:Layout() end
 a.SetWidth=setter
 check(l.dirty and not l.prepared and a.w==45 and b.w==30 and notices==0,'recursive Layout cancels the partial batch: direct='..tostring(direct))
 check(l.records[a].committedW==nil,'recursive Layout cannot publish partial native cache: direct='..tostring(direct))
 l:Layout();check(a.w==45 and b.w==55 and notices==1,'recursive Layout preserves intrinsic inputs on retry: direct='..tostring(direct));l:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local child=frame(host);local notices=0
 local l=ui.C.Row(host,{{frame=child,width=40,height=22}},{mode='flex',track=true,onLayout=function() notices=notices+1 end})
 local setter=child.SetWidth;local once=false;child.SetWidth=function(self,value) setter(self,value);if not once then once=true;l:Layout();check(self.h==16 and l.records[child].committedW==nil,'scheduler commit reentry cannot write or publish inside its setter') end end
 ui:FlushLayouts();child.SetWidth=setter;ui:FlushLayouts()
 check(child.w==40 and child.h==22 and notices==1 and not l.dirty,'scheduler retries the deferred recursive Layout once');l:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local a,b=frame(host),frame(host,30,16)
 local l=ui.C.Row(host,{{frame=a,grow=1,height=16},{frame=b,grow=1,height=16}},{mode='flex'})
 local setter=a.SetWidth;local once=false;a.SetWidth=function(self,value) setter(self,value);if not once then once=true;l:Measure(200,40) end end
 l:Layout();a.SetWidth=setter
 check(l.dirty and a.w==45 and b.w==30,'cancelled intrinsic batch stops before later item writes')
 l:Layout();check(a.w==45 and b.w==55,'recursive measurement cannot make partial output a new intrinsic baseline');l:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local child=frame(host);local notices=0
 local l=ui.C.Row(host,{{frame=child,width=20,height=16}},{mode='flex',track=true,onLayout=function() notices=notices+1 end});l:Layout()
 local setter=child.SetWidth;local once=false;child.SetWidth=function(self,value) setter(self,value);if not once then once=true;l:Measure() end end
 l:SetItems({{frame=child,width=40,height=22}});l:Layout();child.SetWidth=setter
 check(l.dirty and l.records[child].committedW==20 and notices==1,'cancelled reflow preserves its last successful cache')
 ui:FlushLayouts();check(not l.dirty and child.h==22 and notices==2,'tracked recursive measurement queues the next batch');l:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local box=frame(host);local child=frame(box,40,20);local notices=0
 local setter=box.SetWidth;local once=false;box.SetWidth=function(self,value) setter(self,value);if not once then once=true;self._lycheeBoxLayout:Measure() end end
 local _,l=ui.C.Box(box,{layout='row',items={{frame=child,width=40,height=20}},width='content',height='content',onLayout=function() notices=notices+1 end});box.SetWidth=setter
 check(l.dirty and box.w==40 and box.h==16,'recursive content Box measurement cancels its later height write')
 check(l.boxCommittedW==nil and notices==0,'cancelled content Box cannot publish its pending native pair or notify')
 l:Layout();check(box.h==20 and notices==1 and not l.dirty,'content Box placement recovers in the next batch');ui.C.ReleaseBox(box)
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local a,b=frame(host),frame(host,30,16)
 local l=ui.C.Row(host,{{frame=a,grow=1,height=16},{frame=b,grow=1,height=16}},{mode='flex'})
 local setter=a.SetWidth;a.SetWidth=function(self,value) setter(self,value);l:Measure('invalid-width',40) end
 check(not pcall(l.Layout,l) and not l.preparing and not l.committing,'recursive measurement errors unwind both active phase guards')
 check(l.records[a].committedW==nil and not l.ownerSnapshots,'failed recursive measurement publishes no successful cache or prepared references')
 a.SetWidth=setter;l:Layout();check(a.w==45 and b.w==55,'failed recursive measurement preserves intrinsic inputs for recovery');l:Release()
end
for _,managePoints in ipairs({false,true}) do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40);local child=frame(host);local weak=setmetatable({},{__mode='v'});local live
 do
  local oldUI=LycheeUI:CreateContext({reducedMotion=true});local old=oldUI.C.Row(host,{child});old:Layout();local place=child._lycheeLayoutPlace
  weak[1],weak[2]=oldUI,old
  live=ui.C.Row(host,{{frame=child,width=30,height=18,managePoints=managePoints}},{mode='flex'});live:Layout()
  if managePoints then check(child._lycheeLayoutPlace==nil and child._lycheeLayoutOwner==live,'flex point claim drops the obsolete legacy helper')
  else check(child._lycheeLayoutPlace==place and child._lycheeLayoutOwner==old,'manual points preserve the current legacy helper and owner') end
  old:Release()
 end
 collectgarbage('collect');collectgarbage('collect')
 check(weak[1]==nil and weak[2]==nil,'legacy-to-flex released Context and controller collect: points='..tostring(managePoints))
 check(child.w==30 and child.h==18 and child._lycheeLayoutFields.width==live,'late legacy release preserves new dimensions')
 if managePoints then check(child._lycheeLayoutOwner==live,'late legacy release preserves new point ownership') end
 live:Release()
end
assert(#failures==0,table.concat(failures,'; '));print('LycheeUI recursive preparation: '..checks..' checks passed')
