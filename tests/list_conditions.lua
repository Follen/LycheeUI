-- Run from LycheeUI: lua tests/list_conditions.lua.
local S=dofile("tests/stubs.lua");S.Install()
local private={};local manifest=assert(io.open("embeds.xml"));local xml=manifest:read("*a");manifest:close()
for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(file))("ListConditions",private) end
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function near(a,b,message) check(math.abs(a-b)<.000001,message) end
local function frame(parent,w,h) local f=CreateFrame("Frame",nil,parent or UIParent);f:SetSize(w or 600,h or 200);return f end
local function idle(ui) return not ui.layoutScheduler or not ui.layoutScheduler.driver or not ui.layoutScheduler.driver:GetScript("OnUpdate") end
local ids={};for i=1,100 do ids[i]=i end
local function build(rule,options)
 options=options or {}
 local ui=LycheeUI:CreateContext({reducedMotion=true,utilities=options.utilities,elementDefaults={row={template=true,slotKinds={root="box",label="text"}},plain={template=true,slotKinds={root="box",label="text"}}},elements={row=rule}})
 local C=ui.C;local outer=frame(nil,600);C.Container(outer,"outer")
 local parent=frame(outer,600);C.Container(parent,"panel")
 local list=C.List(parent,200,100,40);list:SetStyle({rowHeight=36})
 if options.listContainer then C.Container(list,"viewport") end
 C.Element(list,"list",{rowTemplate="row",rowElementState=options.states})
 list:SetItems(ids,function() end);check(ui:FlushLayouts(),"initial conditional list failed")
 return ui,list,parent,outer
end
local function body(list,index) return list.geometryOffsets[index+1]-list.geometryOffsets[index]-list.geometryGap end
local height={container="panel",minWidth=500,base={root={height=80}}}
do
 local ui,list,parent=build({conditions={height}})
 check(list.elementHeights and list._elementHeightConditions,"condition-only row geometry enables one list projection")
 near(list:GetContentHeight(),8396,"all 100 conditional bodies belong to the complete prefix")
 near(select(2,list.slider:GetMinMaxValues()),8296,"scroll range follows every conditional body")
 near(({list.rows[2]:GetPoint()})[3],-84,"visible rows use the same conditional prefix")
 check(#list.rows<20,"offscreen conditions do not allocate one native row per key")
 local projection=list._elementHeightConditions
 local calls=0;local resolve=ui.ResolveListElementHeight
 ui.ResolveListElementHeight=function(self,...) calls=calls+1;return resolve(self,...) end
 parent:SetWidth(400);check(ui:FlushLayouts(),"condition exit failed")
 near(list:GetContentHeight(),3996,"condition exit restores body baseline across all keys")
 check(calls==100,"one container change rebuilds the full prefix only once")
 parent:SetWidth(600);check(ui:FlushLayouts(),"condition reentry failed")
 list:Select(100,true);near(list.pixelOffset,8296,"locate clamps against the complete conditional range")
 local last;for _,row in ipairs(list.rows) do if row.key==100 then last=row end end
 check(last and last:GetHeight()==80 and last._hitVisible,"last conditional body can be reached and hit")
 list:SetPixelOffset(0,false);list:SetPixelOffset(9000,false);ui:FlushLayouts();local nodes=#S.nodes
 for i=1,30 do list:SetPixelOffset(i%2==0 and 0 or 9000,false);ui:FlushLayouts() end
 check(list._elementHeightConditions==projection and #S.nodes==nodes,"warm scrolling retains the same list projection and physical pool")
 list:Clear();check(not list._elementHeightConditions and projection.released,"Clear removes the common subscription and pending job")
 list:SetItems(ids,function() end);ui:FlushLayouts();check(list._elementHeightConditions and list._elementHeightConditions~=projection,"reusing a cleared list binds current dependencies once")
 ui.C.Element(list,"list",{rowTemplate="plain"})
 check(not list._elementHeightConditions and not list.elementHeights and not list.geometryOffsets,"replacing the template removes conditional variable geometry")
 near(list.rows[1]:GetHeight(),36,"ordinary template restores its fixed native body")
 ui.C.Element(list,"list",{rowTemplate="row"});ui:FlushLayouts()
 ui.C.ReleaseElement(list);check(not list._elementHeightConditions and not list.elementTemplate,"releasing the list element clears its row-template subscription")
 near(list:GetContentHeight(),3996,"releasing row-template metadata restores fixed geometry")
end
do
 local ui,list,parent=build({instances={[100]={classes="lastTall"}}},{utilities={lastTall={conditions={{container="panel",minWidth=500,base={root={height=120}}}}}}})
 near(list:GetContentHeight(),4080,"an offscreen-only named utility contributes before its row exists")
 near(select(2,list.slider:GetMinMaxValues()),3980,"offscreen-only conditional height changes range")
 list:Select(100,true);near(list.pixelOffset,3960,"locate uses the offscreen conditional prefix")
 list:SetPixelOffset(0,false);parent:SetWidth(400);ui:FlushLayouts()
 near(list:GetContentHeight(),3996,"offscreen-only dependency updates without a visible matching instance")
end
do
 local ui,list,parent,outer=build({base={root={height=36}},states={selected={root={height=70}},checked={root={height=75}},disabled={root={height=65}}},conditions={
  {container="panel",minWidth=500,base={root={height=80}},states={selected={root={height=100}},checked={root={height=110}},hover={root={height=120}},disabled={root={height=60}}}},
  {when={{container="outer",minWidth=500},{container="viewport",minWidth=150,maxWidth=250}},base={root={height=90,maxHeight=105}}},
 }},{listContainer=true,states=function(key,index,name) if name=="checked" and key==2 or name=="disabled" and key==3 then return true end end})
 list:Select(1,false)
 near(body(list,1),100,"conditional selected follows ordinary selected after all base branches")
 near(body(list,2),105,"checked condition respects a later conditional maximum")
 near(body(list,3),60,"disabled remains the final projected state")
 near(body(list,100),90,"named AND conditions include the list itself in the real row ancestor chain")
 ui.C.SetElementState(list.rows[1],"hover",true);near(body(list,1),105,"hover follows selected and shares prefix constraints")
 outer:SetWidth(400);ui:FlushLayouts();near(body(list,100),80,"AND branch exits when its named outer ancestor changes")
 list:SetRowHeightResolver(function(key,index,fallback) return key==100 and 150 or fallback end)
 parent:SetWidth(400);ui:FlushLayouts();near(body(list,100),36,"ordinary fixed base height retains its priority over the business resolver")
 check(idle(ui),"projected stable states settle without recursive Refresh")
end
do
 local ui,list,parent=build({conditions={{container="missing",minWidth=0,base={root={height=90}}}},variants={tall={conditions={{container="panel",minWidth=500,base={root={height=110}}}}}}})
 near(list:GetContentHeight(),3996,"a missing container never matches")
 list.rows[1].styleController:SetVariant("tall");near(body(list,1),110,"variant-only conditions retain their compiled branch match")
 local other=frame(nil,600);ui.C.Container(other,"missing");list:SetParent(other);ui.C.RebindLayout(list);ui:FlushLayouts()
 near(body(list,100),90,"explicit same-context reparent rebinds the shared ancestor dependency")
 local projection=list._elementHeightConditions;list:Release()
 check(not list._elementHeightConditions and projection.released and idle(ui),"Release removes the projection and leaves no queued shared job")
end
do
 local ui,list,parent=build({conditions={{container="panel",minWidth=500,base={root={minHeight=80}}}}})
 list:SetRowHeightResolver(function(key,index,fallback) return key==100 and 150 or fallback end)
 near(body(list,100),150,"conditional minimum preserves a larger business height")
 parent:SetWidth(400);ui:FlushLayouts();near(body(list,100),150,"condition exit preserves the latest business height resolver")
 near(body(list,1),36,"other rows restore the normal body fallback")
end
do
 local ui,list,parent=build({conditions={{container="panel",minWidth=500,base={root={minHeight=100}}}}})
 list:SetRowTextResolver(function(key) return "Wrapped content "..key end,{batchSize=13,minHeight=36})
 for i=1,30 do if idle(ui) then break end;check(ui:FlushLayouts(),"flow conditions failed") end
 near(list:GetContentHeight(),10396,"flow text applies conditional minHeight to every bounded-batch row")
 parent:SetWidth(400)
 for i=1,30 do if idle(ui) then break end;check(ui:FlushLayouts(),"flow condition exit failed") end
 check(list:GetContentHeight()<10396 and idle(ui),"flow indices invalidate once and settle when a height condition exits")
 ui:SetFont(nil,1.3);for i=1,30 do if idle(ui) then break end;check(ui:FlushLayouts(),"flow font refresh failed") end
 check(idle(ui) and #list.rows<100,"font and condition geometry retain the bounded flow pool")
end
-- Actual native input axes are dependencies even when their placement is owned.
for _,hidden in ipairs({false,true}) do for _,manual in ipairs({false,true}) do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local parent=frame(nil,200,200)
 local a,b=frame(parent,20,20),frame(parent,20,20)
 local item={frame=a};if manual then item.manageHeight=false end
 local layout=C.Column(parent,{item,b},{mode="flex",height="content",gap=5,track=true,includeHidden=hidden});ui:FlushLayouts()
 near(select(5,b:GetPoint()),-25,"initial Column has the native input height")
 a:SetHeight(50);check(not idle(ui),"a native height input must queue tracked Column work")
 check(ui:FlushLayouts(),"tracked native height update failed");near(select(5,b:GetPoint()),-55,"tracked Column follows manual and omitted height axes")
 local prepares=ui.layoutScheduler.prepares;layout:Layout();check(ui:FlushLayouts() and ui.layoutScheduler.prepares==prepares,"own committed sizes do not create a feedback batch")
 layout:Release();check(not a._lycheeLayoutInputs,"release removes native input references")
end end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local parent=frame(nil,200,100)
 local a,b=frame(parent,20,20),frame(parent,20,20)
 local row=C.Row(parent,{a,b},{mode="flex",width="content",gap=5,track=true,includeHidden=true});ui:FlushLayouts()
 a:SetWidth(50);check(not idle(ui) and ui:FlushLayouts(),"omitted native width queues a tracked Row even with includeHidden")
 near(select(4,b:GetPoint()),55,"Row follows its actual native width input")
 row:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local parent=frame(nil,200,100)
 local a,b=frame(parent,20,20),frame(parent,20,20)
 local layout=C.Row(parent,{{frame=a,width=20,height=20},{frame=b,width=20,height=20}},{mode="flex",track=true,includeHidden=true});ui:FlushLayouts()
 check(not a._lycheeLayoutSignals or #a._lycheeLayoutSignals.entries==0,"fully explicit managed dimensions need no child size subscription")
 layout:Release()
 local _,inside=C.Box(a,{layout="row",items={frame(a,10,20)},height="content",track=true})
 local outside=C.Column(parent,{{frame=a,manageHeight=false},b},{mode="flex",height="content",gap=5,track=true});ui:FlushLayouts()
 inside:SetOptions({padding={0,10,0,10}});ui:FlushLayouts()
 near(select(5,b:GetPoint()),-45,"a child content Box updates its unmanaged parent input axis")
end
print("LycheeUI conditional list geometry: "..count.." checks passed")
