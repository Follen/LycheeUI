-- Run from LycheeUI: lua tests/list_geometry.lua
local S=dofile("tests/stubs.lua");S.Install()
local private={};local f=assert(io.open("embeds.xml"));local xml=f:read("*a");f:close()
for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(file))("GeometryFixture",private) end
local Library=private.LycheeUI;local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function y(row) local _,a,b,_,v=row:GetPoint();return type(a)=="number" and b or v end
local function Build(rule,keys,utilities)
 local ctx=Library:CreateContext({reducedMotion=true,utilities=utilities,elementDefaults={row={template=true,scope="test",slotKinds={root="box",label="text"}}},elements={row=rule or {}}})
 local list=ctx.C.List(UIParent,200,100,40);list.elementTemplate="row";list.elementScope="test";list:SetStyle({rowHeight=36});list:SetItems(keys or {1,2,3},function() end)
 return ctx,list
end
local ctx,list=Build();check(not list.geometryOffsets and y(list.rows[2])==-40,"unconfigured rows keep fixed geometry")
list:SetRowHeight(50,46);check(list.rows[1]:GetHeight()==46 and y(list.rows[2])==-50,"business stride and body setters remain immediate")
list:SetRowHeightResolver(function(key,_,fallback) return key==2 and 100 or fallback end)
check(y(list.rows[3])==-154 and select(2,list.slider:GetMinMaxValues())==100,"business height resolver participates in scroll geometry")
list:SetRowHeightResolver(nil);check(not list.geometryOffsets and y(list.rows[3])==-100,"clearing a business resolver restores fixed placement")
local one,variable=Build({instances={[1]={base={root={height=80}}}}})
check(variable.rows[1]:GetHeight()==80 and y(variable.rows[2])==-84 and y(variable.rows[3])==-124,"startup instance geometry preserves internal body gaps")
check(select(2,variable.slider:GetMinMaxValues())==60,"variable content includes every body and only internal gaps")
local ids={};for i=1,100 do ids[i]=i end
local distant,far=Build({instances={[100]={base={root={height=120}}}}},ids)
check(select(2,far.slider:GetMinMaxValues())==3980,"offscreen fixed instance height participates before native allocation")
check(#far.rows<20 and not distant.elementIndex.row,"offscreen configuration creates neither a row per key nor a live query index")
far:Select(100,true);local selected;for _,row in ipairs(far.rows) do if row.key==100 then selected=row end end
check(selected and selected:GetHeight()==120 and far.pixelOffset==3960,"locate uses configured prefix geometry for a row taller than the viewport")
check(selected._hitVisible and selected:GetHitRectInsets()>=0,"the visible slice remains clickable")
far:SetPixelOffset(99999,false);check(far.pixelOffset==3980 and select(4,selected:GetHitRectInsets())==0,"final body can scroll completely into view")
far:SetPixelOffset(0,false);check(far.rows[1].key==1 and far.rows[1]:GetHeight()==36,"pool rebind removes the prior instance height")
local states,active=Build({states={hover={root={height=90}},selected={root={height=70}}}})
active:Select(1,false);check(active.rows[1]:GetHeight()==70 and y(active.rows[2])==-74,"selected height moves following rows")
active:Select(nil,false);active.clip.mouseOver=true;active.rows[1].mouseOver=true;active.rows[1]:Fire("OnEnter")
check(active.rows[1]:GetHeight()==90 and y(active.rows[2])==-94,"hover geometry reflows synchronously")
active.rows[1]:Fire("OnLeave");check(active.rows[1]:GetHeight()==36 and y(active.rows[2])==-40,"leaving hover restores the current business body height")
local short,small=Build({base={root={height=10}}},ids);check(#small.rows>=10 and small.rows[8].key==8,"short static rows extend only visible capacity and overscan")
local grown=#S.nodes;small:SetPixelOffset(30,false);small:SetPixelOffset(0,false);check(#S.nodes==grown,"warm scrolling reuses the same high water pool")
local utility,tall=Build({classes="tall"},nil,{tall={height=70}});check(tall.rows[1]:GetHeight()==70 and y(tall.rows[2])==-74,"named startup utility height participates in list geometry")
local limits,bounded=Build({base={root={minHeight=60,maxHeight=65}},states={pressed={root={height=100}},disabled={root={height=62}}}})
check(bounded.rows[1]:GetHeight()==60,"static minimum constraint participates before placement")
limits.C.SetElementState(bounded.rows[1],"pressed",true);check(bounded.rows[1]:GetHeight()==65,"pressed geometry respects maximum height")
limits.C.SetElementState(bounded.rows[1],"disabled",true);check(bounded.rows[1]:GetHeight()==62,"disabled suppresses transient pressed geometry")
local collapsed,zero=Build({instances={[2]={base={root={height=0}}}}});check(zero.rows[1].key==1 and zero.rows[2].key==3 and y(zero.rows[2])==-40,"a zero height instance is collapsed without a native row slot")
local all,empty=Build({base={root={height=0}}},ids);check(empty.contentHeight==0 and select(2,empty.slider:GetMinMaxValues())==0 and #empty.geometryIndices==0,"an all-zero template has no visible pool or range")
local keys,mixed=Build({instances={[1]={base={root={height=80}}},["1"]={base={root={height=100}}}}},{1,"1",2})
check(mixed.rows[1].key==1 and mixed.rows[1]:GetHeight()==80 and mixed.rows[2].key=="1" and mixed.rows[2]:GetHeight()==100,"numeric and string keys keep distinct configured heights")
local classed,classRows=Build({instances={[100]={classes="tall"}}},ids,{tall={height=120}})
check(select(2,classRows.slider:GetMinMaxValues())==3980 and #classRows.rows<20,"offscreen instance classes enable configured geometry without allocating rows for every key")
classRows:Select(100,true);local last;for _,row in ipairs(classRows.rows) do if row.key==100 then last=row end end
check(last and last:GetHeight()==120 and classRows.pixelOffset==3960,"locating an offscreen classed instance uses the same configured body height")
local variants,variantRows=Build({variants={tall={base={root={height=80}}}}})
variantRows.rows[1].styleController:SetVariant("tall")
check(variantRows.rows[1]:GetHeight()==80 and y(variantRows.rows[2])==-84,"a variant-only height rule enables synchronous row geometry before its first activation")
variantRows.rows[1].styleController:SetVariant(nil)
check(variantRows.rows[1]:GetHeight()==36 and y(variantRows.rows[2])==-40,"leaving a height-only variant restores normal row placement")
local mapped=Library:CreateContext({reducedMotion=true,elementDefaults={row={template=true,scope="test",slotKinds={root="box",label="text"}}},elements={row={instances={["item:100"]={base={root={height=120}}}}}}})
local mappedList=mapped.C.List(UIParent,200,100,40)
local mappedKeys={};for index=1,100 do mappedKeys[index]="business:"..index end
mappedList:SetItems(mappedKeys,function() end)
mapped.C.Element(mappedList,"mappedList",{scope="test",rowTemplate="row",rowElementKey=function(key,index) check(key==mappedKeys[index],"mapped row registration receives its real data index");return "item:"..index end})
mappedList:RefreshGeometry()
check(mapped.elements[mappedList.rows[1]].key=="item:1" and mappedList.rows[1].key=="business:1","late row-template association maps existing element keys without changing business keys")
check(mappedList:GetContentHeight()==4080,"the same mapping resolves offscreen element heights")
mappedList:Select("business:100",true)
local mappedLast;for _,row in ipairs(mappedList.rows) do if row.key=="business:100" then mappedLast=row end end
check(mappedLast and mapped.elements[mappedLast].key=="item:100" and mappedLast:GetHeight()==120,"locate and newly bound pool rows share the same index-aware element mapping")
local projected=Library:CreateContext({reducedMotion=true,utilities={big={height=70}},elementDefaults={row={template=true,scope="test",slotKinds={root="box",label="text"}}},elements={row={variants={tall={base={root={height=90}}}},states={checked={root={height=0}}}}}})
local projectedList=projected.C.List(UIParent,200,150,40)
projected.C.Element(projectedList,"projectedList",{scope="test",rowTemplate="row",rowElementState=function(key,index,name)
 check(name=="checked" or name=="disabled","stable row-state callbacks receive only the finite checked/disabled names")
 if name=="checked" then return false end
end})
projectedList:SetItems({1,2},function() end)
local projectedRow=projectedList.rows[1]
projected.C.Element(projectedRow,"row",{template="row",key=1,scope="test",classes="big"})
check(projectedRow:GetHeight()==70 and y(projectedList.rows[2])==-70,"projected stable states preserve a visible record's explicit classes")
projectedRow.styleController:SetVariant("tall")
check(projectedRow:GetHeight()==90 and y(projectedList.rows[2])==-90,"projected stable states preserve the visible controller's active variant")
for _,context in ipairs({ctx,one,distant,states,short,utility,limits,collapsed,all,keys,classed,variants,mapped,projected}) do context:Hide() end
print("LycheeUI list geometry: "..count.." checks passed")
