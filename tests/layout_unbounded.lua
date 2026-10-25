-- Missing maximum constraints restore absence, never a user infinity.
-- Run from LycheeUI: lua tests/layout_unbounded.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={}
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('LayoutUnbounded',private) end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function frame(parent,w,h) local f=CreateFrame('Frame',nil,parent or UIParent);f:SetSize(w or 40,h or 30);f.GetStringWidth=false;f.GetStringHeight=false;return f end
local keys={'width','height','maxWidth','maxHeight'}
local function same(C,target,message)
 local out=C._ReadLayoutValues(target,{},keys,{})
 for _,key in ipairs(keys) do check(out[key]==C.LayoutValue(target,key),message..' scalar/projection '..key) end
end
for _,vertical in ipairs({false,true}) do
 for _,condition in ipairs({false,true}) do
  local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
  local outer=frame(nil,400,100);C.Container(outer,'unbounded');local host=frame(outer,300,100);local child=frame(host)
  local classes={base={root={width=40,height=30}}}
  if condition then classes.conditions={{container='unbounded',minWidth=500,base={root={maxWidth=20,maxHeight=15}}}}
  else classes.states={disabled={root={maxWidth=20,maxHeight=15}}} end
  C.Element(child,'limit',{classes=classes})
  local layout=(vertical and C.Column or C.Row)(host,{child},{mode='flex'})
  layout:Layout()
  check(child:GetWidth()==40 and child:GetHeight()==30,'inactive absent maxima preserve natural fixed geometry')
  check(C.LayoutValue(child,'maxWidth')==nil and C.LayoutValue(child,'maxHeight')==nil,'missing maxima stay absent')
  same(C,child,'inactive')
  if condition then outer:SetWidth(600) else child:Disable();C.ApplyElement(child) end
  layout:Layout();check(child:GetWidth()==20 and child:GetHeight()==15,'active maxima constrain both axes');same(C,child,'active')
  if condition then outer:SetWidth(400) else child:Enable();C.ApplyElement(child) end
  layout:Layout();check(child:GetWidth()==40 and child:GetHeight()==30,'max exit restores both unconstrained axes')
  check(C.LayoutValue(child,'maxWidth')==nil and C.LayoutValue(child,'maxHeight')==nil,'max exit clears internal restore metadata');same(C,child,'exit')
  C.ReleaseElement(child);layout:Layout();check(not child._lycheeBoxValues or child._lycheeBoxValues.maxWidth==nil and child._lycheeBoxValues.maxHeight==nil,'release keeps absent maxima absent')
  layout:Release();C.ReleaseContainer(outer)
 end
end
for _,vertical in ipairs({false,true}) do
 for _,condition in ipairs({false,true}) do
  local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
  local outer=frame(nil,400,100);C.Container(outer,'box-limit');local box=frame(outer);local child=frame(box)
  local classes
  if condition then classes={conditions={{container='box-limit',minWidth=500,base={root={maxWidth=20,maxHeight=15}}}}}
  else classes={states={disabled={root={maxWidth=20,maxHeight=15}}}} end
  local _,layout=C.Box(box,{layout=vertical and 'column' or 'row',width='content',height='content',items={{frame=child,width=40,height=30}},classes=classes})
  layout:Layout();check(box:GetWidth()==40 and box:GetHeight()==30,'content Box starts with absent inactive maxima');same(C,box,'Box inactive')
  if condition then outer:SetWidth(600) else box:Disable();C.ApplyElement(box) end
  layout:Layout();check(box:GetWidth()==20 and box:GetHeight()==15,'content Box applies active maxima');same(C,box,'Box active')
  if condition then outer:SetWidth(400) else box:Enable();C.ApplyElement(box) end
  layout:Layout();check(box:GetWidth()==40 and box:GetHeight()==30,'content Box restores absence after max exit');same(C,box,'Box exit')
  C.ReleaseBox(box);check(not box._lycheeBoxValues or box._lycheeBoxValues.maxWidth==nil and box._lycheeBoxValues.maxHeight==nil,'Box release does not retain internal infinities')
  C.ReleaseContainer(outer)
 end
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true,elementDefaults={row={template=true,slotKinds={root='box'}}},elements={row={instances={finite={base={root={maxWidth=70,maxHeight=60}},states={disabled={root={maxWidth=20,maxHeight=15}}}}}}}})
 local C=ui.C;local host=frame(nil,300,100)
 for _,instance in ipairs({false,true}) do
  local child=frame(host);local layout
  if instance then C.Element(child,'row',{key='finite'})
  else C.Box(child,{width=40,height=30,maxWidth=70,maxHeight=60});C.Element(child,'finite',{classes={states={disabled={root={maxWidth=20,maxHeight=15}}}}}) end
  layout=C.Row(host,{{frame=child,width=40,height=30}},{mode='flex'});layout:Layout()
  check(C.LayoutValue(child,'maxWidth')==70 and C.LayoutValue(child,'maxHeight')==60,'finite explicit/instance baseline is preserved')
  child:Disable();C.ApplyElement(child);layout:Layout();check(child:GetWidth()==20 and child:GetHeight()==15,'finite baseline can be temporarily narrowed')
  child:Enable();C.ApplyElement(child);layout:Layout()
  check(child:GetWidth()==40 and child:GetHeight()==30 and C.LayoutValue(child,'maxWidth')==70 and C.LayoutValue(child,'maxHeight')==60,'finite baseline restored after state exit');same(C,child,'finite restore')
  C.ReleaseElement(child);layout:Release();C.ReleaseBox(child)
 end
 for _,key in ipairs({'width','height','maxWidth','maxHeight'}) do
  local child=frame(host);local descriptor={frame=child,width=40,height=30};descriptor[key]=math.huge
  local layout=C.Row(host,{descriptor},{mode='flex'})
  check(not pcall(layout.Layout,layout),'explicit infinite descriptor '..key..' remains invalid');layout:Release()
  local root={[key]=math.huge}
  check(not pcall(C.Element,child,'invalid',{classes={base={root=root}}}),'explicit infinite style '..key..' remains invalid')
  local box=frame(host);local spec={layout='row',width='content',height='content',items={}};spec[key]=math.huge
  local ok,message=pcall(function() local _,l=C.Box(box,spec);l:Layout() end)
  check(not ok,'explicit infinite composed Box '..key..' remains invalid');C.ReleaseBox(box)
 end
end
print('LycheeUI unbounded layout: '..checks..' checks passed')
