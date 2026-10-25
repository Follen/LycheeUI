-- Offline lifetime/allocation diagnostics only. Optional first argument loads
-- a frozen library directory for a RED comparison; no game GC is involved.
local S=dofile("tests/stubs.lua");S.Install()
local source=arg[1] or ".";local private={}
local file=assert(io.open(source.."/embeds.xml"));local xml=file:read("*a");file:close()
for name in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(source.."/"..name))("ListMemory",private) end
local checks,failures=0,0
local function check(value,message) checks=checks+1;assert(value,message) end
local function count(values) local n=0;for _ in pairs(values or {}) do n=n+1 end;return n end
local function case(name,run)
 local ok,message=pcall(run)
 if not ok then failures=failures+1;print("[FAIL] "..name..": "..tostring(message)) else print("[PASS] "..name) end
end
local ids={};for i=1,1000 do ids[i]=i end
local function build(kind)
 local rule=kind=="catalog" and {} or kind=="fixed" and {base={root={height=60}}} or kind=="classes" and {classes="h-64"} or {conditions={{container="panel",minWidth=0,base={root={height=60}}}}}
 local ui=LycheeUI:CreateContext({reducedMotion=true,elementDefaults={row={template=true,slotKinds={root="box",label="text"}}},elements={row=rule}})
 local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(600,200);ui.C.Container(parent,"panel")
 return ui,parent
end
local function list(ui,parent)
 local result=ui.C.List(parent,200,100,40);result:SetStyle({rowHeight=36});ui.C.Element(result,"list",{rowTemplate="row"});result:SetItems(ids,function() end);ui:FlushLayouts();return result
end
case("released numeric prefixes",function()
 local ui,parent=build("conditional");local result=list(ui,parent)
 check(#result.geometryOffsets==1001,"fixture did not build a complete prefix")
 result:Release()
 check(not result.geometryOffsets and not result.geometryIndices and not result._geometryOffsets and not result._geometryIndices,"explicit Release retained numeric prefixes")
 check(not ui.elements[result] and not result.elementTemplate,"explicit Release retained the list element/template")
end)
case("released row subscribers",function()
 local ui,parent=build("conditional");local observed=setmetatable({},{__mode="k"})
 for round=1,5 do
  local result=list(ui,parent)
  for _,row in ipairs(result.rows) do observed[row.styleController]=true end
  result:Release();result:Hide();result:Release()
  check(#parent._lycheeLayoutSignals.entries==0,"released list rows retained container subscriptions")
  check(count(ui._conditionalControllers)==0,"released list rows remained conditional owners")
 end
 collectgarbage("collect")
 check(count(observed)==0,"released row style controllers survived offline collection")
 check(not ui.layoutScheduler or not ui.layoutScheduler.driver or not ui.layoutScheduler.driver:GetScript("OnUpdate"),"released lists retained a task")
end)
for _,kind in ipairs({"catalog","fixed","conditional","classes"}) do case("rekey "..kind,function()
 local ui,parent=build(kind);local host=CreateFrame("Frame",nil,parent);host:SetSize(50,30)
 ui.C.Element(host,"row",{template="row",key=1})
 local controller=host.styleController;local records=controller and controller.records;local matches=controller and controller.conditionMatches
 for key=2,20 do ui.C.RekeyElement(host,key) end
 check(ui.elements[host].key==20,"rekey skipped the business identity")
 if controller then check(controller.records==records and controller.conditionMatches==matches,"equivalent fixed rules rebuilt their records or matches") end
 collectgarbage("collect");collectgarbage("stop");local before=collectgarbage("count")
 for key=21,1020 do ui.C.RekeyElement(host,key) end
 local allocated=collectgarbage("count")-before;collectgarbage("restart")
 check(allocated<8,"equivalent rekey allocated "..allocated.." KiB")
 check(ui.elements[host].key==1020,"allocation diagnostic skipped identity updates")
end) end
case("different rules, variants and slots",function()
 local ui=LycheeUI:CreateContext({reducedMotion=true,elementDefaults={row={template=true,slotKinds={root="box",child="box"}},other={template=true,slotKinds={root="box",child="box"}}},elements={row={base={root={height=40},child={width=20}},variants={tall={base={root={height=80}}}},instances={one={base={root={width=80}}},three={base={root={width=120}}}}},other={base={root={width=160}}}}})
 local C=ui.C;local host=CreateFrame("Frame",nil,UIParent);host:SetSize(50,30)
 local a,b=CreateFrame("Frame",nil,host),CreateFrame("Frame",nil,host);a:SetWidth(7);b:SetWidth(9);local slots={root=host,child=a}
 C.Element(host,"row",{template="row",key="one",slots=slots});local controller=host.styleController
 C.RekeyElement(host,"three");check(host:GetWidth()==120,"instance rules were skipped")
 C.RekeyElement(host,"plain");check(host:GetWidth()==50,"instance exit lost the business baseline")
 controller:SetVariant("tall");local records=controller.records;C.RekeyElement(host,"next")
 check(host:GetHeight()==80 and controller.records==records,"equivalent rekey changed the active variant")
 slots.child=b;C.RekeyElement(host,"last");check(a:GetWidth()==7 and b:GetWidth()==20,"a changed native slot was skipped")
 C.RekeyElement(host,"other","other");check(host:GetWidth()==160,"a changed template was skipped")
end)
case("Clear still reuses its physical pool",function()
 local ui,parent=build("conditional");local result=list(ui,parent)
 local row=result.rows[1];local controller=row.styleController;local records=controller.records
 row.pressedKey=row.key;row._inside=true;row._pressed=true
 result:Clear();result:SetItems(ids,function() end);ui:FlushLayouts()
 check(result.rows[1]==row and row.styleController==controller and controller.records==records,"Clear discarded its reusable fixed row binding")
 check(row.pressCancelled and not row._inside and not row._pressed,"rebind retained the preceding pressed/hover identity")
 result:Select(2,false);check(result.selectedKey==2,"rekey changed list selection behavior")
 result:Release()
end)
case("terminal callbacks and pressed key",function()
 local ui=LycheeUI:CreateContext({reducedMotion=true});local observed=setmetatable({},{__mode="k"})
 local selected=0
 local function callback(name)
  local payload={name=name};observed[payload]=name
  return function() if name=="select" then selected=selected+1 end;return payload end
 end
 local result=ui.C.List(UIParent,200,100,40,callback("select"),callback("hover"),{initializeRow=callback("constructor initializer"),onGeometryChanged=callback("geometry")})
 result:SetRowInitializer(callback("registered initializer"))
 result:SetItems({1},callback("renderer"));result:Clear();result:SetItems({2},callback("replacement renderer"))
 result.clip.mouseOver=true;result.rows[1]:Fire("OnMouseDown","LeftButton");result.rows[1]:Fire("OnClick","LeftButton")
 check(selected==1,"Clear discarded a live selection callback")
 local key={old="pressed business identity"};observed[key]="pressed key"
 result:SetItems({key},function() end);result.rows[1].pressedKey=key;key=nil
 result:Release();collectgarbage("collect")
 check(count(observed)==0,"terminal release retained a callback payload or pressed key")
 check(not result.initializeRow and not result.rows[1].pressedKey,"terminal callback/key fields remain")
 result.rows[1]:Fire("OnClick","LeftButton");check(selected==1,"released native row fired an application callback")
end)
case("new business key projects current state",function()
 for _,state in ipairs({"checked","disabled"}) do
  local ui=LycheeUI:CreateContext({reducedMotion=true,elementDefaults={row={template=true,slotKinds={root="box",label="text"}}},elements={row={base={root={height=20}},states={checked={root={height=80}},disabled={root={height=40}},selected={root={height=100}}}}}})
  local result=ui.C.List(UIParent,200,100,20)
  ui.C.Element(result,"list",{rowTemplate="row",rowElementState=function(key,index,name) if key==1 and name==state then return true end end})
  result:SetItems({1},function() end);local row=result.rows[1]
  result:Select(1,false);result:SetItems({2},function() end)
  check(row.key==2 and not row._checked and row:IsEnabled() and not row._selected,"new key inherited the preceding checked/disabled/selected identity")
  check(row:GetHeight()==20 and result:GetContentHeight()==20,"new key inherited state geometry")
  result:Release()
 end
 local ui=LycheeUI:CreateContext({reducedMotion=true,elementDefaults={row={template=true,slotKinds={root="box"}}},elements={row={states={disabled={root={height=30}}}}}})
 local result=ui.C.List(UIParent,200,100,20);result:SetRowInitializer(function(row) row:SetEnabled(false) end)
 ui.C.Element(result,"list",{rowTemplate="row",rowElementState=function(key,index,name) if key==1 and name=="disabled" then return false end end})
 result:SetItems({1},function() end);check(result.rows[1]:IsEnabled(),"explicit enabled projection was not applied")
 result:SetItems({2},function() end);check(not result.rows[1]:IsEnabled(),"new key lost the physical row's original disabled default")
 result:Release()
end)
case("released semantic anchor references",function()
 local ui=LycheeUI:CreateContext({reducedMotion=true});local host=CreateFrame("Frame",nil,UIParent)
 ui.C.Element(host,"anchored",{classes={base={root={points={{"LEFT","@later","RIGHT",0,0}}}}}})
 check(ui.elementReferences.later[host],"semantic anchor fixture lacks its source reference")
 ui.C.ReleaseElement(host)
 check(not ui.elementReferences.later[host] and not ui.elements[host],"released element remained in a semantic reference index")
end)
print("LycheeUI list memory: "..checks.." checks, "..failures.." failures")
os.exit(failures==0 and 0 or 1)
