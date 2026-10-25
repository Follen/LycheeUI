-- Run from LycheeUI: lua tests/flex_layouts.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={}
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('FlexLayouts',private) end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b) return math.abs(a-b)<.00001 end
local ctx=LycheeUI:CreateContext({reducedMotion=true});local C=ctx.C
local parent=CreateFrame('Frame',nil,UIParent);parent:SetSize(300,100)
local function frame(w,h,p)
 local f=CreateFrame('Frame',nil,p or parent);f:SetSize(w or 20,h or 10)
 -- Real Frames have no FontString measurement API. Keep this test correction
 -- local instead of extending the shared stub's historical surface.
 f.GetStringWidth=false;f.GetStringHeight=false
 f.GetWidth=function(self) return self.w end;f.GetHeight=function(self) return self.h end
 return f
end
local function row(items,options)
 options=options or {};options.mode='flex';return C.Row(parent,items,options)
end
check(LycheeUI.layoutModes.flex,'enhanced mode advertises capability')
do
 local a,b,c=frame(),frame(),frame()
 local l=row({{frame=a,width=20,grow=1,maxWidth=30},{frame=b,width=20,grow=1,maxWidth=80},{frame=c,width=20,grow=1}},{width=210,height=30})
 l:Layout();check(a:GetWidth()==30 and b:GetWidth()==80 and c:GetWidth()==100,'growth redistributes after multiple max freezes')
 l:SetItems({{frame=a,width=100,shrink=1,minWidth=90},{frame=b,width=100,shrink=2,minWidth=50},{frame=c,width=100,shrink=1,minWidth=0}})
 l:SetOptions({width=180});l:Layout()
 check(a:GetWidth()==90 and b:GetWidth()==50 and c:GetWidth()==40,'weighted shrink redistributes after multiple min freezes')
 l:SetItems({{frame=a,width=40,minWidth=50,maxWidth=10},{frame=b,width=40,minWidth=30}}):SetOptions({width=20});l:Layout()
 check(a:GetWidth()==50 and b:GetWidth()==40 and l.overflow and l.overflowWidth==70,'min beats conflicting max and shortage reports overflow')
 l:Release()
end
do
 local a,b=frame(),frame()
 local l=row({{frame=a,width='50%'},{frame=b,width='25%'}},{width=200,height=30,gap=10})
 l:Layout();check(a:GetWidth()==100 and b:GetWidth()==50,'percent resolves determined parent axis')
 l:SetOptions({width='content'});local ok,message=pcall(l.Layout,l)
 check(not ok and message:find('percentage depends on content axis') and a:GetWidth()==100,'content percentage dependency fails before native writes')
 l:SetItems({{frame=a,width='fill'}});check(not pcall(l.Layout,l),'content fill dependency fails explicitly')
 l:Release()
 local col=C.Column(parent,{{frame=a,height='50%'}},{mode='flex',width=80,height='content'})
 check(not pcall(col.Layout,col),'column content height never falls back to determined width')
 col:Release()
end
do
 local a,b,c=frame(),frame(),frame()
 local l=row({{frame=a,width=60,height=10,grow=1},{frame=b,width=60,height=20,grow=1},{frame=c,width=60,height=15,grow=1}},{width=130,height='content',gap=5,lineGap=7,flowWrap=true})
 local w,h=l:Layout()
 check(near(a:GetWidth(),62.5) and near(b:GetWidth(),62.5) and c:GetWidth()==130,'wrap distributes each line independently')
 check(w==130 and h==42 and select(5,c:GetPoint())==-27,'wrap measures line cross sizes and line gap')
 l:Release()
 local l2=C.Column(parent,{{frame=a,width=10,height=60},{frame=b,width=20,height=60},{frame=c,width=15,height=60}},{mode='flex',width='content',height=130,gap=5,lineGap=7,flowWrap=true})
 w,h=l2:Layout();check(w==42 and h==125 and select(4,c:GetPoint())==27,'column wrapping uses physical cross sizes')
 l2:Release()
end
do
 local a,b,c=frame(20,10),frame(30,10),frame(40,10);b:Hide()
 local l=row({{frame=a},{frame=b},{frame=c,participate=false}},{width='content',height='content',gap=4})
 l:Layout();check(l.contentWidth==20 and l.records[c]==nil and not b._lycheeLayoutOwner,'hidden and manually excluded objects have no placement')
 l:SetItems({a,{frame=b,reserve=true},{frame=c,participate=false}});l:Layout()
 check(l.contentWidth==54 and not b:IsShown() and b._lycheeLayoutOwner==l,'reserve keeps hidden geometry without showing it')
 a:ClearAllPoints();a:SetPoint('CENTER',parent,'CENTER',9,8)
 l:SetItems({{frame=a,width=90,height=90,manageWidth=false,manageHeight=false,managePoints=false},b});l:Layout()
 check(a:GetWidth()==20 and a:GetHeight()==10 and a:GetPoint()=='CENTER' and not a._lycheeLayoutOwner,'manual fields read native geometry and preserve anchors')
 a:SetWidth(42);l:Invalidate('manual resize');l:Layout();check(l.contentWidth==42,'manual native dimensions become current solver input')
 l:Release()
end
do
 local a=frame(20,10);a:SetScale(2)
 local b=frame(20,10)
 local l=row({a,b},{width='content',height='content',gap=5})
 l:Layout();check(l.contentWidth==65 and a:GetWidth()==20 and select(4,b:GetPoint())==45,'different effective scales use parent units without native size changes')
 l:SetItems({b,a});l:Layout();check(near(select(4,a:GetPoint()),12.5),'points convert from parent units into child effective scale')
 l:Release()
 local previous=GetPhysicalScreenSize;GetPhysicalScreenSize=function() return 1920,1080 end
 local c,d=frame(),frame();l=row({{frame=c,width=1.1},{frame=d,width=1.1}},{width=10,height=10})
 l:Layout();local x=select(4,d:GetPoint());check(near(c:GetWidth(),x) and near(d:GetWidth()+x,3*768/1080),'pixel aligned cumulative boundaries share adjacent edge')
 l:Release();GetPhysicalScreenSize=previous
end
do
 local label=C.Text(parent,'A sufficiently long wrapped text string','label');label:SetWordWrap(true);label:SetSize(200,20)
 local l=row({{frame=label,width=70,height='content'}},{width=70,height='content'})
 local oldW,oldH=label:GetWidth(),label:GetHeight();local oldPoint=label:GetNumPoints()
 local w,h=l:Measure();check(w==70 and h>20 and label:GetWidth()==oldW and label:GetHeight()==oldH and label:GetNumPoints()==oldPoint and not label._lycheeLayoutOwner,'wrapped measure uses probe and preserves all native geometry')
 l:Layout();check(label:GetWidth()==70 and label:GetHeight()==h,'commit assigns wrapped height at final width')
 local natural=label.GetUnboundedStringWidth;local reads=0;label.GetUnboundedStringWidth=function(self) reads=reads+1;return natural(self) end
 local writes=0
 for _,method in ipairs({'SetWidth','SetHeight','SetPoint','ClearAllPoints'}) do local original=label[method];label[method]=function(self,...) writes=writes+1;return original(self,...) end end
 local r=l.records[label];local line=l.lines[1];local before=collectgarbage('count');collectgarbage('stop')
 for _=1,1000 do l:Layout() end
 local growth=collectgarbage('count')-before;collectgarbage('restart')
 check(reads==0 and writes==0 and l.records[label]==r and l.lines[1]==line,'stable layout reuses records with no measurement or geometry writes')
 check(growth<1,'stable layout allocates no per-call Lua table or closure')
 l:Release()
end
do
 local a,b=frame(),frame();local l=row({a},{width=100,height=30});l:Layout()
 local weak=setmetatable({},{__mode='v'});local descriptor={frame=a,width=25};weak[1]=descriptor;l:SetItems({descriptor});l:Layout();descriptor=nil
 l:SetItems({b});collectgarbage('collect')
 check(weak[1]==nil and not l.records[a] and not a._lycheeLayoutOwner,'SetItems immediately drops unrelated descriptors records and ownership')
 l:Layout();local newer=row({b},{width=50,height=20,x=7});newer:Layout();local x=select(4,b:GetPoint())
 l:Release();check(b._lycheeLayoutOwner==newer and select(4,b:GetPoint())==x,'old release preserves new owner and final geometry')
 newer:Release();check(not b._lycheeLayoutOwner and not b._lycheeLayoutFields and select(4,b:GetPoint())==x,'release clears own fields and leaves native geometry')
end
do
 local a=frame();local l=row({{frame=a,width=60}},{width=100,height=30})
 local setter=a.SetWidth;local fail=true;a.SetWidth=function(self,n) if fail then fail=false;error('setter failed') end;return setter(self,n) end
 check(not pcall(l.Layout,l) and l.dirty,'failed native setter retains dirty retry state')
 l:Layout();check(a:GetWidth()==60 and not l.dirty,'later layout retries failed geometry')
 l:Release()
 local calls=0;local l2;l2=row({a},{width=100,height=30,onLayout=function(self) calls=calls+1;if calls==1 then self:Layout() end end})
 l2:Layout();check(calls==1 and l2.dirty,'callback reentry leaves one subsequent batch')
 l2:Layout();check(calls==2 and not l2.dirty,'subsequent batch completes without recursive callbacks')
 l2:SetOptions({onLayout=function(self) self:Release() end});l2:Layout();check(l2.released and not a._lycheeLayoutOwner,'callback may release its layout safely')
end
do
 local holder=frame(120,40);local a,b=frame(20,10,holder),frame(30,10,holder);local native=#S.nodes
 local target,l=C.Box(holder,{width=120,height=40,layout='row',items={a,b},gap=5})
 check(target==holder and l.mode=='flex' and #S.nodes==native and select(4,b:GetPoint())==25,'Box returns original target plus common flex controller without proxy frames')
 l:Release();C.Box(holder,{width=60});check(not holder._lycheeBoxValues and not holder._lycheeBoxApply and not ctx.boxes[holder],'fixed Box retains no empty composition metadata or fit registration')
end
do
 local a,b=frame(),frame();local calls=0
 local l=row({{frame=a,width=80}},{width=120,height=30,onLayout=function(self) calls=calls+1;self:Layout() end})
 l:PrepareLayout();check(a:GetWidth()==20 and not a._lycheeLayoutOwner,'preparation preserves target geometry and ownership')
 l:CommitLayout(true);check(a:GetWidth()==80 and calls==0 and l._notifyPending,'deferred commit queues notification only after complete submission')
 l:NotifyLayout();check(calls==1 and not l._notifyPending and l.dirty,'deferred notification reentry requests next batch')
 l:NotifyLayout();check(calls==1,'notification is consumed once')
 l:Release()
 l=row({a},{width=100,height=30});l:PrepareLayout()
 local newer=row({{frame=a,width=35}},{width=100,height=30,x=17});newer:Layout()
 l:CommitLayout();check(a:GetWidth()==35 and select(4,a:GetPoint())==17 and a._lycheeLayoutOwner==newer and l.dirty,'prepared old owner cannot write after another layout commits')
 l:Release();newer:Release()
 l=row({a,b},{width='content',height='content'});l:Layout();a:SetWidth(31);b:Hide();l:Layout()
 check(l.contentWidth==31 and not b._lycheeLayoutOwner,'stable check notices native dimensions and visibility without explicit declaration edits')
 a:SetScale(2);l:Layout();check(l.contentWidth==62,'stable check notices child effective scale changes')
 l:Release()
end
do
 local holder=frame(120,40);local a,b=frame(20,10,holder),frame(30,15,holder)
 local _,l=C.Box(holder,{layout='row',items={a,b},width='content',height='content',padding=2,gap=3})
 check(holder:GetWidth()==57 and holder:GetHeight()==19,'Box content dimensions follow successful common solver result')
 l:Release();C.Box(holder,{width='50%',height='fill'})
 check(holder:GetWidth()==150 and holder:GetHeight()==100,'direct Box percentage and fill resolve its native parent axes')
 C.Box(holder,20)
 local a2=frame(20,10);local l2=row({{frame=a2,width=20,height='fill'}},{width=80,height='content'})
 check(not pcall(l2.Layout,l2),'content cross fill dependency is explicit error')
 l2:Release()
end
do
 local a,b=frame(),frame();local old=row({a},{width=100,height=30});old:Layout()
 local newer=row({{frame=a,width=45,managePoints=false}},{width=100,height=30});newer:Layout();old:Release()
 check(a._lycheeLayoutFields.width==newer and not a._lycheeLayoutOwner,'old point owner release preserves independent new width owner')
 newer:Release()
 local calls=0;local l=row({{frame=a,width=70},{frame=b,width=50}},{width=200,height=30,onLayout=function() calls=calls+1 end})
 local setter=a.SetWidth;a.SetWidth=function(self,value) setter(self,value);l:Release() end
 l:Layout();check(l.released and b:GetWidth()==20 and calls==0,'release during native setter stops subsequent geometry and notification')
 a.SetWidth=setter
 local l2=row({{frame=a,width=90}},{width=200,height=30});local replacement
 a.SetWidth=function(self,value)
  setter(self,value)
  if not replacement then replacement=row({{frame=a,width=33}},{width=100,height=30,x=9});replacement:Layout() end
 end
 l2:Layout();check(a:GetWidth()==33 and select(4,a:GetPoint())==9 and a._lycheeLayoutOwner==replacement,'takeover inside a native setter stops older remaining writes')
 a.SetWidth=setter;l2:Release();replacement:Release()
end
-- Audit regressions run together so every previously failing case is visible.
do
 local failures={}
 local function audit(value,message) checks=checks+1;if not value then failures[#failures+1]=message end end
 local holder=frame(30,20);local a=frame(20,10,holder)
 local _,l=C.Box(holder,{layout='row',items={a},width='content',height='content',minWidth=100,maxWidth=120,minHeight=35,maxHeight=40})
 audit(holder:GetWidth()==100 and holder:GetHeight()==35,'content Box respects its own minimum dimensions')
 l:Release()
 local _,l2=C.Box(holder,{layout='row',items={a},width='content',height='content',minWidth=100,maxWidth=60})
 audit(holder:GetWidth()==100,'content Box minimum wins conflicting maximum');l2:Release()
 for _,vertical in ipairs({false,true}) do
  local f=frame();local item={frame=f,width=60,height='fill'}
  local options={mode='flex',width=100,height=80,flowWrap=true}
  if vertical then item.width,item.height='fill',60;options.width,options.height=80,100 end
  local wrap=(vertical and C.Column or C.Row)(parent,{item},options);wrap:Layout()
  audit((vertical and f:GetWidth() or f:GetHeight())==80,'wrapped fill receives determined cross budget '..tostring(vertical));wrap:Release()
 end
 local one,two=frame(),frame()
 local wrap=row({{frame=one,width=60,height=10},{frame=two,width=60,height='fill',minHeight=20}},{width=100,height=100,flowWrap=true,lineGap=10})
 wrap:Layout();audit(two:GetHeight()==50 and select(5,two:GetPoint())==-50,'wrapped lines share remaining cross space above natural minima');wrap:Release()
 local text=C.Text(parent,'A','label');text:SetWordWrap(true)
 local txt=row({{frame=text,width=60,height='content'}},{width=60,height='content'});txt:Layout();local old=text:GetHeight()
 text:SetText('This direct native text replacement wraps across several lines');txt:Layout()
 audit(text:GetHeight()>old,'explicit Layout notices direct native content text replacement')
 old=text:GetHeight();text:SetFont('font',24,'');txt:Layout();audit(text:GetHeight()>old,'content signature notices direct font replacement')
 txt:Release()
 for _,justify in ipairs({'space-around','space-evenly'}) do
  local x,y=frame(),frame();local l3=row({{frame=x,width=20},{frame=y,width=20}},{width=100,height=30,justify=justify});l3:Layout()
  local first=justify=='space-around' and 15 or 20;local second=justify=='space-around' and 65 or 60
  audit(near(select(4,x:GetPoint()),first) and near(select(4,y:GetPoint()),second),'justify implements '..justify);l3:Release()
 end
 local scaled=frame();scaled:SetScale(1.3)
 local stable=row({{frame=scaled,width=33.3,height=12.7}},{width=100,height=30});stable:Layout()
 local calls=0;local oldRead=scaled.GetFont;scaled.GetFont=function(self) calls=calls+1;return oldRead(self) end
 local oldField=C.LayoutValue;C.LayoutValue=function(...) calls=calls+1;return oldField(...) end
 for _=1,100 do stable:Layout() end
 C.LayoutValue=oldField;audit(calls==0,'noninteger effective scale remains on stable path');stable:Release()
 local box=frame(100,30);local first,second=frame(20,10,box),frame(30,10,box)
 local _,classLayout=C.Box(box,{classes='flex-row',items={first,second},gap=4})
 audit(classLayout and select(4,second:GetPoint())==24,'direction utility alone creates Box layout')
 if classLayout then classLayout:Release() end
 local _,override=C.Box(box,{layout='column',classes='flex-row',items={first,second},gap=4})
 audit(override and not override.vertical and select(4,second:GetPoint())==24,'effective class direction overrides explicit Box layout')
 if override then override:Release() end
 local _,bounded=C.Box(holder,{layout='row',items={{frame=a,width=160,shrink=1}},width='content',height='content',maxWidth=80})
 audit(holder:GetWidth()==80 and a:GetWidth()==80,'content maximum participates in the main-axis shrink budget');bounded:Release()
 local savedSettled=ctx._LayoutSettled;local settled=0
 ctx._LayoutSettled=function(self,layout) settled=settled+1;if savedSettled then savedSettled(self,layout) end end
 local last=frame();local final=row({{frame=last,width=50}},{width=100,height=30});final:Layout();local committedW=final.parentW
 final:SetItems({{frame=last,width=80}});parent:SetWidth(310)
 local setter=last.SetWidth;last.SetWidth=function() error('audit native setter failure') end
 audit(not pcall(final.Layout,final) and final.parentW==committedW and settled==1,'failed submission preserves last successful input cache and sends no settled signal')
 last.SetWidth=setter;final:Layout()
 audit(final.parentW==310 and settled==2 and not final.dirty,'successful synchronous retry publishes cache and settled signal')
 final:Release();ctx._LayoutSettled=savedSettled;parent:SetWidth(300)
 local colText=C.Text(parent,'a sufficiently long wrapped label text','label');colText:SetWordWrap(true);colText:SetSize(80,20)
 local col=C.Column(parent,{{frame=colText,width='fill',height='content'}},{mode='flex',width=80,height=100,flowWrap=true});col:Layout()
 audit(colText:GetWidth()==80 and colText:GetHeight()==80 and not col.overflow,'wrapped column measures content text at its allocated line width');col:Release()
 local textItems={}
 for i=1,3 do local f=C.Text(parent,'a sufficiently long wrapped label text','label');f:SetWordWrap(true);f:SetSize(80,20);textItems[i]={frame=f,width='fill',height='content'} end
 local cols=C.Column(parent,textItems,{mode='flex',width=80,height=100,flowWrap=true});cols:Layout()
 audit(cols.lineCount==3 and near(textItems[1].frame:GetWidth(),80/3) and textItems[1].frame:GetHeight()==220 and cols.overflow,'wrapped columns repack after line-width text measurement and retain real overflow');cols:Release()
 assert(#failures==0,table.concat(failures,'\n'))
end
do
 local holder=frame(300,100);local child=frame(20,35,holder)
 local column=C.Column(holder,{{frame=child,width='fill',manageHeight=false}},{mode='flex',height='content'})
 column:Layout();check(child:GetWidth()==300 and child:GetHeight()==35,'omitted unmanaged column main axis does not inherit fill from the width');column:Release()
 local manual=C.Column(holder,{{frame=child,height='fill',basis='50%',minHeight='50%',manageHeight=false}},{mode='flex',height='content'})
 manual:Layout();check(child:GetHeight()==35,'unmanaged field does not introduce a declarative content-axis dependency');manual:Release()
end
do
 local failures={}
 local function audit(value,message) checks=checks+1;if not value then failures[#failures+1]=message end end
 local host=frame(50,30);local child=frame(10,20,host)
 local _,inside=C.Box(host,{layout='row',items={child},height='content',track=true})
 local outside=row({{frame=host,width=200,height=80}},{width=300,height=100,track=true});outside:Layout();ctx:FlushLayouts()
 child:SetHeight(40);inside:Invalidate('content');ctx:FlushLayouts()
 audit(host:GetHeight()==80 and host._lycheeLayoutFields.height==outside,'content Box yields its height to a newer outer layout owner')
 inside:Release();audit(host:GetHeight()==80 and host._lycheeLayoutFields.height==outside,'old content Box release preserves newer height geometry and owner');outside:Release();C.ReleaseBox(host)
 local manual=frame(50,80);local manualChild=frame(10,20,manual)
 local _,manualLayout=C.Box(manual,{layout='row',items={manualChild},height='content',manageHeight=false})
 audit(manual:GetHeight()==80,'content Box manageHeight=false keeps native height as its read-only budget');manualLayout:Release();C.ReleaseBox(manual)
 for _,resize in ipairs({false,true}) do
  local container=frame(100,30);local a,b=frame(20,10,container),frame(30,10,container);local write=a.SetWidth
  local failed=true;a.SetWidth=function(self,value) write(self,value);if failed then error('partial width written before failure') end end
  local l=C.Row(container,{{frame=a,grow=1},{frame=b,grow=1}},{mode='flex'})
  audit(not pcall(l.Layout,l) and a:GetWidth()==45 and b:GetWidth()==30,'setter failure reproduces partial native geometry before retry')
  failed=false;if resize then container:SetWidth(200) end;l:Layout()
  audit(near(a:GetWidth(),resize and 95 or 45) and near(b:GetWidth(),resize and 105 or 55),'retry preserves the original business basis after partial setter failure '..tostring(resize));l:Release()
 end
 local container=frame(100,30);local a,b=frame(20,10,container),frame(30,10,container);local setter=a.SetWidth
 a.SetWidth=function(self,value) setter(self,value);error('partial output becomes explicit business input only on invalidation') end
 local explicit=C.Row(container,{{frame=a,grow=1},{frame=b,grow=1}},{mode='flex'});pcall(explicit.Layout,explicit)
 a.SetWidth=setter;explicit:Invalidate('new native baseline');explicit:Layout()
 audit(near(a:GetWidth(),57.5) and near(b:GetWidth(),42.5),'explicit invalidation deliberately rereads the current native business basis');explicit:Release()
 local pendingBox=frame(50,30);local pendingChild=frame(10,20,pendingBox)
 local _,pending=C.Box(pendingBox,{layout='row',items={pendingChild},height='content'})
 pending:SetItems({{frame=pendingChild,width=35,height=40}});pending:PrepareLayout()
 local newer=row({{frame=pendingBox,width=50,height=90,managePoints=false}},{width=300,height=100});newer:Layout();pending:CommitLayout()
 audit(pendingBox:GetHeight()==90 and pendingChild:GetWidth()==10 and pendingBox._lycheeLayoutFields.height==newer,'a new Box axis owner between prepare and commit cancels the entire old placement batch')
 pending:Release();newer:Release();C.ReleaseBox(pendingBox)
 local query=frame(400,100);C.Container(query,'content-axis')
 local conditionalBox=frame(50,30,query);local conditionalChild=frame(10,20,conditionalBox)
 local _,conditional=C.Box(conditionalBox,{layout='row',items={conditionalChild},height='content',track=true,conditions={
  {container='content-axis',minWidth=500,base={root={height=80}}},
  {container='content-axis',minWidth=600,base={root={height='50%'}}},
 }})
 ctx:FlushLayouts();query:SetWidth(550);ctx:FlushLayouts()
 audit(conditionalBox:GetHeight()==80 and not (conditionalBox._lycheeLayoutFields and conditionalBox._lycheeLayoutFields.height),'content-to-fixed condition submits the new size before relinquishing internal content ownership')
 query:SetWidth(650);ctx:FlushLayouts();audit(conditionalBox:GetHeight()==50,'conditional Box percentage uses the real parent budget rather than its last content output')
 query:SetWidth(400);ctx:FlushLayouts();audit(conditionalBox:GetHeight()==20 and conditionalBox._lycheeLayoutFields.height==conditional,'leaving the fixed condition restores content sizing and its field owner')
 C.ReleaseBox(conditionalBox);C.ReleaseContainer(query)
 local callbackBox=frame(50,30);local callbackChild=frame(10,20,callbackBox)
 local _,callbackLayout=C.Box(callbackBox,{layout='row',items={callbackChild},width='content',height='content'})
 local writeWidth=callbackBox.SetWidth;local takeover
 callbackBox.SetWidth=function(self,value)
  writeWidth(self,value)
  if not takeover then takeover=row({{frame=callbackBox,manageWidth=false,height=90,managePoints=false}},{width=300,height=100});takeover:Layout() end
 end
 callbackLayout:SetItems({{frame=callbackChild,width=30,height=40}});callbackLayout:Layout()
 audit(callbackBox:GetHeight()==90 and callbackBox._lycheeLayoutFields.height==takeover,'height ownership acquired during content width submission blocks the older height write')
 callbackLayout:Release();takeover:Release();C.ReleaseBox(callbackBox)
 local target=frame(30,20);C.Box(target,{padding=4});local original=target._lycheeBoxValues
 local other=LycheeUI:CreateContext({reducedMotion=true})
 audit(target._lycheeBoxContext==ctx and not pcall(other.C.Box,target,99) and target:GetWidth()==30 and target._lycheeBoxValues==original,'foreign Context Box rejects metadata takeover before native or rule mutation')
 C.Box(target,25);audit(not target._lycheeBoxContext,'same Context scalar replacement clears Box context registration')
 local newcomer=frame(10,10,target);local _,owned=other.C.Box(target,{layout='row',items={newcomer}})
 audit(owned.context==other and target._lycheeBoxContext==other,'new Box composition records its actual Context')
 C.ReleaseBox(target);audit(not owned.released and target._lycheeBoxLayout==owned,'late ReleaseBox from an old Context preserves the new composition')
 other.C.ReleaseBox(target);C.Box(target,{width=22,height=11});audit(not target._lycheeBoxContext,'ordinary fixed numeric Box remains free of Context registration')
 C.Box(target,{basis='fill'});audit(target._lycheeBoxValues.basis=='fill' and target._lycheeBoxContext==ctx,'symbolic Box basis is retained as registered layout metadata');C.Box(target,{width=22});audit(not target._lycheeBoxContext,'same Context plain Box replacement clears its earlier metadata registration')
 local excluded=frame();C.Element(excluded,'excluded-escape',{classes={base={root={participate=true}}}})
 local escape=row({{frame=excluded,participate=false}},{width=100,height=30});escape:Layout()
 audit(not escape.records[excluded] and not excluded._lycheeLayoutInputs and #escape.active==0,'descriptor participate=false remains a complete registration escape despite higher conditional style');escape:Release();C.ReleaseElement(excluded)
 assert(#failures==0,table.concat(failures,'\n'))
end
do
 -- Model the client's single-precision screen edges followed by subtraction
 -- and conversion back into UI units. This is not pixel-size rounding: small
 -- controls at a remote screen origin can read back several float ULPs away.
 local function float32(value)
  if value==0 then return 0 end
  local sign=value<0 and -1 or 1;local mantissa,exponent=math.frexp(math.abs(value))
  return sign*math.ldexp(math.floor(mantissa*16777216+.5)/16777216,exponent)
 end
 local nativeScale=.71111112833023071
 local function readback(value,origin) return float32((float32(origin+value*nativeScale)-float32(origin))/nativeScale) end
 local previousPhysical=GetPhysicalScreenSize;GetPhysicalScreenSize=function() return 2560,1440 end
 local host=frame(600,100);host:SetScale(nativeScale)
 local item=frame(20,16,host);local writes=0
 local oldWidth,oldHeight,oldPoint,oldClear=item.SetWidth,item.SetHeight,item.SetPoint,item.ClearAllPoints
 item.SetWidth=function(self,value) writes=writes+1;return oldWidth(self,readback(value,50)) end
 item.SetHeight=function(self,value) writes=writes+1;return oldHeight(self,readback(value,700)) end
 item.SetPoint=function(self,a,b,c,x,y) writes=writes+1;return oldPoint(self,a,b,c,readback(x,1000),readback(y,700)) end
 item.ClearAllPoints=function(self) writes=writes+1;return oldClear(self) end
 local l=C.Row(host,{{frame=item,width=20,height=16}},{mode='flex',width=600,height=100,x=434.25})
 l:Layout();local r=l.records[item]
 check(math.abs(item:GetWidth()-r.w)>2e-6 and math.abs(item:GetHeight()-r.h)>1e-5,'fixture reproduces real native size-readback error beyond the old size-relative epsilon')
 local field=C.LayoutValue;local calculations=0;C.LayoutValue=function(...) calculations=calculations+1;return field(...) end
 writes=0;for _=1,20 do l:Layout() end
 C.LayoutValue=field
 check(writes==0 and calculations==0,'native float readback stays on the stable path without size or point rewrites')
 l:Invalidate('same geometry');writes=0;l:Layout()
 check(writes==0,'same dirty geometry reuses its successful native readback for dimensions and anchors')
 local before=item:GetWidth();item.w=before+.00001;writes=0;l:Layout()
 check(writes>0 and math.abs(item:GetWidth()-before)<1e-9,'small external native width changes are still detected and repaired without a broad pixel tolerance')
 local a,b,c,x,y=item:GetPoint();oldPoint(item,a,b,c,x+.00001,y);writes=0;l:Layout()
 check(writes>0,'external managed point changes are detected independently of cached native size')
 l:SetItems({{frame=item,manageWidth=false,manageHeight=false,managePoints=false}});l:SetOptions({width='content',height='content',x=0});l:Layout()
 item.w=item.w+.00001;item.h=item.h+.00001;local actualW,actualH=item.w,item.h;writes=0;l:Layout()
 check(writes==0 and math.abs(l.contentWidth-actualW)<1e-9 and math.abs(l.contentHeight-actualH)<1e-9,'unmanaged axes continue to use external native values under float readback')
 l:Release()
 local tracked=frame(20,16,host);local trackedWidth,trackedHeight=tracked.SetWidth,tracked.SetHeight;local trackedWrites=0
 tracked.SetWidth=function(self,value) trackedWrites=trackedWrites+1;return trackedWidth(self,readback(value,50)) end
 tracked.SetHeight=function(self,value) trackedWrites=trackedWrites+1;return trackedHeight(self,readback(value,700)) end
 local nativeLayout=C.Row(host,{tracked},{mode='flex',track=true,width=600,height=100})
 local generation=nativeLayout.generation;ctx:FlushLayouts()
 check(not nativeLayout.dirty and nativeLayout.generation==generation and nativeLayout.records[tracked].nativeReadW==tracked:GetWidth(),'tracked omitted axes suppress only their own quantized synchronous size signals')
 trackedWrites=0;for _=1,20 do nativeLayout:Layout();ctx:FlushLayouts() end
 check(trackedWrites==0 and not ctx.layoutScheduler.driver:GetScript('OnUpdate'),'tracked quantized geometry settles with zero repeated writes or queue feedback')
 tracked:SetWidth(24);check(nativeLayout.dirty,'external native writes still invalidate a tracked omitted axis');ctx:FlushLayouts();check(not nativeLayout.dirty,'external tracked geometry settles after its new native input')
 nativeLayout:Release()
 local quantBox=frame(50,30,host);local boxW,boxH=quantBox.SetWidth,quantBox.SetHeight;local boxWrites=0
 quantBox.SetWidth=function(self,value) boxWrites=boxWrites+1;return boxW(self,readback(value,50)) end
 quantBox.SetHeight=function(self,value) boxWrites=boxWrites+1;return boxH(self,readback(value,700)) end
 local boxChild=frame(20,16,quantBox)
 local _,boxLayout=C.Box(quantBox,{layout='row',items={{frame=boxChild,width=20,height=16}},width='content',height='content',track=true})
 ctx:FlushLayouts();check(not boxLayout.dirty and boxLayout.boxNativeReadH==quantBox:GetHeight(),'content Box publishes successful readbacks without invalidating itself from native size signals')
 boxWrites=0;boxLayout:Invalidate('same declared content');ctx:FlushLayouts()
 check(boxWrites==0 and not boxLayout.dirty,'unchanged content Box dimensions skip quantized native setter rewrites')
 C.ReleaseBox(quantBox)
 local failing=frame(20,16,host);local nativeWidth=failing.SetWidth;local broken=false
 failing.SetWidth=function(self,value) nativeWidth(self,readback(value,50));if broken then error('post-write native float failure') end end
 local retry=C.Row(host,{{frame=failing,width=20,height=16}},{mode='flex',track=true,width=600,height=100});ctx:FlushLayouts()
 local savedRead=retry.records[failing].nativeReadW;retry:SetItems({{frame=failing,width=40,height=16}});broken=true
 check(not pcall(retry.Layout,retry) and retry.records[failing].nativeReadW==savedRead and not retry._writeTarget,'failed native write clears its signal marker and cannot publish a successful readback')
 broken=false;retry:Layout();check(not retry.dirty and retry.records[failing].nativeReadW==failing:GetWidth(),'native float failure retries and publishes the successful observed geometry')
 retry:Release();GetPhysicalScreenSize=previousPhysical
end
do
 local holder=frame(200,40);local a,b=frame(20,10,holder),frame(30,10,holder)
 local descriptors={{frame=a,width=20,height=10},{frame=b,width=30,height=10}}
 local l=C.Row(holder,descriptors,{mode='flex',width=200,height=40});l:Layout();local generation=l.generation
 l:SetItems(descriptors);l:Layout();check(l.generation==generation,'identical plain SetItems reuses the successful declaration compilation')
 descriptors[1].width=50;l:SetItems(descriptors);l:Layout();check(a:GetWidth()==50 and select(4,b:GetPoint())==50,'same-array descriptor axis edits invalidate the compiled declaration')
 descriptors[1].grow=1;l:SetItems(descriptors);l:Layout();check(a:GetWidth()==170,'same-array grow edits leave the simple numeric path and preserve distribution')
 descriptors[1].grow=nil;descriptors[1].manageWidth=false;a:SetWidth(23);l:SetItems(descriptors);l:Layout();check(a:GetWidth()==23,'same-array manual-axis edits preserve actual native input')
 l:Release()
 local ancestor=frame(600,100);C.Container(ancestor,'sync-alias');local host=frame(300,100,ancestor);local child=frame(20,10,host)
 C.Element(host,'slot-alias',{slots={root=host,child=child},classes={base={child={width=20}},conditions={{container='sync-alias',minWidth=500,base={child={width=160}}}}}})
 local alias=C.Row(host,{child},{mode='flex',width=300,height=100});alias:Layout();check(child:GetWidth()==160 and not child._lycheeStyleController,'conditional slot has a separate real controller')
 ancestor:SetWidth(400);alias:Layout();check(child:GetWidth()==20,'synchronous Layout resolves a dirty aliased slot condition before reusing geometry')
 ancestor:SetWidth(600);alias:SetItems(alias.items);alias:Layout();check(child:GetWidth()==160,'same-array SetItems still refreshes rule-backed conditional inputs')
 alias:Release();C.ReleaseElement(host);C.ReleaseContainer(ancestor)
 local native=frame(20,10);local reads=0;native.GetSize=function(self) reads=reads+1;return self.w,self.h end
 local capable=row({{frame=native,width=20,height=10}},{width=100,height=30});capable:Layout();reads=0;capable:Layout()
 check(reads==1,'stable geometry uses one capability-checked native size read when GetSize exists')
 native.w=25;capable:Layout();check(native:GetWidth()==20,'batched native size reads still detect external changes');capable:Release()
end
do
 local function single(value)
  if value==0 then return 0 end
  local sign=value<0 and -1 or 1;local m,e=math.frexp(math.abs(value));return sign*math.ldexp(math.floor(m*16777216+.5)/16777216,e)
 end
 local scale=.71111112833023071
 local function nativeRead(size,origin) return single((single(origin+size*scale)-single(origin))/scale) end
 local physical=GetPhysicalScreenSize;GetPhysicalScreenSize=function() return 2560,1440 end
 local host=frame(720,100);host:SetScale(scale);local items={};local fixedWrites,fillWrites=0,0
 for i=1,24 do
  local f=frame(20,16,host);local width=f.SetWidth
  f.GetWidth=function(self) return nativeRead(self.w,500+(self._desiredX or 0)*scale) end
  f.GetHeight=function(self) return nativeRead(self.h,700) end
  f.GetSize=function(self) return nativeRead(self.w,500+(self._desiredX or 0)*scale),nativeRead(self.h,700) end
  f.SetWidth=function(self,value) if i==1 then fillWrites=fillWrites+1 else fixedWrites=fixedWrites+1 end;return width(self,value) end
  local point=f.SetPoint
  f.SetPoint=function(self,a,b,c,x,y) self._desiredX=x;return point(self,a,b,c,x,y) end
  items[i]={frame=f,width=i==1 and 'fill' or 20,height=16}
 end
 local layout=C.Row(host,items,{mode='flex',gap=3,height=100});layout:Layout();fixedWrites,fillWrites=0,0
 for i=1,20 do host:SetWidth(i%2==0 and 720 or 960);layout:Layout() end
 check(fillWrites==20 and fixedWrites==0,'whole-pixel parent shifts preserve canonical fixed-item pixel spans without redundant width setters: fill='..fillWrites..' fixed='..fixedWrites)
 layout:Release();GetPhysicalScreenSize=physical
end
do
 local physical=GetPhysicalScreenSize;local height=1440;local screenReads=0
 GetPhysicalScreenSize=function() screenReads=screenReads+1;return 2560,height end
 local host=frame(100,40);local child=frame(20,16,host);local commits=0
 local layout=C.Row(host,{{frame=child,width=20,height=16}},{mode='flex',width=100,height=40,onLayout=function() commits=commits+1 end})
 layout:Layout();local first=child:GetWidth();local parentW,parentH,parentScale=host:GetWidth(),host:GetHeight(),host:GetEffectiveScale()
 height=2160;layout:Layout();local unit=768/height/parentScale;local expected=math.floor(20/unit+.5)*unit
 check(parentW==host:GetWidth() and parentH==host:GetHeight() and parentScale==host:GetEffectiveScale() and child:GetWidth()~=first and near(child:GetWidth(),expected),'physical screen height changes the pixel grid even when parent UI geometry is unchanged')
 local previousCommits=commits;screenReads=0
 layout:Layout();check(commits==previousCommits and screenReads==1,'unchanged physical screen signature uses one constant-time read and keeps the stable path')
 layout:Release();GetPhysicalScreenSize=physical
end
do
 local native=frame(20,16);local original=getmetatable(native).__index;local lookups,calls=0,0
 local method=function(self) return self.w,self.h end
 setmetatable(native,{__index=function(self,key)
  if key=='GetSize' then lookups=lookups+1;return method end
  if type(original)=='function' then return original(self,key) end;return original[key]
 end})
 local layout=row({{frame=native,width=20,height=16}},{width=100,height=40});layout:Layout();lookups=0;layout:Layout()
 check(lookups==1,'stable native GetSize capability uses one dynamic method lookup instead of probing the same method twice')
 native.GetSize=function(self) calls=calls+1;return method(self) end;layout:Layout()
 check(calls==1,'stable capability boolean keeps invoking the current instance method and its counting wrapper')
 layout:Release()
end
print('LycheeUI flex layouts: '..checks..' checks passed')
