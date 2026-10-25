-- A setter may transfer just one field; old batches cannot reclaim that field.
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('FlexFieldOwnership',private) end
local checks,failures=0,{}
local function check(value,message) checks=checks+1;if not value then failures[#failures+1]=message;print('[FAIL] '..message) end end
local function frame(parent,w,h) local f=CreateFrame('Frame',nil,parent or UIParent);f:SetSize(w or 20,h or 16);f.GetStringHeight=false;f.GetStringWidth=false;f.GetSize=function(self) return self.w,self.h end;return f end
for _,kind in ipairs({'height-from-width','points-from-width','points-from-height','both-axes'}) do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local host=frame(nil,100,40);local child=frame(host)
 local notices=0;local old=C.Row(host,{{frame=child,width=40,height=20}},{mode='flex',onLayout=function() notices=notices+1 end});old:Layout()
 old:SetItems({{frame=child,width=50,height=21}})
 local setter=kind=='points-from-height' and 'SetHeight' or 'SetWidth';local native=child[setter];local successor
 child[setter]=function(self,value)
  native(self,value)
  if not successor then
   local spec={frame=child,manageWidth=false,manageHeight=false,managePoints=false}
   if kind=='height-from-width' then spec.height,spec.manageHeight=22,true
   elseif kind=='both-axes' then spec.width,spec.height,spec.manageWidth,spec.manageHeight=33,22,true,true
   else spec.managePoints=true end
   successor=C.Row(host,{spec},{mode='flex',x=9});successor:Layout()
  end
 end
 old:Layout();child[setter]=native
 local fields=child._lycheeLayoutFields
 if kind=='height-from-width' or kind=='both-axes' then check(child.h==22 and fields.height==successor,kind..' keeps successor height')
 else check(select(4,child:GetPoint())==9 and child._lycheeLayoutOwner==successor and fields.points==successor,kind..' keeps successor point placement') end
 if kind=='both-axes' then check(child.w==33 and fields.width==successor,'both-axes still stops the old width batch') end
 check(old.dirty and notices==1 and old.records[child].committedW==40,kind..' cannot publish partial success cache or notification')
 old:Release()
 if kind=='height-from-width' or kind=='both-axes' then check(child._lycheeLayoutFields and child._lycheeLayoutFields.height==successor,kind..' delayed release preserves successor field')
 else check(child._lycheeLayoutOwner==successor,kind..' delayed release preserves successor points') end
 successor:Release()
end
do
 -- Releasing an unrelated manual controller can remove an empty lease table
 -- during placement completion. The old local table then ceases to be current.
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local host=frame(nil,100,40);local child=frame(host)
 local manual=C.Row(host,{{frame=child,manageWidth=false,manageHeight=false,managePoints=false}},{mode='flex'});manual:Layout()
 local oldFields=child._lycheeLayoutFields
 local old=C.Row(host,{{frame=child,width=40,height=20}},{mode='flex'});local successor
 ui.Motion.placements[child]={}
 ui.Motion.FinishPlacement=function(self,target)
  self.placements[target]=nil;manual:Release()
  successor=C.Row(host,{{frame=child,manageWidth=false,height=22,managePoints=false}},{mode='flex'});successor:Layout()
 end
 old:Layout()
 check(oldFields~=child._lycheeLayoutFields,'callback lifecycle replaces the physical lease table')
 check(child.h==22 and child._lycheeLayoutFields.height==successor,'replacement table governs the next height write')
 check(old.dirty and old.records[child].committedW==nil,'stale lease table cannot publish a successful batch')
 old:Release();check(child._lycheeLayoutFields.height==successor,'old release leaves the replacement lease table owner intact');successor:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local host=frame(nil,100,40);local box=frame(host);local child=frame(box,40,20)
 local width=box.SetWidth;local successor
 box.SetWidth=function(self,value)
  width(self,value)
  if not successor then successor=C.Row(host,{{frame=box,manageWidth=false,height=22,managePoints=false}},{mode='flex'});successor:Layout() end
 end
 local _,old=C.Box(box,{layout='row',width='content',height='content',items={{frame=child,width=40,height=20}}})
 box.SetWidth=width
 check(box.h==22 and box._lycheeLayoutFields.height==successor,'content Box width callback cannot reclaim a new height owner')
 check(old.dirty and old.boxCommittedW==nil,'interrupted content Box does not publish its pending pair')
 C.ReleaseBox(box);check(box._lycheeLayoutFields.height==successor,'content Box release preserves the succeeding height lease');successor:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=frame(nil,100,40)
 local label=host:CreateFontString(nil,'OVERLAY');label:SetText('text');label:SetFont('font',14,'')
 local original=label.GetStringHeight;local weak=setmetatable({},{__mode='v'})
 local function wrapper(method,payload) return function(...) local keep=payload;return method(...) end end
 do local payload={};weak[1]=payload;label.GetStringHeight=wrapper(original,payload) end
 local l=ui.C.Row(host,{{frame=label,width='content',height=16}},{mode='flex'});l:Layout();label.GetStringHeight=original
 collectgarbage('collect');collectgarbage('collect')
 check(type(l.records[label].contentMetrics)=='boolean','content metric capability stores only a boolean')
 check(weak[1]==nil,'restored text getter does not leave its captured payload retained by layout record');l:Release()
end
assert(#failures==0,table.concat(failures,'; '))
print('LycheeUI flex field ownership: '..checks..' checks passed')
