-- Run from LycheeUI: lua tests/style_release.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('StyleRelease',private) end
local Library=private.LycheeUI;local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
-- Native HookScript registrations survive SetScript, unlike the general stub's
-- convenient chained-script implementation. Model that distinction locally.
local function NativeEvents(frame)
 local hooks={};frame.hookCount=0
 function frame:HookScript(event,callback)
  local list=hooks[event] or {};hooks[event]=list;list[#list+1]=callback;self.hookCount=self.hookCount+1
 end
 function frame:Fire(event,...)
  local script=self:GetScript(event);if script then script(self,...) end
  local list=hooks[event] or {};local count=#list
  for index=1,count do list[index](self,...) end
 end
 function frame:SetFocus() self.focus=true;self:Fire('OnEditFocusGained') end
 function frame:ClearFocus() if self.focus then self.focus=false;self:Fire('OnEditFocusLost') end end
 function frame:SetEnabled(value) local changed=self.enabled~=value;self.enabled=value;if changed then self:Fire(value and 'OnEnable' or 'OnDisable') end end
 function frame:Hide() local shown=self.shown;self.shown=false;if shown then self:Fire('OnHide') end end
 function frame:Show() local shown=self.shown;self.shown=true;if not shown then self:Fire('OnShow') end end
 return frame
end
local function Retained(weak)
 collectgarbage('collect');local count=0;for _ in pairs(weak) do count=count+1 end;return count
end
local ctx=Library:CreateContext({reducedMotion=true});local C=ctx.C
local host=NativeEvents(CreateFrame('Button',nil,UIParent));host:SetSize(100,40)
local weak=setmetatable({},{__mode='k'});local hookMaximum
for round=1,100 do
 local controller=C.Style(host,{states={hover={root={alpha=.5}}}});weak[controller]=true
 controller:Bind(host,{hover=true});host:Fire('OnEnter');check(host:GetAlpha()==.5,'a rebound controller receives hover')
 controller:Release();check(host:GetAlpha()==1 and next(controller.sources)==nil and (not controller.bindings or next(controller.bindings)==nil),'release restores appearance and removes all sources')
 if round==1 then hookMaximum=host.hookCount end
 check(host.hookCount==hookMaximum,'repeated binding reuses native event hooks')
end
check(Retained(weak)==0,'released controllers are collectible while the native host remains alive')
local before=host:GetAlpha();host:Fire('OnEnter');host:Fire('OnDisable');check(host:GetAlpha()==before,'released event subscriptions do no work')

-- Multiple sources OR states; checked, disabled and source-hide retain their
-- established state semantics while one event may have multiple contributions.
local target=NativeEvents(CreateFrame('Button',nil,UIParent));target:SetSize(100,40)
local one=NativeEvents(CreateFrame('CheckButton',nil,UIParent));local two=NativeEvents(CreateFrame('Button',nil,UIParent))
local style=C.Style(target,{states={hover={root={alpha=.5}},pressed={root={alpha=.4}},checked={root={width=120}},disabled={root={alpha=.2}}}})
style:Bind(one,{hover=true,pressed=true,checked=true});style:Bind(two,{hover=true});style:Bind(target,{hover=true})
local hooks=one.hookCount;style:Bind(one,{hover=true,pressed=true,checked=true});check(one.hookCount==hooks,'duplicate Bind is idempotent')
one:Fire('OnEnter');two:Fire('OnEnter');one:Fire('OnLeave');check(target:GetAlpha()==.5,'another source retains its hover contribution')
two:Hide();check(target:GetAlpha()==1,'hiding a source clears that source only')
one:Fire('OnEnter');one:Fire('OnMouseDown');check(target:GetAlpha()==.4,'pressed state overrides hover')
one:Fire('OnLeave');check(target:GetAlpha()==1,'one leave event clears both hover and pressed contributions')
one:SetChecked(true);one:Fire('OnClick');check(target:GetWidth()==120,'checked state follows the source native value')
target:Fire('OnEnter');target:SetEnabled(false);check(target:GetAlpha()==.2,'disabled state wins and clears transient source states')
target:SetEnabled(true);check(target:GetAlpha()==1,'enabling does not resurrect hover')
style:Release();one:Fire('OnClick');check(target:GetWidth()==100,'checked hooks stop after release')

-- Separate controllers and contexts can share one source. Native business
-- scripts and foreign hooks retain their normal invocation and remain writable.
local other=Library:CreateContext({reducedMotion=true})
local source=NativeEvents(CreateFrame('Button',nil,UIParent));local order={}
source:SetScript('OnEnter',function() order[#order+1]='business' end)
source:HookScript('OnEnter',function() order[#order+1]='foreign' end)
local left=CreateFrame('Frame',nil,UIParent);left:SetSize(10,10)
local right=CreateFrame('Frame',nil,UIParent);right:SetSize(10,10)
local a=C.Style(left,{states={hover={root={alpha=.5}}}});local b=other.C.Style(right,{states={hover={root={alpha=.7}}}})
local applyA,applyB=a.Apply,b.Apply
function a:Apply(...) order[#order+1]='first';return applyA(self,...) end
function b:Apply(...) order[#order+1]='second';return applyB(self,...) end
a:Bind(source,{hover=true});b:Bind(source,{hover=true});source:Fire('OnEnter')
check(table.concat(order,',')=='business,foreign,first,second','shared-source callbacks preserve Bind order after native scripts and prior foreign hooks')
check(left:GetAlpha()==.5 and right:GetAlpha()==.7,'cross-context subscribers receive the event')
a:Release();order={};source:SetScript('OnEnter',function() order[#order+1]='replacement' end);source:Fire('OnEnter')
check(table.concat(order,',')=='replacement,foreign,second','external SetScript preserves the fixed-style hook and the remaining subscriber')
b:Release()

-- Removing a later subscriber during dispatch suppresses it. Rebinding adds a
-- fresh subscriber which starts on the next event, even on the same source.
local changing=NativeEvents(CreateFrame('Button',nil,UIParent));local p=CreateFrame('Frame',nil,UIParent);local q=CreateFrame('Frame',nil,UIParent)
p:SetSize(10,10);q:SetSize(10,10)
local first=C.Style(p,{states={hover={root={alpha=.3}}}});local second=C.Style(q,{states={hover={root={alpha=.6}}}})
first:Bind(changing,{hover=true});second:Bind(changing,{hover=true})
local firstApply=first.Apply;local replaced,newCalls=false,0;local replacement
function first:Apply(...)
 if not replaced then
  replaced=true;second:Release();second=nil
  replacement=C.Style(q,{states={hover={root={alpha=.8}}}})
  local apply=replacement.Apply
  function replacement:Apply(...) newCalls=newCalls+1;return apply(self,...) end
  replacement:Bind(changing,{hover=true})
 end
 return firstApply(self,...)
end
changing:Fire('OnEnter');check(q:GetAlpha()==1 and newCalls==0,'new subscriptions do not consume the event that created them')
changing:Fire('OnEnter');check(q:GetAlpha()==.8 and newCalls==1,'the next event reaches the replacement subscription')
first:Release();replacement:Release()

-- Nested delivery uses an independent event snapshot. A callback error clears
-- temporary dispatch references and still allows a later normal event.
local recursive=NativeEvents(CreateFrame('Button',nil,UIParent));local r=CreateFrame('Frame',nil,UIParent);r:SetSize(10,10)
local nested=C.Style(r,{states={hover={root={alpha=.9}}}});nested:Bind(recursive,{hover=true})
local nestedApply=nested.Apply;local inside=false;local calls=0
function nested:Apply(...)
 calls=calls+1
 if not inside then inside=true;recursive:Fire('OnEnter');inside=false end
 return nestedApply(self,...)
end
recursive:Fire('OnEnter');check(calls==2 and r:GetAlpha()==.9,'nested delivery keeps the outer and inner event snapshots independent')
local throw=true
function nested:Apply(...) if throw then throw=false;error('expected style callback error') end;return nestedApply(self,...) end
local ok,message=pcall(function() recursive:Fire('OnEnter') end)
check(not ok and tostring(message):find('expected style callback error',1,true),'callback failures propagate to the caller')
recursive:Fire('OnLeave');check(r:GetAlpha()==1,'a failed dispatch does not block later events')
local failedWeak=setmetatable({[nested]=true},{__mode='k'});nested:Release();nested=nil
check(Retained(failedWeak)==0,'failed dispatch snapshots do not retain a released controller')

-- Real NativeInput/Element ownership path, including foreign loss. Retained
-- Frames and a fixed startup focus rule must not retain departed controllers.
local native=Library:CreateContext({reducedMotion=true,elementDefaults={input={slotKinds={root='text'}}},elements={input={states={focus={root={alpha=.5}}}}}})
local home=CreateFrame('Frame',nil,UIParent);local foreign=CreateFrame('Frame',nil,UIParent)
local box=NativeEvents(CreateFrame('EditBox',nil,home));box:SetSize(180,24)
local shell=native.C.Field(UIParent,300,44);local lost=0;local nativeWeak=setmetatable({},{__mode='k'});local nativeHooks
for round=1,100 do
 local lease=native.C.NativeInput(shell,box,{onLost=function(control) lost=lost+1;native.C.ReleaseElement(control.box) end})
 native.C.Element(box,'input',{scope='native',owner=lease});nativeWeak[box.styleController]=true
 box:SetFocus();check(box:GetAlpha()==.5 and lease:IsOwned(),'native focus styling remains functional after reacquisition')
 box:SetParent(foreign);lease:Release();box:ClearFocus();box:SetParent(home)
 check(not lease.active and not native.elements[box] and next(native.nativeControls)==nil and #native.inputs==0,'foreign release clears the lease and element registrations')
 if round==1 then nativeHooks=box.hookCount end
 check(box.hookCount==nativeHooks,'native reacquisition keeps its hook count constant')
end
check(lost==100 and Retained(nativeWeak)==0,'foreign NativeInput loss releases all old style controllers')
local lostNativeHooks=nativeHooks
-- Ordinary release keeps its reusable controller and subscription at high water.
for round=1,100 do
 local lease=native.C.NativeInput(shell,box)
 native.C.Element(box,'input',{scope='native',owner=lease});box:SetFocus()
 native.C.ReleaseElement(box);lease:Release()
 if round==1 then nativeHooks=box.hookCount end
 check(box.hookCount==nativeHooks,'ordinary native release reuses its style controller hooks')
end

-- An embedded upgrade preserves the source's first permanent dispatcher while
-- new controllers have distinct module-local empty tables. The older callback
-- must never write its state-clearing fields into the newer shared empty.
local upgrading=NativeEvents(CreateFrame('Button',nil,UIParent));upgrading:SetSize(100,40)
local oldStyle=C.Style(upgrading,{states={hover={root={alpha=.5}}}})
local oldEmpty=oldStyle.states;oldStyle:Bind(upgrading,{hover=true});oldStyle:Release()
local upgradeHooks=upgrading.hookCount
local coreFile=assert(io.open('Core.lua'));local coreSource=coreFile:read('*a');coreFile:close()
local nextRevision=Library.version+1
coreSource=coreSource:gsub('local REVISION=%d+','local REVISION='..nextRevision,1)
local upgradedPrivate={};assert(loadstring(coreSource,'@SimulatedUpgradeCore'))('StyleReleaseUpgrade',upgradedPrivate)
for _,file in ipairs({'Theme','Motion','Styles','Components','Layouts','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('StyleReleaseUpgrade',upgradedPrivate) end
local upgraded=upgradedPrivate.LycheeUI:CreateContext({reducedMotion=true})
local upgradedStyle=upgraded.C.Style(upgrading,{states={hover={root={alpha=.7}}}})
local upgradedEmpty=upgradedStyle.states
check(oldEmpty~=upgradedEmpty and next(oldEmpty)==nil and next(upgradedEmpty)==nil,'simulated embedded upgrade creates independent unmodified empty tables')
upgradedStyle:Bind(upgrading,{hover=true});upgrading:SetEnabled(false);upgrading:SetEnabled(true)
check(next(oldEmpty)==nil and next(upgradedEmpty)==nil,'the old dispatcher does not mutate either revision shared empty table')
check(upgrading.hookCount==upgradeHooks,'a newer embedded revision reuses the existing source dispatcher')
upgrading:Fire('OnEnter');check(upgrading:GetAlpha()==.7,'the old dispatcher delivers events to a newer controller')
upgradedStyle:SetState('pressed',true);upgradedStyle:SetState('hover',true);upgrading:SetEnabled(false);upgrading:SetEnabled(true)
check(not upgradedStyle.states.hover and not upgradedStyle.states.pressed and upgrading:GetAlpha()==1,'the old dispatcher still clears explicitly set transient states after an upgrade')
upgradedStyle:Release()
-- Old contexts remain usable after installing a higher embedded revision.
local restored=C.Style(upgrading,{states={hover={root={alpha=.5}}}});restored:Bind(upgrading,{hover=true})
upgrading:SetEnabled(false);upgrading:SetEnabled(true);upgrading:Fire('OnEnter')
check(next(oldEmpty)==nil and next(upgradedEmpty)==nil and upgrading:GetAlpha()==.5,'retained older contexts keep working without shared-table pollution')
restored:Release();upgraded:Hide()
ctx:Hide();other:Hide();native:Hide()
print('LycheeUI style release: '..checks..' checks passed; plain native hooks='..hookMaximum..', lost native hooks='..lostNativeHooks..', ordinary native hooks='..nativeHooks)
