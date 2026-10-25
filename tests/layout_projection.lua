-- Per-pass geometry projection must agree with the public scalar reads.
-- Run from LycheeUI: lua tests/layout_projection.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={}
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('LayoutProjection',private) end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local ui=LycheeUI:CreateContext({reducedMotion=true,themeDefaults={projectionWidth=73}});local C=ui.C
local keys={'width','height','minWidth','maxWidth','minHeight','maxHeight','basis','grow','shrink','align','gapAfter','manageWidth','manageHeight','managePoints','participate','reserve'}
local function frame(parent,w,h) local f=CreateFrame('Frame',nil,parent or UIParent);f:SetSize(w or 24,h or 12);f.GetStringHeight=false;f.GetStringWidth=false;return f end
local function equivalent(target,item,message)
 local out={};item=item or {};C._ReadLayoutValues(target,out,keys,item)
 local box=target._lycheeBoxValues or {}
 for _,key in ipairs(keys) do local fallback=item[key];if fallback==nil then fallback=box[key] end
  local value=C.LayoutValue(target,key,fallback)
  check(out[key]==value,message..' '..key..': '..tostring(out[key])..' ~= '..tostring(value))
 end
 return out
end
local ancestor=frame(nil,600,100);C.Container(ancestor,'projection-container')
local parent=frame(ancestor,300,80);local child=frame(parent)
local slot=C.Element(parent,'slot',{slots={root=parent,child=child},classes={base={child={width=31,height=14,minWidth=9,grow=1}},conditions={{container='projection-container',minWidth=500,base={child={width=51,basis='25%',manageHeight=false}},states={selected={child={width=61}}}}}}})
equivalent(child,{width=17,height=11},'alias conditional values')
check(C._ReadLayoutValues(child,{},keys,{}).width==51,'alias projected condition width')
local direct=C.Element(child,'direct',{classes={base={root={height=18}},states={selected={root={width=71,minWidth=13}},disabled={root={width=81}}},variants={wide={base={root={height=28}}}}}})
equivalent(child,{width=17,height=11},'inactive direct property owns its declaration union')
check(C._ReadLayoutValues(child,{},keys,{width=17}).width==17,'inactive direct winner falls back to descriptor rather than alias')
C.SetElementState(child,'selected',true);equivalent(child,{},'selected direct values')
child.styleController:SetVariant('wide');equivalent(child,{},'variant values');check(C._ReadLayoutValues(child,{},keys,{}).height==28,'variant projected height')
child:Disable();child.styleController:Apply(true);equivalent(child,{},'native disabled observed through Apply')
check(C._ReadLayoutValues(child,{},keys,{}).width==81,'disabled projection follows documented Apply observation')
child:Enable();child.styleController:Apply(true);C.SetElementState(child,'selected',false)
C.ReleaseElement(child);equivalent(child,{},'direct release reveals alias')
check(C._ReadLayoutValues(child,{},keys,{}).width==51,'released direct contribution reveals live alias')
ancestor:SetWidth(400)
local controller=parent.styleController;ui:_RefreshConditions(controller)
check(not controller._conditionDirty and controller._conditionApplyNeeded,'condition snapshot may be fresh before native Apply')
equivalent(child,{},'fresh alias condition before Apply')
check(C._ReadLayoutValues(child,{},keys,{}).width==31,'projection reads fresh matches with no dirty flag')
ancestor:SetWidth(600);equivalent(child,{},'dirty ancestor alias refresh')
check(C._ReadLayoutValues(child,{},keys,{}).width==51,'alias controller refreshed by projected read')

-- All fallback fields, including explicit false and Box constraint precedence.
local boxed=frame(parent);C.Box(boxed,{width='fill',height=19,minWidth=12,manageHeight=false,reserve=true})
equivalent(boxed,{width=22,minWidth=2,manageHeight=true,reserve=false},'Box fallback precedence')
C.Box(boxed,{width=23,height=20});equivalent(boxed,{minWidth=2},'Box replacement drops previous declarations')
C.ReleaseBox(boxed);equivalent(boxed,{minWidth=2},'Box release')

local checked=frame(parent);C.Element(checked,'checked',{classes={base={root={width=40,height=12,maxWidth=100}},states={checked={root={minWidth=50}},disabled={root={maxWidth=55}}}}})
local source=frame(parent);checked.styleController:Bind(source,{checked=true})
source:SetChecked(true);source:Fire('OnClick');equivalent(checked,{},'bound native checked event')
local checkedLayout=C.Row(parent,{checked},{mode='flex'});checkedLayout:Layout()
check(checked:GetWidth()==50,'checked constraint participates in layout even when native Apply did not size the axis')
source:SetChecked(false);source:Fire('OnClick');checkedLayout:Layout();check(checked:GetWidth()==40,'bound checked exit recomputes the next projection')
checkedLayout:Release();C.ReleaseElement(checked);checked.styleController:Release()

do
 local ctx=LycheeUI:CreateContext({reducedMotion=true,elementDefaults={row={template=true,slotKinds={root='box'}}},elements={row={instances={one={base={root={width=67}}},two={base={root={width=87}}}}}}})
 local target=frame();local api=ctx.C;api.Element(target,'row',{key='one'})
 check(api._ReadLayoutValues(target,{},keys,{}).width==67,'initial instance contribution')
 api.RekeyElement(target,'two');check(api._ReadLayoutValues(target,{},keys,{}).width==87,'rekey replaces winning projection source')
 api.ReleaseElement(target)
end

-- Rules introduced after initial declaration compilation must reach both paths.
local late=frame(parent);local layout=C.Row(parent,{{frame=late,width=24,height=12}},{mode='flex'})
layout:Layout();C.Element(late,'late',{classes='w-44 h-16'});layout:Layout()
check(late:GetWidth()==44 and late:GetHeight()==16,'late style invalidates a previously plain compiled item')
C.Element(late,'late',{classes={base={root={width=54,height=17}}}});parent:SetWidth(360);layout:Layout()
check(late:GetWidth()==54 and late:GetHeight()==17,'replacement declarations are observed on width reflow')
C.ReleaseElement(late);layout:Layout();check(late:GetWidth()==24 and late:GetHeight()==12,'release restores descriptor geometry with the physical record alive')

-- Nested token resolution gets independent scratch; failed token resolution
-- cannot leave a winning value/priority in a later call or its retry.
local token=frame(parent);C.Element(token,'token',{classes={base={root={width='projectionWidth',height=15}}}})
local other=frame(parent);C.Element(other,'other',{classes={base={root={width=29,height=13}}}})
local resolve=ui.ResolveValue;local nested,fail=false,false
function ui:ResolveValue(value)
 if value=='projectionWidth' then
  if fail then error('projection token failure') end
  if not nested then nested=true;local result=C._ReadLayoutValues(other,{},keys,{});check(result.width==29 and result.height==13,'nested projection remains independent');nested=false end
 end
 return resolve(self,value)
end
local result=C._ReadLayoutValues(token,{},keys,{});check(result.width==73 and result.height==15,'outer projection survives nested resolution')
fail=true;check(not pcall(C._ReadLayoutValues,token,{},keys,{}),'resolver failure is reported')
equivalent(other,{},'scratch cleared after resolver failure');fail=false
result=C._ReadLayoutValues(token,{},keys,{});check(result.width==73,'failed projection retries without stale scratch')
ui.ResolveValue=resolve

-- A released winning controller must collect even while native target/layout
-- records remain reachable. Metadata hints must not retain the old owner.
local weak=setmetatable({},{__mode='v'})
do local owner=frame(ancestor);local target=frame(parent)
 C.Element(owner,'collect',{slots={root=owner,child=target},classes={base={child={width=37,height=13}}}})
 local l=C.Row(parent,{target},{mode='flex'});l:Layout();weak[1]=owner.styleController
 C.ReleaseElement(owner);owner.styleController:Release();owner=nil;parent:SetWidth(301);l:Layout()
 collectgarbage('collect');collectgarbage('collect')
 check(weak[1]==nil,'released alias controller is not retained by record or projection scratch');l:Release()
end
layout:Release();C.ReleaseElement(token);C.ReleaseElement(other);C.ReleaseElement(parent);C.ReleaseContainer(ancestor)
print('LycheeUI layout projection: '..checks..' checks passed')
