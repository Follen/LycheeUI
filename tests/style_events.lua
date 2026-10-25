-- Run from LycheeUI: lua tests/style_events.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('StyleEvents',private) end
local ctx=private.LycheeUI:CreateContext({reducedMotion=true});local C=ctx.C
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Host() local f=CreateFrame('Frame',nil,UIParent);f:SetSize(100,40);return f end
local function Style(target)
 return C.Style(target,{states={hover={root={alpha=.5}},pressed={root={alpha=.25}}}})
end
local function Press(source) source:Fire('OnEnter');source:Fire('OnMouseDown') end
for _,split in ipairs({false,true}) do
 local source,target=Host(),Host();local style=Style(target)
 if split then style:Bind(source,{hover=true});style:Bind(source,{pressed=true}) else style:Bind(source,{hover=true,pressed=true}) end
 Press(source);Check(target:GetAlpha()==.25,'a bound pressed state remains above hover')
 local apply=style.Apply;local calls,values=0,{}
 function style:Apply(...) calls=calls+1;local result=apply(self,...);values[#values+1]=target:GetAlpha();return result end
 source:Fire('OnLeave')
 Check(calls==1,'one leave applies adjacent contributions once, including split Bind calls')
 Check(#values==1 and values[1]==1 and not style.active.hover and not style.active.pressed,'one leave clears hover and pressed together')
 style:Release()
end
-- Only adjacent entries may combine: a later split binding stays after another
-- controller, including when the middle controller has two adjacent entries.
do
 local source,aTarget,bTarget=Host(),Host(),Host();local a,b=Style(aTarget),Style(bTarget)
 a:Bind(source,{hover=true});b:Bind(source,{hover=true,pressed=true});a:Bind(source,{pressed=true});Press(source)
 local order={};local applyA,applyB=a.Apply,b.Apply
 function a:Apply(...) order[#order+1]='a';return applyA(self,...) end
 function b:Apply(...) order[#order+1]='b';return applyB(self,...) end
 source:Fire('OnLeave')
 Check(table.concat(order,',')=='a,b,a','interleaved controllers keep their binding order')
 Check(aTarget:GetAlpha()==1 and bTarget:GetAlpha()==1,'interleaved split bindings both reach their final states')
 a:Release();b:Release()
end
-- A callback may remove a later subscriber and add its replacement. The new
-- subscription must wait for the next delivery rather than join the old batch.
do
 local source,firstTarget,laterTarget=Host(),Host(),Host();local first,later=Style(firstTarget),Style(laterTarget)
 first:Bind(source,{hover=true,pressed=true});later:Bind(source,{hover=true,pressed=true});Press(source)
 local apply=first.Apply;local replaced=false;local replacement,calls
 function first:Apply(...)
  if not replaced then
   replaced=true;later:Release();replacement=Style(laterTarget);calls=0
   local original=replacement.Apply
   function replacement:Apply(...) calls=calls+1;return original(self,...) end
   replacement:Bind(source,{hover=true,pressed=true})
  end
  return apply(self,...)
 end
 source:Fire('OnLeave')
 Check(calls==0 and laterTarget:GetAlpha()==1,'a released later subscriber and its replacement do not consume the current event')
 Press(source);calls=0;source:Fire('OnLeave')
 Check(calls==1 and laterTarget:GetAlpha()==1,'a new subscription receives the next event once')
 first:Release();replacement:Release()
end
-- Nested events get independent snapshots even after the outer event consumes
-- both adjacent entries before calling Apply.
do
 local source,target=Host(),Host();local style=Style(target);style:Bind(source,{hover=true,pressed=true});Press(source)
 local apply=style.Apply;local inside=false;local calls=0
 function style:Apply(...)
  calls=calls+1
  if not inside then inside=true;source:Fire('OnLeave');inside=false end
  return apply(self,...)
 end
 source:Fire('OnLeave')
 Check(calls==2 and target:GetAlpha()==1,'outer and nested leave each apply exactly once')
 Check(next(source._lycheeFixedEvents.OnLeave.buffer)==nil,'nested delivery clears the reusable outer snapshot')
 local throw=true
 function style:Apply(...) if throw then throw=false;error('expected grouped event failure') end;return apply(self,...) end
 local ok,message=pcall(function() source:Fire('OnLeave') end)
 Check(not ok and tostring(message):find('expected grouped event failure',1,true),'grouped event errors propagate')
 Check(next(source._lycheeFixedEvents.OnLeave.buffer)==nil,'failed grouped delivery clears its snapshot')
 Press(source);source:Fire('OnLeave');Check(target:GetAlpha()==1,'a failed delivery does not block later state changes')
 style:Release()
end
-- A source can already have a permanent r40 dispatcher from another embedded
-- copy. Keep its entry protocol: it still applies twice, with correct end state.
do
 local source,target=Host(),Host();local state={entries={},buffer={}}
 source._lycheeFixedEvents={OnLeave=state}
 source:HookScript('OnLeave',function(control)
  local count=#state.entries
  for index=1,count do state.buffer[index]=state.entries[index] end
  for index=1,count do
   local entry=state.buffer[index];state.buffer[index]=nil
   local controller=entry.controller
   if controller and not controller.released then
    Check(entry.action=='state','new bindings preserve the existing r40 state-entry protocol')
    entry.owned[entry.name]=entry.value;controller:Apply(false)
   end
  end
 end)
 local style=Style(target);style:Bind(source,{hover=true,pressed=true});Press(source)
 local apply=style.Apply;local calls=0
 function style:Apply(...) calls=calls+1;return apply(self,...) end
 source:Fire('OnLeave')
 Check(calls==2 and target:GetAlpha()==1 and not style.active.hover and not style.active.pressed,'a previously installed r40 dispatcher retains correct state without claiming fewer calls')
 style:Release();Check(#state.entries==0 and next(state.buffer)==nil,'releasing a new controller also clears its older dispatcher subscriptions')
end
ctx:Hide()
print('LycheeUI grouped style events: '..checks..' checks passed')
