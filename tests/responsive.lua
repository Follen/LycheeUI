-- Integrated declarations, conditional styles and on-demand layout scheduling.
local S=dofile('tests/stubs.lua');S.Install()
local private={};local manifest=assert(io.open('embeds.xml'));local xml=manifest:read('*a');manifest:close()
for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(file))('ResponsiveTest',private) end
local count=0
local function Check(value,message) count=count+1;assert(value,message) end
local function Near(a,b) return math.abs(a-b)<.000001 end
local function Frame(parent,w,h) local f=CreateFrame('Frame',nil,parent or UIParent);f:SetSize(w or 100,h or 40);return f end
local function Context() return LycheeUI:CreateContext({reducedMotion=true}) end
local function Idle(ctx) return not ctx.layoutScheduler or not ctx.layoutScheduler.driver or not ctx.layoutScheduler.driver:GetScript('OnUpdate') end
local function Condition(min,max,width,name) return {container=name or 'panel',minWidth=min,maxWidth=max,base={root={width=width}}} end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,700,100);C.Container(parent,'panel')
 local child=Frame(parent,20,20)
 C.Element(child,'item',{classes={conditions={Condition(600,nil,80)}}})
 Check(child:GetWidth()==80,'initial matching condition applies')
 parent:SetWidth(500);Check(not Idle(ctx),'a changed dependency schedules work')
 Check(ctx:FlushLayouts() and child:GetWidth()==20,'condition exit restores the business width')
 Check(Idle(ctx),'settled condition has no update script')
 parent:SetWidth(600);ctx:FlushLayouts();Check(child:GetWidth()==80,'minimum width is inclusive')
 C.Element(child,'item',{classes={conditions={Condition(nil,600,90)}}})
 Check(child:GetWidth()==20,'maximum width is exclusive')
 parent:SetWidth(599);ctx:FlushLayouts();Check(child:GetWidth()==90,'upper interval matches below boundary')
 parent:Hide();parent:SetWidth(601);Check(Idle(ctx),'hidden subtree retains dirtiness without an update task')
 parent:Show();ctx:FlushLayouts();Check(child:GetWidth()==20 and Idle(ctx),'show reapplies the current condition once')
 C.ReleaseElement(child)
 Check(#parent._lycheeLayoutSignals.entries==0,'release removes actual container subscriptions')
 Check(not child._lycheeStyleController._conditionBindings and not child._lycheeStyleController.hasOverrides,'release removes conditional rules and subscriptions')
end

do
 local ctx=Context();local C=ctx.C;local outer=Frame(nil,800,100);local inner=Frame(outer,300,100);local child=Frame(inner,20,20)
 C.Container(outer,'outer');C.Container(inner,'inner')
 C.Element(child,'nested',{classes={conditions={{when={{container='outer',minWidth=700},{container='inner',maxWidth=400}},base={root={width=55}}}}}})
 Check(child:GetWidth()==55,'named ancestor predicates combine with AND')
 local reads=0;local original=outer.GetWidth
 outer.GetWidth=function(self) reads=reads+1;return original(self) end
 local second=Frame(inner,20,20)
 C.Element(second,'second',{classes={conditions={{container='outer',minWidth=700,base={root={height=33}}}}}})
 reads=0;outer:SetWidth(801);ctx:FlushLayouts()
 Check(reads==1,'a source width is shared between actual subscribers in one batch')
 outer.GetWidth=original
 C.Container(inner,'other');ctx:FlushLayouts()
 Check(child:GetWidth()==20,'renaming a needed container removes the old condition contribution')
 C.Container(inner,'inner');ctx:FlushLayouts();Check(child:GetWidth()==55,'adding the needed name reapplies the matching contribution')
 C.ReleaseElement(child);C.ReleaseElement(second)
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,200,40)
 local a,b=Frame(parent,10,20),Frame(parent,10,20)
 local layout=C.Row(parent,{{frame=a,width='fill'},{frame=b,width=40}},{mode='flex',track=true,gap=10})
 Check(ctx:FlushLayouts() and Near(a:GetWidth(),150),'tracked parent computes geometry')
 Check(Idle(ctx),'geometry settles without an idle driver')
 parent:SetWidth(300);parent:SetWidth(400)
 local before=ctx.layoutScheduler.commits
 ctx:FlushLayouts();Check(Near(a:GetWidth(),350) and ctx.layoutScheduler.commits==before+1,'same batch size signals collapse to one final commit')
 b:Hide();ctx:FlushLayouts();Check(Near(a:GetWidth(),400),'hidden child leaves the layout')
 b:Show();ctx:FlushLayouts();Check(Near(a:GetWidth(),350),'shown child returns to the layout')
 parent:Hide();parent:SetWidth(600);Check(Idle(ctx),'hidden flow stops pending work')
 parent:Show();ctx:FlushLayouts();Check(Near(a:GetWidth(),550),'shown flow consumes the latest width')
 layout:Release();Check(Idle(ctx) and #parent._lycheeLayoutSignals.entries==0,'release cancels work and parent subscription')
 Check(#b._lycheeLayoutSignals.entries==0,'release cancels physical item subscriptions')
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,600,40);C.Container(parent,'panel')
 local content=Frame(parent,600,40);local a,b=Frame(content,10,20),Frame(content,10,20)
 C.Element(a,'growing',{classes={base={root={grow=1,basis=0}},conditions={{container='panel',minWidth=700,base={root={grow=2}}}}}})
 local layout=C.Row(content,{{frame=a,width='fill'},{frame=b,width='fill'}},{mode='flex',track=true})
 ctx:FlushLayouts();Check(Near(a:GetWidth(),300),'unconditional grow shares the width')
 parent:SetWidth(800);ctx:FlushLayouts();Check(Near(a:GetWidth(),400),'condition updates only the affected owning layout')
 parent:SetWidth(600);ctx:FlushLayouts();Check(Near(a:GetWidth(),300),'condition exit rebalances the existing objects')
 local before=#S.nodes;for _=1,100 do parent:SetWidth(800);ctx:FlushLayouts();parent:SetWidth(600);ctx:FlushLayouts() end
 Check(#S.nodes==before,'repeated conditions create no native objects')
 Check(a._lycheeLayoutFields.width==layout,'style conditions retain layout width ownership')
 C.ReleaseElement(a);layout:Release()
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,300,100)
 local a,b=Frame(parent,10,20),Frame(parent,10,20)
 local order={}
 local first=C.Row(parent,{a},{mode='flex',track=true,onLayout=function() order[#order+1]='first';ctx:Hide() end})
 local second=C.Row(parent,{b},{mode='flex',track=true,onLayout=function() order[#order+1]='second' end})
 Check(ctx:FlushLayouts(),'hiding during notification completes cleanly')
 Check(#order==1 and order[1]=='first','hide prevents the remaining display notifications')
 Check(Idle(ctx),'hide leaves no scheduler callback')
 first:Release();second:Release()
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,300,100);local a,b=Frame(parent,10,20),Frame(parent,10,20)
 local second;local callbacks=0
 local first=C.Row(parent,{a},{mode='flex',track=true,onLayout=function() second:Release() end})
 second=C.Row(parent,{b},{mode='flex',track=true,onLayout=function() callbacks=callbacks+1 end})
 Check(ctx:FlushLayouts() and callbacks==0,'release of a queued notification is safe')
 first:Release();Check(Idle(ctx),'notification release leaves idle state')
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,500,100);C.Container(parent,'panel');local child=Frame(parent,20,20)
 C.Element(child,'fault',{classes={conditions={Condition(600,nil,80)}}})
 local original=child.SetWidth;local fail=true
 child.SetWidth=function(self,value) if fail then error('injected width failure') end;return original(self,value) end
 parent:SetWidth(700)
 local ok,message=ctx:FlushLayouts();Check(not ok and message:find('injected width failure'),'native write failure is reported')
 Check(Idle(ctx),'failed application leaves no perpetual task')
 fail=false;ctx:_QueueLayout(child._lycheeStyleController,'retry')
 Check(ctx:FlushLayouts() and child:GetWidth()==80,'explicit retry reapplies a selected condition after failure')
 child.SetWidth=original;C.ReleaseElement(child)
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,500,100);local child=Frame(parent,20,20)
 C.Container(parent,'panel');C.Element(child,'transaction',{classes={conditions={Condition(400,nil,80)}}})
 local before=#parent._lycheeLayoutSignals.entries;local original=child.GetParent
 local chain=Frame(nil,10,10);chain.parent=chain
 child.GetParent=function() return chain end
 local ok=pcall(ctx._BindConditions,ctx,child._lycheeStyleController,child._lycheeStyleController.conditionSelectors)
 Check(not ok,'invalid ancestry is rejected')
 Check(#parent._lycheeLayoutSignals.entries==before,'failed preflight preserves existing subscriptions')
 child.GetParent=original;C.ReleaseElement(child)
 Check(#parent._lycheeLayoutSignals.entries==0,'failed binding still releases completely')
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,400,100);local text=C.Text(parent,'short',14,'text');text:SetWordWrap(true)
 local layout=C.Column(parent,{{frame=text,width='fill',height='content'}},{mode='flex',track=true})
 ctx:FlushLayouts();local height=text:GetHeight()
 ctx:SetText(text,string.rep('long content ',30));ctx:FlushLayouts()
 Check(text:GetHeight()>height,'Context text writes invalidate only their owned content layout')
 layout:Release()
 local fixed=Frame(parent,50,20);local nodes=#S.nodes
 for _=1,200 do C.Box(fixed,{width=50,height=20}) end
 Check(not fixed._lycheeBoxValues and not fixed._lycheeBoxLayout and #S.nodes==nodes,'ordinary fixed boxes retain no empty geometry record or native driver')
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,700,100);C.Container(parent,'panel')
 local target=Frame(parent,40,20)
 C.Box(target,{width=120,classes='w-80'})
 Check(target:GetWidth()==80 and C.LayoutValue(target,'width')==80,'Box utility and native width agree and fixed rules win')
 C.Box(target,{width=110})
 Check(target:GetWidth()==110 and not target._lycheeBoxRules and not ctx.elements[target],'replacement Box removes its old synthetic rule layer')
 C.Element(target,'original',{key='A',classes='alpha-50 w-24'})
 C.Box(target,{width=120,classes='h-32',conditions={Condition(600,nil,80)}})
 Check(target:GetAlpha()==.5 and target:GetWidth()==80 and target:GetHeight()==32,'Box adds rules while preserving ordinary element classes')
 Check(ctx.elements[target].id=='original' and ctx.elements[target].key=='A' and ctx.elements[target].classes=='alpha-50 w-24','Box preserves semantic identity and declaration')
 C.RekeyElement(target,'B');C.ReleaseBox(target)
 Check(ctx.elements[target].key=='B' and target:GetWidth()==24 and target:GetHeight()==20,'releasing Box restores the current element without stale identity')
 C.Box(target,{classes='h-32'})
 C.Element(target,'replacement',{key='C',classes='w-40'})
 C.ReleaseBox(target)
 Check(ctx.elements[target].id=='replacement' and ctx.elements[target].key=='C' and target:GetWidth()==40 and target:GetHeight()==20,'external element replacement survives Box release')
 C.Box(target,{width=140});Check(target:GetWidth()==40,'ordinary element rules still override new native Box fallback')
 C.ReleaseElement(target);Check(target:GetWidth()==140,'release restores the latest Box business fallback')
 local synthetic=Frame(parent,12,13);C.Box(synthetic,{classes='h-32'})
 C.Element(synthetic,'real',{classes='w-80'});C.ReleaseBox(synthetic)
 Check(ctx.elements[synthetic].id=='real' and synthetic:GetWidth()==80 and synthetic:GetHeight()==13,'a promoted synthetic element becomes independently owned')
 C.Box(synthetic,{classes='h-32'});C.Box(synthetic,50)
 Check(synthetic:GetWidth()==80 and synthetic:GetHeight()==50 and not synthetic._lycheeBoxRules,'scalar Box clears its own rules and preserves other fixed rules')
 C.ReleaseElement(synthetic)
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,300,100)
 local first=C.Row(parent,{Frame(parent,10,20)},{mode='flex',track=true})
 local secondChild=Frame(parent,10,20);local second=C.Row(parent,{{frame=secondChild,width='fill'}},{mode='flex',track=true})
 ctx:FlushLayouts();local invalidate=first.Invalidate
 first.Invalidate=function() error('signal failure') end
 parent:SetWidth(400)
 Check(not parent._lycheeLayoutSignals.dispatching and #parent._lycheeLayoutSignals.buffer==0,'failed subscriber clears dispatch state and snapshot references')
 Check(first.lastError:find('signal failure') and ctx:FlushLayouts() and secondChild:GetWidth()==400,'failed subscriber does not block other owners')
 first.Invalidate=invalidate;first:Release();second:Release()
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,300,100);local calls=0
 local layout=C.Row(parent,{Frame(parent,10,20)},{mode='flex',track=true,onLayout=function(self) calls=calls+1;self:Invalidate('callback') end})
 for _=1,8 do if not Idle(ctx) then ctx:FlushLayouts() end end
 Check(calls<=5 and Idle(ctx) and layout.lastError:find('notification feedback'),'callback feedback has a finite frame budget')
 layout:SetOptions({mode='flex',track=true,onLayout=false});layout:Invalidate('retry')
 Check(ctx:FlushLayouts() and Idle(ctx),'an external correction recovers from a stopped callback cycle')
 layout:Release()
end

do
 local ctx=Context();local C=ctx.C;local host=Frame(nil,300,100);local steps=0
 local job={mode='list-flow',host=host,dirty=true}
 function job:Invalidate(reason) self.dirty=true;ctx:_QueueLayout(self,reason) end
 function job:StepLayout() steps=steps+1;self.dirty=steps<3;return not self.dirty end
 ctx:_TrackWork(job);ctx:FlushLayouts()
 Check(steps==1 and not Idle(ctx),'bounded index work advances once per flush')
 host:Hide();Check(Idle(ctx) and job.dirty,'hidden index work keeps dirtiness without a callback')
 host:Show();ctx:FlushLayouts();Check(steps==2,'shown index work resumes one step')
 ctx:FlushLayouts();Check(steps==3 and Idle(ctx),'completed index work releases the shared update callback')
 ctx:_ForgetWork(job);Check(#host._lycheeLayoutSignals.entries==0 and not job._layoutContext,'index release clears subscriptions and context')
end

do
 local first,second=Context(),Context();local parent=Frame(nil,400,100);local child=Frame(parent,20,20)
 first.C.Container(parent,'panel');first.C.Element(child,'source',{classes={conditions={Condition(300,nil,80)}}})
 local before=#parent._lycheeLayoutSignals.entries
 Check(not pcall(second.C.Container,parent,'panel') and parent._lycheeContainer.context==first and #parent._lycheeLayoutSignals.entries==before,'cross-context transfer requires explicit release and preserves the original owner')
 local original=parent.GetParent;parent.GetParent=function() return parent end
 Check(not pcall(first.C.ReleaseContainer,parent) and parent._lycheeContainer.context==first,'failed container release restores its marker')
 parent.GetParent=original;first.C.ReleaseElement(child);first.C.ReleaseContainer(parent);second.C.Container(parent,'panel')
 Check(parent._lycheeContainer.context==second and #parent._lycheeLayoutSignals.entries==0,'explicit cross-context release and acquisition leaves no old subscriptions')
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,400,100);local label=C.Text(parent,'delayed metrics',14,'text')
 label:SetSize(77,23);local read=label.GetUnboundedStringWidth;local attempts=0
 label.GetUnboundedStringWidth=function(self) attempts=attempts+1;if attempts<2 then return 0 end;return read(self) end
 local layout=C.Row(parent,{{frame=label,width='content',height='content'}},{mode='flex',track=true})
 ctx:FlushLayouts();Check(attempts==1 and label:GetWidth()==77 and label:GetHeight()==23 and not Idle(ctx),'unready metrics retain native geometry and defer one frame')
 ctx:FlushLayouts();Check(attempts==2 and label:GetWidth()>77 and Idle(ctx),'ready metrics commit once and remove deferred work')
 label.GetUnboundedStringWidth=function() return 0 end;C.InvalidateTextMetrics(label);layout:Invalidate('text')
 for _=1,6 do if not Idle(ctx) then ctx:FlushLayouts() end end
 Check(Idle(ctx) and layout.lastError:find('two frame retries') and layout._metricsRetries==3,'persistently unavailable metrics stop after two retries')
 label.GetUnboundedStringWidth=read;layout:Invalidate('font-ready');Check(ctx:FlushLayouts() and Idle(ctx),'new font evidence recovers a stopped metrics retry')
 layout:Release()
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,400,100);C.Container(parent,'panel')
 local a,b=Frame(parent,50,20),Frame(parent,50,20)
 C.Element(a,'conditional-participant',{classes={conditions={{container='panel',minWidth=500,base={root={participate=false}}}}}})
 local layout=C.Row(parent,{a,b},{mode='flex',track=true,gap=10});ctx:FlushLayouts()
 Check(select(4,b:GetPoint())==60,'ordinary participant takes its declared slot')
 parent:SetWidth(600);ctx:FlushLayouts();Check(select(4,b:GetPoint())==0 and a:IsShown(),'conditional nonparticipation removes space without changing business visibility')
 parent:SetWidth(400);ctx:FlushLayouts();Check(select(4,b:GetPoint())==60,'an excluded native object retains only its actual input dependency and can return')
 C.Box(a,{reserve=true});a:Hide();ctx:FlushLayouts();Check(select(4,b:GetPoint())==60 and not a:IsShown(),'structured reserve retains hidden space')
 C.Box(a,{reserve=false});ctx:FlushLayouts();Check(select(4,b:GetPoint())==0,'clearing reserve removes hidden space')
 layout:Release();Check(not a._lycheeLayoutInputs and not b._lycheeLayoutInputs,'release clears input dependencies as well as field owners')
 C.ReleaseElement(a);a:Show();C.Box(a,{grow=2,basis=0});C.Box(b,{grow=1,basis=0})
 local row=C.Row(parent,{a,b},{mode='flex'});row:Layout();Check(Near(a:GetWidth(),400*2/3) and Near(b:GetWidth(),400/3),'structured Box grow and basis participate in the shared solver')
 row:Release();C.ReleaseBox(a);C.ReleaseBox(b)
end

do
 local a,b=Context(),Context();local target=Frame(nil,30,20)
 a.C.Element(target,'first',{classes='w-80'})
 Check(not pcall(b.C.Element,target,'second',{classes='w-40'}) and target:GetWidth()==80 and not b.elements[target],'cross-context element rebind is rejected before changing either registry')
 a.C.ReleaseElement(target);b.C.Element(target,'second',{classes='w-40'})
 a.C.ReleaseElement(target)
 Check(b.elements[target].id=='second' and target:GetWidth()==40 and target._lycheeStyleController.context==b,'explicit element transfer discards only an idle old binding and ignores a late release')
 b.C.ReleaseElement(target);target._lycheeStyleController:Release()
 local style=a.C.Style(target,{style={root={height=32}}})
 Check(not pcall(b.C.Style,target,{style={root={height=55}}}) and target:GetHeight()==32,'construction styles cannot silently switch Context')
 style:Release();local nextStyle=b.C.Style(target,{style={root={height=55}}});style:Release()
 Check(target:GetHeight()==55 and nextStyle.context==b,'explicit style transfer keeps the current owner on late release')
 nextStyle:Release()
end

do
 local ctx=Context();local C=ctx.C;local parent=Frame(nil,400,100)
 local label=C.Text(parent,'initial',14,'text');local textLayout=C.Row(parent,{{frame=label,width='content',height='content'}},{mode='flex',track=true})
 ctx:FlushLayouts();local nativeRead=label.GetUnboundedStringWidth;local missing=true;local calls=0
 label.GetUnboundedStringWidth=function(self) calls=calls+1;if missing then return 0 end;return nativeRead(self) end
 local trigger=C.Row(parent,{Frame(parent,20,20)},{mode='flex',track=true,onLayout=function()
  label:SetText('replacement text');textLayout:Layout()
 end})
 ctx:FlushLayouts();Check(calls==1 and not Idle(ctx) and #ctx.layoutScheduler.deferred==0,'metrics deferred from a layout notification still wake the following frame')
 missing=false;ctx:FlushLayouts();Check(calls==2 and Idle(ctx) and not textLayout.dirty,'notification-deferred text finishes after metrics become available')
 textLayout:Release();trigger:Release()
end

print('LycheeUI responsive integration: '..count..' checks passed')
