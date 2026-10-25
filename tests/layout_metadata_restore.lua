-- Inactive state/condition declarations preserve the caller's layout defaults.
-- Run from LycheeUI: lua tests/layout_metadata_restore.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={}
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('LayoutMetadataRestore',private) end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function frame(parent,w,h)
 local target=CreateFrame('Frame',nil,parent or UIParent);target:SetSize(w,h)
 target.GetStringHeight=false;target.GetStringWidth=false;return target
end
local function position(target) local _,_,_,x,y=target:GetPoint();return x,y end
local function rule(condition,part)
 if condition then return {conditions={{container='metadata',minWidth=500,base={root=part}}}} end
 return {states={disabled={root=part}}}
end
for _,vertical in ipairs({false,true}) do
 for _,condition in ipairs({false,true}) do
  for _,late in ipairs({false,true}) do
   local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
   local outer=frame(nil,400,100);C.Container(outer,'metadata')
   local host=frame(outer,160,100);local child=frame(host,20,10)
   local layout
   local function createLayout()
    layout=(vertical and C.Column or C.Row)(host,{{frame=child,width=20,height=10,minWidth=30,minHeight=20,align='center'}},{mode='flex',height=100})
    layout:Layout()
   end
   if late then createLayout() end
   C.Element(child,'metadata-state',{classes=rule(condition,{minWidth=90,minHeight=40,align='end',fit='contain'})})
   if not late then createLayout() else layout:Layout() end
   local function baseline(label)
    local x,y=position(child)
    check(child:GetWidth()==30 and child:GetHeight()==20,label..' keeps descriptor minima')
    check(x==(vertical and 65 or 0) and y==(vertical and 0 or -40),label..' keeps descriptor alignment')
    local box=child._lycheeBoxValues
    for _,key in ipairs({'minWidth','minHeight','align','fit'}) do
     check(not box or box[key]==nil,label..' restores absence of '..key)
    end
   end
   baseline('inactive '..tostring(late))
   if condition then outer:SetWidth(600) else child:Disable();C.ApplyElement(child) end
   layout:Layout()
   local x,y=position(child)
   check(child:GetWidth()==90 and child:GetHeight()==40,'active rules replace both minima')
   check(x==(vertical and 70 or 0) and y==(vertical and 0 or -60),'active rules replace alignment')
   check(C.LayoutValue(child,'fit')=='contain','active fit is available')
   if condition then outer:SetWidth(400) else child:Enable();C.ApplyElement(child) end
   layout:Layout();baseline('state or condition exit')
   C.ReleaseElement(child);layout:Layout();baseline('element release')
   layout:Release();check(host._lycheeLayoutInputs==nil,'released layout removes parent input ownership');C.ReleaseContainer(outer)
  end
 end
end
for _,vertical in ipairs({false,true}) do
 for _,condition in ipairs({false,true}) do
  local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
  local outer=frame(nil,400,100);C.Container(outer,'metadata')
  local host=frame(outer,160,100);local child=frame(host,20,10)
  C.Element(host,'parent-padding',{classes=rule(condition,{padding=4})})
  local layout=(vertical and C.Column or C.Row)(host,{{frame=child,width=20,height=10}},{mode='flex',padding=10})
  layout:Layout();local x,y=position(child);check(x==10 and y==-10,'inactive parent padding keeps layout option')
  if condition then outer:SetWidth(600) else host:Disable();C.ApplyElement(host) end
  layout:Layout();x,y=position(child);check(x==4 and y==-4,'active parent padding applies')
  if condition then outer:SetWidth(400) else host:Enable();C.ApplyElement(host) end
  layout:Layout();x,y=position(child);check(x==10 and y==-10,'parent padding exit restores layout option')
  C.ReleaseElement(host);layout:Layout();x,y=position(child);check(x==10 and y==-10,'parent padding release preserves layout option')
  layout:Release();C.ReleaseContainer(outer)
 end
end
for _,vertical in ipairs({false,true}) do
 for _,alias in ipairs({false,true}) do
  local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
  local outer=frame(nil,400,100);C.Container(outer,'metadata')
  local host=frame(outer,160,100);local child=frame(host,20,10);local owner=alias and frame(outer,10,10) or child
  local layout=(vertical and C.Column or C.Row)(host,{{frame=child,width=20,height=10}},{mode='flex'});layout:Layout()
  C.Element(owner,'late-participation',{slots={root=owner,child=child},classes={conditions={{container='metadata',minWidth=500,base={[alias and 'child' or 'root']={participate=false}}}}}})
  outer:SetWidth(600);layout:Layout();check(#layout.active==0,'new conditional source can immediately exclude a formerly plain item')
  outer:SetWidth(400);layout:Layout();check(#layout.active==1,'excluded item still detects the condition that restores participation')
  check(child:IsShown(),'layout participation never changes native visibility')
  outer:SetWidth(600);layout:Layout();C.ReleaseElement(owner);layout:Layout()
  check(#layout.active==1,'released exclusion restores descriptor participation')
  layout:Release();check(host._lycheeLayoutInputs==nil,'excluded-item layout releases parent input');C.ReleaseContainer(outer)
 end
end
for _,alias in ipairs({false,true}) do
 local ui=LycheeUI:CreateContext({reducedMotion=true,elementDefaults={late={template=true,slotKinds={root='box',child='box'}}},
  elements={late={instances={bounded={conditions={{container='metadata',minWidth=500,base={[alias and 'child' or 'root']={maxWidth=50}}}}}}}}})
 local C=ui.C;local outer=frame(nil,400,100);C.Container(outer,'metadata')
 local host=frame(outer,160,100);local child=frame(host,100,10);local owner=alias and frame(outer,10,10) or child
 local row=C.Row(host,{{frame=child,width=100,height=10}},{mode='flex'});row:Layout()
 C.Element(owner,'late',{key='bounded',slots={root=owner,child=child}})
 row:Layout();check(child:GetWidth()==100,'late inactive maximum keeps original geometry')
 outer:SetWidth(600);row:Layout();check(child:GetWidth()==50,'late direct/alias condition invalidates a formerly plain declaration')
 C.RekeyElement(owner,'plain');row:Layout();check(child:GetWidth()==100,'replacing with no rules invalidates the removed binding target')
 C.ReleaseElement(owner);row:Release();check(host._lycheeLayoutInputs==nil,'late-binding layout releases its parent input')
 C.ReleaseContainer(outer)
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
 local host=frame(nil,160,100);local child=frame(host,20,10)
 C.Box(child,{minWidth=30,minHeight=20,align='center',padding=10,fit='cover'})
 C.Element(child,'explicit-baseline',{classes=rule(false,{minWidth=90,minHeight=40,align='end',padding=4,fit='contain'})})
 local baseline={minWidth=30,minHeight=20,align='center',padding=10,fit='cover'}
 for key,value in pairs(baseline) do check(C.LayoutValue(child,key)==value,'explicit initial baseline '..key) end
 child:Disable();C.ApplyElement(child)
 child:Enable();C.ApplyElement(child)
 for key,value in pairs(baseline) do check(C.LayoutValue(child,key)==value,'explicit restored baseline '..key) end
 C.ReleaseElement(child);C.ReleaseBox(child)
end
print('LycheeUI layout metadata restore: '..checks..' checks passed')
