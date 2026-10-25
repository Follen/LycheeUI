-- Independent runner: lua tests/responsive_rules.lua. Container lookup is a
-- focused substitute; tests/responsive.lua covers the actual scheduler.
local S=dofile("tests/stubs.lua");S.Install()
local private={}
local manifest=assert(io.open("embeds.xml"));local xml=manifest:read("*a");manifest:close()
for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(file))("ResponsiveRules",private) end
local Library=_G.LycheeUI
local assertions=0
local function check(value,message) assertions=assertions+1;assert(value,message) end
local function frame(parent,width) local f=CreateFrame("Frame",nil,parent or UIParent);f:SetSize(width or 30,20);return f end
local function instrument(ctx)
 ctx.binds,ctx.releases=0,0
 function ctx:_BindConditions(controller,selectors) self.binds=self.binds+1;controller.testSelectors=selectors;controller.conditionsDirty=true end
 function ctx:_ReleaseConditions(controller) if controller.testSelectors then self.releases=self.releases+1;controller.testSelectors=nil end end
 function ctx:_RefreshConditions(controller)
  if not controller.conditionsDirty then return false end;controller.conditionsDirty=false
  local changed=false
  for index,branch in ipairs(controller.testSelectors) do
   local match=true
   for _,selector in ipairs(branch.when) do
    local parent=controller.host:GetParent()
    while parent and (not parent.containerName or selector.container and parent.containerName~=selector.container) do parent=parent:GetParent() end
    local width=parent and parent:GetWidth()
    local lo=type(selector.minWidth)=="string" and self.Theme[selector.minWidth] or selector.minWidth
    local hi=type(selector.maxWidth)=="string" and self.Theme[selector.maxWidth] or selector.maxWidth
    match=match and width~=nil and (lo==nil or width>=lo) and (hi==nil or width<hi)
   end
   changed=changed or controller.conditionMatches[index]~=match;controller.conditionMatches[index]=match
  end
  return changed
 end
 return ctx
end
local function refresh(target) local c=target.styleController;c.conditionsDirty=true;c:Apply(true) end
local catalog={item={slotKinds={root="box"}},classes={slotKinds={root="box"}},row={template=true,slotKinds={root="box"}},alias={slotKinds={root="box",child="box"}}}
local ctx=instrument(Library:CreateContext({reducedMotion=true,themeDefaults={toolbarWide=640},elementDefaults=catalog,elements={
 item={base={root={width=40}},states={selected={root={width=45}},hover={root={width=50}},disabled={root={width=60}}},conditions={
  {minWidth=640,base={root={width=80}},states={selected={root={width=85}},hover={root={width=90}}}},
  {when={{container="outer",minWidth=900},{container="inner",maxWidth=960}},base={root={width=100}},states={hover={root={width=110}}}},
 }},
 classes={classes="w-40 selected:w-44 hover:w-48 @toolbarWide/inner:w-80 @640/inner:selected:w-96 @900/outer:@max-960/inner:w-100 @900/outer:hover:@max-960/inner:w-120"},
 row={instances={one={conditions={{minWidth=640,base={root={width=120}}}}},two={conditions={{maxWidth=640,base={root={width=160}}}}}}},
 alias={conditions={{minWidth=640,base={child={width=180}}}}},
}}))
local C=ctx.C
local outer=frame(nil,1000);outer.containerName="outer"
local inner=frame(outer,639);inner.containerName="inner"
local item=frame(inner);C.Element(item,"item")
check(item:GetWidth()==100,"named ancestor AND branches override ordinary bases")
C.SetElementState(item,"selected",true);check(item:GetWidth()==45,"ordinary selected state follows every conditional base")
C.SetElementState(item,"hover",true);check(item:GetWidth()==110,"conditional hover follows ordinary hover in declaration order")
C.SetElementState(item,"disabled",true);check(item:GetWidth()==60,"disabled remains last and suppresses hover")
C.SetElementState(item,"disabled",false);C.SetElementState(item,"selected",false)
outer:SetWidth(899);inner:SetWidth(640);refresh(item);check(item:GetWidth()==80,"minimum width is inclusive and a missing AND selector disables only its branch")
inner:SetWidth(639);refresh(item);check(item:GetWidth()==40,"condition exits reveal ordinary rules")
outer:SetWidth(1000);inner:SetWidth(960);refresh(item);check(item:GetWidth()==80,"maximum width is exclusive")
local class=frame(inner);C.Element(class,"classes");check(class:GetWidth()==80,"numeric theme token class condition compiles with static geometry")
inner:SetWidth(800);refresh(class);check(class:GetWidth()==100,"chained class prefixes compile as AND selectors")
C.SetElementState(class,"hover",true);check(class:GetWidth()==120,"state prefix may appear between container prefixes")
local baseline=frame(inner,35);C.Element(baseline,"row",{key="one"});check(baseline:GetWidth()==120,"conditional instance rule applies")
baseline:SetWidth(55);refresh(baseline);inner:SetWidth(639);refresh(baseline);check(baseline:GetWidth()==55,"exiting restores the latest business baseline")
local oldSelectors=baseline.styleController.conditionSelectors
C.RekeyElement(baseline,"two");check(baseline:GetWidth()==160 and baseline.styleController.conditionSelectors~=oldSelectors,"rekey replaces condition subscriptions and instance contributions")
local bound=ctx.binds;local releases=ctx.releases;C.ReleaseElement(baseline)
check(ctx.releases>releases and not baseline.styleController.conditionSelectors and baseline:GetWidth()==55,"release clears subscriptions and restores business geometry")
local stable=item.styleController;local compiled=stable.compiled;local matches=stable.conditionMatches;local records=stable.records
local binds=ctx.binds
for i=1,200 do stable:Apply(true);C.Element(item,"item") end
check(stable.compiled==compiled and stable.conditionMatches==matches and stable.records==records and ctx.binds==binds,"stable input reuses compilation, matches, records and dependency bindings")
local plain=frame();C.Style(plain,{style={root={width=50}}})
check(not plain.styleController.conditionSelectors and not plain.styleController.conditionMatches and ctx.binds==binds,"ordinary fixed styles allocate no condition state")
inner:SetWidth(800)
local host=frame(inner);local child=frame(host);C.Element(host,"alias",{slots={root=host,child=child}})
C.Element(child,"classes");check(child:GetWidth()==100,"direct native root wins its fields over a parent slot")
C.ReleaseElement(child);check(child:GetWidth()==180,"releasing direct binding reveals active conditional slot contribution")
local layout={invalidations=0,Invalidate=function(self,reason) self.invalidations=self.invalidations+1;self.reason=reason end}
local flex=frame(inner,200);flex._lycheeLayoutFields={width=layout,height=layout,points=layout}
flex._lycheeBoxLayout=layout
local style=C.Style(flex,{style={root={width="fill",height="content",minWidth="10%",maxWidth="90%",basis="25%",direction="row",flowWrap=true,gap=8,lineGap=4,grow=1,shrink=0,justify="space-between",participate=true,reserve=false,manageWidth=true,manageHeight=false,managePoints=false}}})
check(flex:GetWidth()==200 and flex:GetHeight()==20,"flex owner is the sole native size writer")
check(C.FixedValue(flex,"width")=="fill" and C.FixedValue(flex,"basis")=="25%" and C.FixedValue(flex,"direction")=="row","FixedValue preserves symbolic sizes and literal layout fields")
check(flex._lycheeBoxValues.flowWrap and flex._lycheeBoxValues.minWidth=="10%" and flex._lycheeBoxValues.manageHeight==false,"geometry declarations share the existing metadata table")
local invalidations=layout.invalidations;flex:SetWidth(350);flex:SetHeight(80)
for i=1,100 do style:Apply(true) end
check(layout.invalidations==invalidations and style.records.root.base.width==200,"solved geometry neither becomes business baseline nor repeatedly invalidates")
local selfLayout=frame();selfLayout._lycheeBoxLayout=layout
C.Style(selfLayout,{style={root={direction="column",gap=12}}});check(layout.invalidations>invalidations and selfLayout._lycheeBoxValues.direction=="column" and selfLayout._lycheeBoxValues.gap==12,"container direction and gap publish current inputs and invalidate its own flex layout")
local symbolic=frame(nil,77);C.Style(symbolic,{style={root={width="content",height="50%"}}})
check(symbolic:GetWidth()==77 and symbolic:GetHeight()==20 and symbolic._lycheeBoxValues.width=="content","symbolic declarations stay pending without a native string setter")
local rules=Library.CompileUtilities({})("flex-row flex-wrap gap-8 grow shrink-0 basis-40 w-fill h-content items-stretch justify-space-around wrap")
check(rules.base.root.direction=="row" and rules.base.root.flowWrap and rules.base.root.wordWrap and rules.base.root.basis==40,"new utilities share the existing compiler and preserve text wrap")
local branchClasses=instrument(Library:CreateContext({elementDefaults={x={slotKinds={root="box"}}},elements={x={conditions={{minWidth=640,classes="w-80"}}}}}))
local branchTarget=frame(inner);branchClasses.C.Element(branchTarget,"x");check(branchTarget:GetWidth()==80,"classes inside structured branches count as declared rules")
local equivalent=Library.CompileUtilities({})({conditions={{container="inner",minWidth=640,classes="w-80"}}})
local equivalentClass=Library.CompileUtilities({})("@640/inner:w-80")
check(equivalent.conditions[1].when[1].minWidth==equivalentClass.conditions[1].when[1].minWidth and equivalent.conditions[1].base.root.width==equivalentClass.conditions[1].base.root.width,"structured and prefixed classes produce equivalent branch rules")
local variant=Library.ResolveStyleVariant({conditions={{minWidth=1}},variants={wide={conditions={{maxWidth=2}}}}},"wide")
check(#variant.conditions==2,"variants retain ordinary and variant condition declarations")
local invalid={
 {conditions="bad"},{conditions={{minWidth=-1,base={root={width=10}}}}},
 {conditions={{minWidth="text",base={root={width=10}}}}},{conditions={{minWidth=0/0}}},
 {conditions={{container=false,minWidth=1}}},{conditions={{minWidth=1,conditions={}}}},
 {conditions={{when={}}}},{conditions={{when={{minWidth=1},{minWidth=2},{minWidth=3},{minWidth=4},{minWidth=5}}}}},
 {classes="@640/inner:unknown"},{classes="@10/inner:@20/outer:@30:@40:@50:w-80"},
 {conditions={{minWidth=1,base={root={width="banana"}}}}},
 {conditions={{minWidth=1,base={root={flowWrap=1}}}}},
 {conditions={{minWidth=1,base={root={direction="diagonal"}}}}},
 {conditions={{minWidth=1,extra=true}}},
}
for index,entry in ipairs(invalid) do local ok,valid,message=pcall(Library.ValidateElements,Library,{item=entry},catalog,ctx.Theme);check(ok and valid==false and type(message)=="string","invalid conditional rule reports validation failure "..index) end
local tooMany={conditions={}};for i=1,33 do tooMany.conditions[i]={minWidth=i,base={root={width=i}}} end
check(not Library:ValidateElements({item=tooMany},catalog,ctx.Theme),"condition branch limit is bounded")
local defaults={item={slotKinds={root="box"},conditions={}}};local overrides={item={conditions={}}}
for i=1,20 do defaults.item.conditions[i]={minWidth=i,base={root={width=i}}};overrides.item.conditions[i]={maxWidth=i,base={root={width=i}}} end
check(not Library:ValidateElements(overrides,defaults,ctx.Theme),"merged default and override conditions share the same branch limit")
local inherited={conditions={},variants={wide={conditions={}}}};for i=1,20 do inherited.conditions[i]={minWidth=i};inherited.variants.wide.conditions[i]={maxWidth=i} end
check(not Library:ValidateElements({item=inherited},catalog,ctx.Theme),"variants cannot exceed the inherited branch limit")
local capability=frame(inner);capability.SetRadius=false
local ok=pcall(C.Element,capability,"item",{classes="@10000:gap-8"})
check(ok,"unmatched metadata branches use the ordinary target capability model")
local texture=C.Icon(inner,12)
ok=pcall(C.Element,texture,"unsupported",{classes="@10000:single-line"})
check(not ok,"unmatched condition branches still validate native capabilities")
local failing=frame();local native=failing.SetWidth;local fail=false
failing.SetWidth=function(self,width) if fail then error("injected native failure") end;return native(self,width) end
local control=C.Style(failing,{states={hover={root={width=90}}}})
fail=true;ok=pcall(control.SetState,control,"hover",true)
check(not ok and not control.applying,"failed style application releases its reentrancy guard")
fail=false;control:Apply(true);check(failing:GetWidth()==90,"failed native writes retry instead of caching success")
local lease=frame(inner,45);local owned=true;C.Element(lease,"row",{key="one",owner={IsOwned=function() return owned end}})
owned=false;lease:SetWidth(333);C.ReleaseElement(lease);check(lease:GetWidth()==333,"lost native lease release leaves its new host untouched")
local schemaDefaults={['screen.toolbar']={slotKinds={root="box",label="text"},conditions={
 {container="inner",minWidth="toolbarWide",base={root={width="fill"}},states={hover={label={fontSize=18}}},classes="gap-8"},
 {when={{container="outer",minWidth=500},{maxWidth=900}},base={root={gap=12}}},
},variants={compact={conditions={{minWidth=400,classes="gap-4",base={root={direction="column"}}}}}}}}
local paths={
 ['screen.toolbar.conditions.1.base.root.width']="fill",
 ['screen.toolbar.conditions.1.states.hover.label.fontSize']=18,
 ['screen.toolbar.conditions.1.classes']="gap-8",
 ['screen.toolbar.conditions.1.container']="inner",
 ['screen.toolbar.conditions.1.minWidth']="toolbarWide",
 ['screen.toolbar.conditions.2.when.1.container']="outer",
 ['screen.toolbar.conditions.2.when.1.minWidth']=500,
 ['screen.toolbar.conditions.2.when.2.maxWidth']=900,
 ['screen.toolbar.variants.compact.conditions.1.classes']="gap-4",
 ['screen.toolbar.variants.compact.conditions.1.base.root.direction']="column",
}
local schema=Library:GetElementSchema(schemaDefaults)
for path,value in pairs(paths) do
 local field=Library:GetElementField(path,schemaDefaults)
 check(field and field.default==value and schema[path] and schema[path].default==value,"conditional static schema exposes "..path)
end
check(not Library:GetElementField('screen.toolbar.conditions.3.base.root.width',schemaDefaults) and not Library:GetElementField('screen.toolbar.conditions.2.when.3.minWidth',schemaDefaults),"conditional schema does not invent branches or selectors")
local pending=frame();local nativeAlpha=pending.SetAlpha;local inject=false
pending.SetAlpha=function(self,value) nativeAlpha(self,value);if inject then error("partial native write") end end
local pendingController=C.Style(pending,{states={hover={root={width=90,alpha=.5}}}})
pendingController._conditionApplyNeeded=true;inject=true
ok=pcall(pendingController.SetState,pendingController,"hover",true)
check(not ok and pendingController._conditionApplyNeeded and not pendingController.applying,"failed native application retains pending conditional work and clears its guard")
inject=false;pendingController:SetState("hover",true)
check(not pendingController._conditionApplyNeeded and not pendingController._applyFailed and pending:GetWidth()==90,"same-state retry completes pending conditional work")
pendingController:SetState("hover",false)
check(pending:GetWidth()==30 and pending:GetAlpha()==1,"a partial write failure never becomes the business baseline")
local bindTarget=frame(inner);local bindController=C.Style(bindTarget,{style={root={width=44}}})
local conditional=Library.CompileUtilities({})({conditions={{minWidth=500,base={root={width=60}}}}})
local bind=ctx._BindConditions;local releaseCount=ctx.releases
ctx._BindConditions=function(self,controller,selectors) bind(self,controller,selectors);error("injected bind failure") end
ok=pcall(bindController.Configure,bindController,conditional,bindController.slots,nil)
check(not ok and not bindController.configured and not bindController.configuring and not bindController.testSelectors and not bindController.conditionSelectors and ctx.releases==releaseCount+1,"existing-controller bind failure clears partial conditional sources")
ctx._BindConditions=bind;bindController:Configure(conditional,bindController.slots,nil);bindController:Apply(true)
check(bindTarget:GetWidth()==60,"condition binding retries after a failed configure")
local content=frame(inner);content.label=C.Text(content,"Responsive content",14)
local contentLayout={invalidations=0,Invalidate=function(self) self.invalidations=self.invalidations+1 end}
content._lycheeLayoutFields={points=contentLayout}
local contentRules=Library.CompileUtilities({})({conditions={{minWidth=500,base={label={fontSize=20,wordWrap=true,spacing=2}}}}})
ctx:_BindFixedElement(content,contentRules,{root=content,label=content.label})
check(contentLayout.invalidations>0,"conditional label metrics invalidate the semantic host's actual flex owner")
local contentCount=contentLayout.invalidations;content.styleController:Apply(true)
check(contentLayout.invalidations==contentCount,"unchanged conditional label metrics do not invalidate flow again")
print("LycheeUI responsive rules: "..assertions.." assertions passed")
