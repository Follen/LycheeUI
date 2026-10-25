return function(S,Library,check,near)
 local catalog={
  action={scope="page",slotKinds={root="roundedBox",label="text",icon="texture",surface="surface"}},
  row={template=true,slotKinds={root="box",label="text"}},
  anchor={slotKinds={root="box"}},later={slotKinds={root="box"}},
  parent={slotKinds={root="box",label="text"}},child={slotKinds={root="text"}},
  art={slotKinds={root="texture"}},borrowed={slotKinds={root="text"}},native={slotKinds={root="box"}},
  nested={slotKinds={root="box",child="box"}},
 }
 local ctx=Library:CreateContext({reducedMotion=true,elementDefaults=catalog,utilities={pill={height=30,radius=8},wide={width=160}},elements={
  action={classes="pill wide",base={icon={texture=20,points={{"LEFT","$root","LEFT",4,0}}}},states={hover={label={color="good"}}},variants={compact={base={root={width=175}}}}},
  row={base={root={width=20}},instances={one={base={root={width=30}}},[1]={base={root={width=40}}},["1"]={base={root={width=50}}}}},
  anchor={base={root={points={{"LEFT","@later","RIGHT",4,0}}}}},
  parent={base={label={fontSize=18,color="good",alpha=.3}},states={hover={label={fontSize=20,color="blue"}}}},
  child={base={root={fontSize=24,color="brand"}},states={focus={root={fontSize=28,color="warning"}}}},
  art={states={hover={root={atlas="TestAtlas"}}}},native={base={root={width=60}}},
  borrowed={base={root={fontSize=22,color="brand"}}},nested={base={child={width=50}}},
 }})
 local C=ctx.C
 local button=C.IconButton(UIParent,nil,80);button.icon:SetTexture(10)
 C.Element(button,"action",{scope="page"})
 check(button:GetWidth()==160 and button:GetHeight()==30 and button.radius==8,"startup classes compose geometry without a runtime utility setter")
 check(button.icon:GetTexture()==20 and select(2,button.icon:GetPoint())==button,"fixed slots preserve semantic root anchors")
 button:Fire("OnEnter");check(near(select(2,button.label:GetTextColor()),ctx.Theme.good[2]),"fixed element states join component hover")
 button:SetAvailable(false);check(not button.styleController.active.hover,"disabled suppresses fixed hover")
 button:SetAvailable(true);button:SetWidth(145);button.icon:SetTexture(30);C.ApplyElement(button)
 check(button:GetWidth()==160 and button.icon:GetTexture()==20,"normal business render reapplies startup rules")
 C.ReleaseElement(button);check(button:GetWidth()==145 and button.icon:GetTexture()==30,"normal release retains the latest affected business values")
 C.Element(button,"action");button:SetVariant("compact")
 check(button:GetWidth()==175 and C.ElementValue(button,"root","width",0)==175,"component variants select fixed element variants for paint and measurement")
 local a=CreateFrame("Frame",nil,UIParent);a:SetSize(10,10);C.Element(a,"row",{template="row",key="one"})
 check(a:GetWidth()==30 and ctx:ResolveElementValue("row","root","width",0,"one")==30,"instance rules are available before or after a native row exists")
 C.RekeyElement(a,"three");check(a:GetWidth()==20,"business rekey drops the old instance contribution")
 C.RekeyElement(a,1);check(a:GetWidth()==40,"numeric instance keys stay legal")
 C.RekeyElement(a,"1");check(a:GetWidth()==50,"string instance keys remain distinct from numbers")
 C.ReleaseElement(a);check(a:GetWidth()==10,"release restores only the affected native baseline")
 local anchor=CreateFrame("Frame",nil,UIParent);C.Element(anchor,"anchor")
 local later=CreateFrame("Frame",nil,UIParent);C.Element(later,"later")
 check(select(2,anchor:GetPoint())==later,"late cross-element anchors reconnect when their target is registered")
 check(ctx.elementIndex.later and not ctx.elementIndex.row and not ctx.GetElement,"only referenced anchor identities receive a native lookup index")
 local early=CreateFrame("Frame",nil,UIParent);C.Element(early,"anchor")
 check(select(2,early:GetPoint())==later,"already registered cross-element anchors resolve on first apply")
 local parent=CreateFrame("Frame",nil,UIParent);parent.label=C.Text(parent,"Shared","label")
 C.Element(parent,"parent");C.Element(parent.label,"child")
 C.SetElementState(parent,"hover",true);C.ApplyElement(parent)
 check(select(2,parent.label:GetFont())==24 and parent.label:GetAlpha()==.3,"a direct root wins its properties while parent aliases retain unrelated properties")
 C.SetElementState(parent.label,"focus",true);C.ApplyElement(parent)
 check(select(2,parent.label:GetFont())==28,"a parent refresh cannot displace a direct root state")
 C.ReleaseElement(parent.label)
 check(select(2,parent.label:GetFont())==20,"releasing a direct entrance reveals the active parent contribution")
 C.ReleaseElement(parent);check(select(2,parent.label:GetFont())==14 and parent.label:GetAlpha()==1,"releasing both entrances recovers their native baseline: "..select(2,parent.label:GetFont()).."/"..parent.label:GetAlpha())
 local art=C.Icon(UIParent,16);art:SetTexture(123);art:SetTexCoord(.1,.8,.2,.9);C.Element(art,"art")
 C.SetElementState(art,"hover",true);C.SetElementState(art,"hover",false)
 check(art:GetTexture()==123 and not art:GetAtlas() and select(1,art:GetTexCoord())==.1,"state art restores texture and crop as one native value")
 art:SetAtlas("OriginalAtlas");C.ApplyElement(art);C.SetElementState(art,"hover",true);C.SetElementState(art,"hover",false)
 check(art:GetAtlas()=="OriginalAtlas","business atlas rebinding updates the affected state baseline")
 local native=CreateFrame("Frame",nil,UIParent);native:SetWidth(30);local owned=true;local owner={IsOwned=function() return owned end}
 C.Element(native,"native",{owner=owner});owned=false;native:SetWidth(90);C.ApplyElement(native);C.ReleaseElement(native)
 check(native:GetWidth()==90,"a lost native lease forbids both state writes and release restoration")
 local outer=CreateFrame("Frame",nil,UIParent);local child=CreateFrame("Frame",nil,outer);child:SetSize(10,10)
 local layout=C.Row(outer,{{frame=child,width=20,height=10}},{width=100,height=20});layout:Layout()
 C.Element(outer,"nested",{slots={root=outer,child=child}});child:SetWidth(20);C.ApplyElement(outer)
 check(child:GetWidth()==50,"fixed child dimensions participate in owning layouts")
 local shell=C.Field(UIParent,200,40);local input=CreateFrame("EditBox",nil,UIParent);input:SetSize(180,20)
 local lease=C.NativeInput(shell,input);C.Element(input,"borrowed",{owner=lease});input:Fire("OnEditFocusGained")
 check(select(2,input:GetFont())==22 and near(select(1,input:GetTextColor()),ctx.Theme.brand[1]),"native focus preserves owned fixed text presentation: "..select(2,input:GetFont()).."/"..select(1,input:GetTextColor()).."/"..tostring(lease:IsOwned()))
 C.ReleaseElement(input);lease:Release()
 local field=Library:GetElementField("action.base.icon.texture",catalog)
 check(field and field.inherited and not field.ref and Library.ResolveStyleValue("art.tga",field,ctx.Theme)=="art.tga","static metadata supports literal art without creating live indices")
 check(not Library:ValidateElements({action={classes="missing"}},catalog,ctx.Theme),"unknown classes fail at startup validation")
 local malformed={
  7,{base={label=7}},{base=7},{states={hover=7}},{states=7},
  {variants={compact=7}},{variants=7},{instances=7},{instances={one=7}},
  {base={label={[true]=12}}},{states={[true]={label={alpha=.5}}}},
 }
 for _,entry in ipairs(malformed) do
  local ok,valid,message=pcall(Library.ValidateElements,Library,{action=entry},catalog,ctx.Theme)
  check(ok and valid==false and type(message)=="string","malformed imported element structures return a validation message instead of throwing")
 end
 local ok,valid,message=pcall(Library.ValidateUtilities,Library,{broken={base={root=7}}},ctx.Theme)
 check(ok and valid==false and type(message)=="string","malformed utility slot properties use the shared nonthrowing validation boundary")
 for _,id in ipairs({"menu","menu.list"}) do for _,short in ipairs({true,false}) do for _,mode in ipairs({"height","constraint"}) do
  local height=short and 80 or 400
  local property=mode=="height" and "height" or short and "maxHeight" or "minHeight"
  local menus=Library:CreateContext({reducedMotion=true,elements={[id]={base={root={[property]=height+(id=="menu" and 8 or 0)}}}}})
  local trigger=menus.C.ChoiceTrigger(UIParent,160);local entries={}
  for index=1,8 do entries[index]={value=index,label="Item "..index} end
  menus:OpenMenu(trigger,entries)
  local popup=menus:GetMenu();local list=popup.list
  check(list:GetHeight()==height and list.gutter==(short and menus.C.listRightInset or 0),"menu gutter follows the final "..id.." element "..property)
  check(list.slider:IsShown()==short,"menu scrolling follows the final "..id.." element "..property)
  menus:Hide()
 end end end
 for _,id in ipairs({"menu","menu.list"}) do for _,small in ipairs({true,false}) do
  local width=small and 100 or 400;local property=small and "maxWidth" or "minWidth"
  local menus=Library:CreateContext({reducedMotion=true,elements={[id]={base={root={[property]=width}}}}})
  local trigger=menus.C.ChoiceTrigger(UIParent,160)
  menus:OpenMenu(trigger,{{value=1,label="Item"}})
  local popup=menus:GetMenu();local inset=menus.Theme.menuPadding*2
  check(popup:GetWidth()==width+(id=="menu.list" and inset or 0) and popup.list:GetWidth()==width-(id=="menu" and inset or 0),"menu content geometry follows "..id.." element "..property)
  menus:Hide()
 end end
 check(ctx.Motion:Count()==0,"fixed rules add no idle scheduler jobs")
 ctx:Hide()
end
