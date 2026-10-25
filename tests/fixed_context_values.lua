-- A layout can consume fixed rules without taking over their Context binding.
-- Optional arguments replace Styles.lua and Responsive.lua for red/green checks.
local S=dofile('tests/stubs.lua');S.Install()
local private={}
for _,name in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do
 local file=name=='Styles' and arg and arg[1] or name=='Responsive' and arg and arg[2] or name..'.lua'
 assert(loadfile(file))('FixedContextValues',private)
end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function frame(parent,width,height)
 local f=CreateFrame('Frame',nil,parent or UIParent);f:SetSize(width or 20,height or 16)
 f.GetStringWidth=false;f.GetStringHeight=false;return f
end
local a=LycheeUI:CreateContext({reducedMotion=true,themeDefaults={ownedWidth=80,ownedMax=90,ownedPadding=7,wideWidth=72}})
local b=LycheeUI:CreateContext({reducedMotion=true,themeDefaults={ownedWidth=160,ownedMax=180,ownedPadding=17,wideWidth=172}})
local host=frame(nil,300,100);local child=frame(host)
a.C.Element(child,'owned',{classes={base={root={width='ownedWidth',height=16,maxWidth='ownedMax'}},states={selected={root={width='wideWidth'}}}}})
local first=a.C.Row(host,{child},{mode='flex'});first:Layout()
local successor=b.C.Row(host,{child},{mode='flex'});successor:Layout()
check(child:GetWidth()==80,'foreign layout preserves the fixed-rule owner token')
check(child.styleController.context==a,'layout does not acquire the fixed binding')
check(b.C.FixedValue(child,'width')==80 and b.C.LayoutValue(child,'maxWidth')==90,'scalar reads use the winning owner Context')
local keys={'width','height','maxWidth','basis','align','manageHeight'}
local out=b.C._ReadLayoutValues(child,{},keys,{basis='25%',align='end',manageHeight=false})
check(out.width==80 and out.maxWidth==90 and out.height==16,'batch reads use the winning owner Context')
check(out.basis=='25%' and out.align=='end' and out.manageHeight==false,'descriptor fallback remains the consumer declaration')
a.C.SetElementState(child,'selected',true);successor:Layout()
check(child:GetWidth()==72,'foreign layout follows the owner state token')
a.C.SetElementState(child,'selected',false);successor:Layout();first:Release()
check(child:GetWidth()==80 and child._lycheeLayoutFields.width==successor,'old layout release preserves the successor')

-- Parent metadata is also owned by the style binding, not by the new layout.
a.C.Element(host,'host',{classes={base={root={padding='ownedPadding'}}}})
successor:Layout();local _,_,_,x=child:GetPoint()
check(x==7,'foreign parent padding token uses the parent fixed-rule owner')
a.C.Element(host,'host',{classes={base={root={padding={left='ownedPadding',top='ownedPadding'}}}}})
successor:Layout();local _,_,_,nestedX,nestedY=child:GetPoint()
check(nestedX==7 and nestedY==-7,'foreign fixed padding edges resolve in their binding Context')
a.C.ReleaseElement(host);if host.styleController then host.styleController:Release() end
a.C.Box(host,{padding={left='ownedPadding',top='ownedPadding'}})
successor:Layout();local _,_,_,boxX,boxY=child:GetPoint()
check(boxX==7 and boxY==-7,'foreign Box padding fallback resolves in its registration Context')
a.C.ReleaseBox(host)
successor:SetOptions({mode='flex',padding={left='ownedPadding',top='ownedPadding'}});successor:Layout()
local _,_,_,optionX,optionY=child:GetPoint()
check(optionX==17 and optionY==-17,'explicit layout padding remains in the consumer Context')

-- Dirty condition reads enqueue Apply in the owning Context only.
local ancestor=frame(nil,100,100);a.C.Container(ancestor,'owner-container')
local conditional=frame(ancestor)
a.C.Element(conditional,'conditional',{classes={base={root={width='ownedWidth'}},conditions={{container='owner-container',minWidth=90,base={root={width='wideWidth'}}}}}})
local queueA,queueB=0,0;local originalA,originalB=a._QueueLayout,b._QueueLayout
function a:_QueueLayout(job,reason) if job==conditional.styleController then queueA=queueA+1 end;return originalA(self,job,reason) end
function b:_QueueLayout(job,reason) if job==conditional.styleController then queueB=queueB+1 end;return originalB(self,job,reason) end
ancestor:SetWidth(80);queueA,queueB=0,0
check(b.C.LayoutValue(conditional,'width')==80,'foreign read refreshes the owner condition')
check(queueA==1 and queueB==0,'condition Apply is queued only in the owner Context')
a:FlushLayouts();ancestor:SetWidth(100);queueA,queueB=0,0
check(b.C._ReadLayoutValues(conditional,{},keys,{}).width==72,'foreign batch refreshes the condition')
check(queueA==1 and queueB==0,'batch condition Apply is queued only in the owner Context')
a._QueueLayout,b._QueueLayout=originalA,originalB

-- Alias winners may belong to different Contexts for different properties.
local aliasHost=frame(nil);local aliased=frame(host)
a.C.Element(aliasHost,'alias',{slots={root=aliasHost,child=aliased},classes={base={child={width='ownedWidth',height=19}}}})
b.C.Element(aliased,'direct',{classes={base={root={maxWidth='ownedMax'}}}})
out=b.C._ReadLayoutValues(aliased,{},keys,{})
check(out.width==80 and out.maxWidth==180 and out.height==19,'each property resolves using its winning record Context')

-- An exception cannot leave a foreign winner in reusable projection scratch.
local resolve=a.ResolveValue;local fail=true
function a:ResolveValue(value) if fail and value=='ownedWidth' then error('foreign resolver failure') end;return resolve(self,value) end
check(not pcall(b.C._ReadLayoutValues,aliased,{},keys,{}),'foreign resolution failure propagates')
local own=frame(host);b.C.Element(own,'own',{classes={base={root={width='ownedWidth'}}}})
check(b.C._ReadLayoutValues(own,{},keys,{}).width==160,'scratch is clear after the foreign resolution error')
fail=false;check(b.C._ReadLayoutValues(aliased,{},keys,{}).width==80,'foreign resolution can retry')
a.ResolveValue=resolve

successor:Release()
for _,target in ipairs({child,host,conditional,aliasHost}) do a.C.ReleaseElement(target);if target.styleController then target.styleController:Release() end end
for _,target in ipairs({aliased,own}) do b.C.ReleaseElement(target);if target.styleController then target.styleController:Release() end end
a.C.ReleaseContainer(ancestor);a:Hide();b:Hide()
print('LycheeUI fixed Context values: '..checks..' checks passed')
