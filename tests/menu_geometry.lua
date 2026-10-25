-- Real generic menu, element rules and pooled list geometry; no product code.
-- Run from LycheeUI: lua tests/menu_geometry.lua
local S=dofile("tests/stubs.lua");S.Install()
local private={};local file=assert(io.open("embeds.xml"));local xml=file:read("*a");file:close()
for name in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(name))("MenuGeometry",private) end
local Library=private.LycheeUI
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function y(row) local _,a,b,_,v=row:GetPoint();return type(a)=="number" and b or v end
local entries={{value="one",label="One"},{value="two",label="Two"},{value="three",label="Three"}}
local contexts={}
local function Fixture(rule,items,options,utilities)
 local ctx=Library:CreateContext({reducedMotion=true,utilities=utilities,elements={["menu.row"]=rule or {}}})
 contexts[#contexts+1]=ctx
 local anchor=ctx.C.ChoiceTrigger(UIParent,200);ctx.C.Element(anchor,"anchor")
 local selected
 ctx:OpenMenu(anchor,items or entries,function(value) selected=value end,options)
 return ctx,ctx:GetMenu(),anchor,function() return selected end
end
local instanceKey="anchor/string:one"
local ctx,menu,anchor,picked=Fixture({instances={[instanceKey]={base={root={height=80}}}}})
check(menu.list.rows[1]:GetHeight()==80 and y(menu.list.rows[2])==-80 and y(menu.list.rows[3])==-120,"instance bodies determine real menu row placement without overlap")
check(menu.list:GetHeight()==160 and menu:GetHeight()==168 and select(2,menu.list.slider:GetMinMaxValues())==0,"the popup viewport fits the actual sum of mixed body heights")
check(menu.list.rows[1].key==1 and ctx.elements[menu.list.rows[1]].key==instanceKey,"menu business index and owner/value element identity remain distinct")
menu.list.rows[2]:Fire("OnMouseDown","LeftButton");menu.list.rows[2]:Fire("OnClick","LeftButton")
check(picked()=="two" and not menu:IsShown(),"semantic height mapping preserves the original menu selection value")
ctx:OpenMenu(anchor,entries)
check(menu.list.rows[1]:GetHeight()==80 and y(menu.list.rows[3])==-120,"closing and reopening restores the same owner instance geometry")
local other=ctx.C.ChoiceTrigger(UIParent,200);ctx.C.Element(other,"other")
ctx:OpenMenu(other,entries)
check(menu.list.rows[1]:GetHeight()==40 and y(menu.list.rows[3])==-80 and menu.list:GetHeight()==120,"reusing the popup for another anchor releases the old owner's instance height")
ctx:OpenMenu(other,{})
check(ctx:GetMenuAnchor()==other,"an empty open request leaves the current menu contract unchanged")

local base,flat=Fixture({base={root={height=60}}})
check(flat.list.rows[1]:GetHeight()==60 and y(flat.list.rows[3])==-120 and flat.list:GetHeight()==180,"base height changes body geometry and popup height together")
local hidden,collapsed=Fixture({instances={[instanceKey]={base={root={height=0}}}}})
check(collapsed.list.rows[1].key==2 and collapsed.list.rows[2].key==3 and y(collapsed.list.rows[2])==-40,"zero instance height consumes neither a pool slot nor a blank gap")
check(collapsed.list.viewportHeight==80 and collapsed:GetHeight()==88,"collapsed items are excluded from the popup viewport")
local zero,empty=Fixture({base={root={height=0}}})
check(empty.list.rowHeight>0 and empty.list.contentHeight==0 and empty.list.viewportHeight==0 and empty:GetHeight()==8,"all-zero menus keep a positive pool stride and only their outer padding")
check(select(2,empty.list.slider:GetMinMaxValues())==0 and #empty.list.geometryIndices==0,"all-zero content has no scroll range or visible item index")
for _,row in ipairs(empty.list.rows) do check(row.key==nil,"all-zero rules leave every native pool row unbound") end

local utility,classed=Fixture({classes="tall"},nil,nil,{tall={height=70}})
check(classed.list:GetHeight()==210 and classed.list.rows[1]:GetHeight()==70 and y(classed.list.rows[2])==-70,"template classes participate in the same complete content geometry")
local variant,varied=Fixture({variants={tall={base={root={height=80}}}}})
varied.list.rows[1].styleController:SetVariant("tall")
check(varied.list.rows[1]:GetHeight()==80 and y(varied.list.rows[2])==-80 and varied.list:GetHeight()==160,"activating a row height variant synchronously resizes its menu")
varied.list.rows[1].styleController:SetVariant(nil)
check(y(varied.list.rows[2])==-40 and varied.list:GetHeight()==120,"clearing a height variant restores the menu geometry")
local states,active=Fixture({base={root={minHeight=30,maxHeight=100}},states={selected={root={height=60}},hover={root={height=80}},pressed={root={height=120}}}})
active.list.clip.mouseOver=true;local row=active.list.rows[1];row.mouseOver=true;row:Fire("OnEnter")
check(row:GetHeight()==80 and y(active.list.rows[2])==-80 and active.list:GetHeight()==160,"hover height reflows both following rows and popup viewport")
row:Fire("OnMouseDown","LeftButton")
check(row:GetHeight()==100 and active.list:GetHeight()==180,"pressed height respects maxHeight while resizing the popup")
row:Fire("OnMouseUp","LeftButton");row:Fire("OnLeave")
check(row:GetHeight()==40 and active.list:GetHeight()==120,"ending transient states restores the default menu body")
active.list:Select(2,false)
check(active.list.rows[2]:GetHeight()==60 and y(active.list.rows[3])==-100 and active.list:GetHeight()==140,"selected business key controls the selected height and menu size")
local bounded,minimum=Fixture({base={root={height=0,minHeight=30}}})
check(minimum.list:GetHeight()==90 and y(minimum.list.rows[3])==-60,"minHeight is applied before collapse and menu sizing")
local maximum,maxZero=Fixture({base={root={height=80,maxHeight=0}}})
check(maxZero.list.contentHeight==0 and maxZero.list.viewportHeight==0,"a zero maxHeight collapses all menu bodies")
local initial,initiallySelected=Fixture({states={selected={root={height=80}}}},nil,{selectedValue="one"})
check(initiallySelected.list.selectedKey==1 and y(initiallySelected.list.rows[2])==-80 and initiallySelected.list.viewportHeight==160,"initial selection is resolved before sizing a short popup")
local onlySelected,only=Fixture({base={root={height=0}},states={selected={root={height=80}}}},nil,{selectedValue="two"})
check(only.list.selectedKey==2 and only.list.rows[1].key==2 and only.list.viewportHeight==80,"selected state can reveal one row in an otherwise zero-height template")
local checkedContext,checkedMenu,checkedAnchor=Fixture({base={root={height=0}},states={checked={root={height=80}}}},nil,{kind="select",selectedValue="two"})
check(checkedMenu.list:GetContentHeight()==80 and checkedMenu.list.viewportHeight==80 and checkedMenu.list.rows[1].key==2,"initial checked state reveals a selected item before any native row is rendered")
check(checkedMenu.list.rows[1]._checked and checkedMenu.list.rows[1].check:IsShown(),"the revealed checked row uses the same native presentation state")
checkedContext:CloseMenu();checkedContext:OpenMenu(checkedAnchor,entries,nil,{kind="select"})
check(checkedMenu.list:GetContentHeight()==0 and checkedMenu.list.viewportHeight==0,"removing selectedValue clears old checked state and restores the all-zero geometry")
checkedContext:CloseMenu();checkedContext:OpenMenu(checkedAnchor,entries,nil,{kind="select",selectedValue="two"})
check(checkedMenu.list.rows[1].key==2 and checkedMenu.list.viewportHeight==80,"a checked item reappears after closing an all-zero menu")
local uncheckedContext,uncheckedMenu,uncheckedAnchor=Fixture({states={checked={root={height=0}}}},nil,{kind="select",selectedValue="two"})
check(uncheckedMenu.list:GetContentHeight()==80 and uncheckedMenu.list.rows[1].key==1 and uncheckedMenu.list.rows[2].key==3,"zero checked height collapses the selected item without cyclic rebinds")
uncheckedContext:CloseMenu();uncheckedContext:OpenMenu(uncheckedAnchor,entries,nil,{kind="select",selectedValue="one"})
check(uncheckedMenu.list:GetContentHeight()==80 and uncheckedMenu.list.rows[1].key==2,"reopening with another selection releases the previous row's checked state")
local marked={{value="one",label="One",checked=true},{value="two",label="Two"},{value="three",label="Three",checked=true}}
local markedContext,multiple=Fixture({base={root={height=0}},states={checked={root={height=80}}}},marked)
check(multiple.list:GetContentHeight()==160 and multiple.list.rows[1].key==1 and multiple.list.rows[2].key==3,"multiple explicitly checked items contribute geometry without a selectedValue")
local disabledEntries={{value="one",label="One"},{value="two",label="Two",disabled=true},{value="three",label="Header",header=true},{value="four",label="Four"}}
local disabledContext,disabledMenu=Fixture({states={disabled={root={height=0}}}},disabledEntries)
check(disabledMenu.list:GetContentHeight()==80 and disabledMenu.list.rows[1].key==1 and disabledMenu.list.rows[2].key==4,"disabled items and headers use the same collapsed geometry")
local disabledTall,tallDisabled=Fixture({base={root={height=0}},states={selected={root={height=60}},checked={root={height=100}},disabled={root={height=80}}}},disabledEntries,{kind="select",selectedValue="two"})
check(tallDisabled.list:GetContentHeight()==160 and tallDisabled.list.rows[1].key==2 and tallDisabled.list.rows[2].key==3,"disabled state wins over selected and checked according to the fixed state order")
check(not tallDisabled.list.rows[1]:IsEnabled() and not tallDisabled.list.rows[2]:IsEnabled(),"disabled and header presentation matches their measured state")
disabledEntries[2].disabled=false;disabledEntries[3].header=false
disabledMenu.list:RefreshGeometry();tallDisabled.list:RefreshGeometry()
check(disabledMenu.list:GetContentHeight()==160,"explicitly clearing stable disabled states reveals the existing items")
check(tallDisabled.list:GetContentHeight()==100 and tallDisabled.list.rows[1].key==2 and tallDisabled.list.rows[1]:IsEnabled(),"a cleared disabled state exposes checked geometry and resets the native enabled state")
local toggleItems={{value="one",label="One",checked=true},{value="two",label="Two"}}
local toggleChecked,toggleMenu=Fixture({states={checked={root={height=80}}}},toggleItems)
check(toggleMenu.list:GetContentHeight()==120 and toggleMenu.list.rows[1]._checked,"explicit checked data starts with the measured body and native state")
toggleItems[1].checked=false;toggleMenu.list:RefreshGeometry()
check(toggleMenu.list:GetContentHeight()==80 and not toggleMenu.list.rows[1]._checked,"position-only refresh consumes checked=false for geometry and the native tracked state")
toggleItems[1].checked=true;toggleMenu.list:Refresh()
check(toggleMenu.list:GetContentHeight()==120 and toggleMenu.list.rows[1].check:IsShown(),"the menu's complete row refresh updates checked content and height together")
toggleItems[1].checked=false;toggleMenu.list:Refresh()
check(toggleMenu.list:GetContentHeight()==80 and not toggleMenu.list.rows[1].check:IsShown(),"a complete menu refresh removes the check and its configured extra height")
local otherChecked=checkedContext.C.ChoiceTrigger(UIParent,200);checkedContext.C.Element(otherChecked,"otherChecked")
checkedContext:OpenMenu(otherChecked,entries,nil,{kind="select",selectedValue="one"})
check(checkedMenu.list.rows[1].key==1 and checkedMenu.list.viewportHeight==80,"cross-owner reuse does not retain the old checked item")

local many={};for index=1,100 do many[index]={value=index,label="Entry "..index} end
local farChecked,checkedLast=Fixture({base={root={height=0}},states={checked={root={height=80}}}},many,{kind="select",selectedValue=100})
check(checkedLast.list:GetContentHeight()==80 and checkedLast.list.rows[1].key==100 and #checkedLast.list.rows<20,"offscreen item 100 can become the only checked row without allocating the full item set")
check(checkedLast.list.selectedKey==100 and checkedLast.list.pixelOffset==0 and checkedLast.list.rows[1]._hitVisible,"locate uses the checked item's collapsed-prefix geometry")
local hiddenChecked,checkedHidden=Fixture({states={checked={root={height=0}}}},many,{kind="select",selectedValue=100})
check(checkedHidden.list:GetContentHeight()==3960 and checkedHidden.list.pixelOffset==3560,"a collapsed offscreen checked item is excluded from locate and the scroll range")
local farDisabledEntries={};for index=1,100 do farDisabledEntries[index]={value=index,label="Entry "..index,disabled=index==100} end
local farDisabled,disabledLast=Fixture({base={root={height=0}},states={disabled={root={height=80}}}},farDisabledEntries,{selectedValue=100})
check(disabledLast.list:GetContentHeight()==80 and disabledLast.list.rows[1].key==100 and not disabledLast.list.rows[1]:IsEnabled(),"offscreen disabled state contributes its body before a native row exists")
for _,height in ipairs({600,640}) do
 local expanded=Library:CreateContext({reducedMotion=true,elements={["menu.list"]={base={root={height=height}}}}})
 contexts[#contexts+1]=expanded
 local trigger=expanded.C.ChoiceTrigger(UIParent,200)
 expanded:OpenMenu(trigger,many,nil,{width=216})
 local popup=expanded:GetMenu();local list=popup.list;local last=height/40
 check(list.viewportHeight==height,"public menu.list height sets the requested viewport")
 check(list.rows[last] and list.rows[last].key==last and list.rows[last]._hitVisible and y(list.rows[last])==-(height-40),"fixed menu pools cover the complete enlarged viewport without blank tail space")
 check(#list.rows<=last+2 and select(2,list.slider:GetMinMaxValues())==4000-height,"enlarged fixed menus retain a bounded viewport pool and complete scroll range")
 list:Select(100,true)
 local finalRow;for _,row in ipairs(list.rows) do if row.key==100 then finalRow=row end end
 check(finalRow and finalRow._hitVisible and list.pixelOffset==4000-height,"the enlarged viewport still locates the final item")
 local allocated=#S.nodes;expanded:CloseMenu();expanded:OpenMenu(trigger,many,nil,{width=216})
 list:SetPixelOffset(0,false)
 check(#S.nodes==allocated and list.rows[last].key==last,"reopening a larger fixed viewport reuses its expanded pool")
end
local far,distant=Fixture({instances={["anchor/number:100"]={classes="tall"}}},many,{selectedValue=100},{tall={height=120}})
check(distant.list.contentHeight==4080 and select(2,distant.list.slider:GetMinMaxValues())==3680,"offscreen item 100 contributes its instance-class height before allocation")
check(distant.list.selectedKey==100 and distant.list.pixelOffset==3680 and distant.list.geometryOffsets[100]==3960,"initial locate uses the numeric business key and complete mapped prefix geometry")
local final
for _,item in ipairs(distant.list.rows) do if item.key==100 then final=item end end
check(final and final:GetHeight()==120 and final._hitVisible and #distant.list.rows<20,"locating the last configured body uses only the viewport pool")
distant.list:SetPixelOffset(0,false)
check(distant.list.rows[1].key==1 and distant.list.rows[1]:GetHeight()==40,"scrolling away releases the last instance's geometry")
local nodes=#S.nodes;distant.list:SetPixelOffset(3680,false);distant.list:SetPixelOffset(0,false)
check(#S.nodes==nodes,"warm scrolling reuses the same bounded native pool")
local distantState,selected=Fixture({states={selected={root={height=120}}}},many,{selectedValue=100})
check(selected.list.contentHeight==4080 and selected.list.pixelOffset==3680,"an offscreen initial selected state uses business identity rather than the mapped element identity")
local overflow,overflowing=Fixture({states={hover={root={height=80}}}},many)
local measured=0;local measureWidth=overflowing.measure.GetStringWidth
overflowing.measure.GetStringWidth=function(self) measured=measured+1;return measureWidth(self) end
overflowing.list.clip.mouseOver=true;overflowing.list.rows[1].mouseOver=true;overflowing.list.rows[1]:Fire("OnEnter")
check(overflowing.list:GetHeight()==400 and select(2,overflowing.list.slider:GetMinMaxValues())==3640 and measured==0,"overflowing hover updates scroll geometry without remeasuring an unchanged viewport")
local long,single=Fixture({base={root={height=800}}},{{value="one",label="Long item"}})
check(single.list.viewportHeight==400 and single.list.rows[1]:GetHeight()==800 and select(2,single.list.slider:GetMinMaxValues())==400,"a single body taller than the viewport retains its full scrollable geometry")
single.list:SetPixelOffset(400,false)
check(single.list.pixelOffset==400 and single.list.rows[1]._hitVisible,"the lower slice of an oversized single item remains reachable")

local normal,plain=Fixture()
check(not plain.list.geometryOffsets and plain.list.rowHeight==40 and plain.list:GetHeight()==120 and plain:GetHeight()==128,"an unconfigured menu preserves the fixed geometry fast path and original dimensions")
check(plain.list._elementHeightStates==nil,"unconfigured menus allocate no projected geometry state table")
normal:CloseMenu();normal:OpenMenu(normal.C.ChoiceTrigger(UIParent,200),entries)
local newAnchor=normal:GetMenuAnchor();normal:CloseMenu();local warmed=#S.nodes
normal:OpenMenu(newAnchor,entries);normal:CloseMenu();normal:OpenMenu(newAnchor,entries)
check(#S.nodes==warmed,"default repeated menu opens allocate no additional native objects")
local body=menu.list.rows[1]:GetHeight();local width=menu:GetWidth();local fontNodes=#S.nodes
ctx:SetFont("another-font",1.5)
check(menu.list.rows[1]:GetHeight()==body and menu:GetWidth()>=width and select(2,menu.list.rows[1].title:GetFont())==24 and #S.nodes==fontNodes,"font reflow keeps row geometry coherent while recomputing labels without new controls")
local idle,inert=Fixture({base={label={fontSize=18}},states={hover={label={color={1,0,0}}}}})
local sizeCalls=0;local setSize=inert.SetSize
inert.SetSize=function(self,...) sizeCalls=sizeCalls+1;return setSize(self,...) end
local widthCalls=0;local originalWidth=inert.measure.GetStringWidth
inert.measure.GetStringWidth=function(self) widthCalls=widthCalls+1;return originalWidth(self) end
inert.list.clip.mouseOver=true;inert.list.rows[1].mouseOver=true
inert.list.rows[1]:Fire("OnEnter");inert.list.rows[1]:Fire("OnLeave")
check(sizeCalls==0 and widthCalls==0,"hover without a body-height change does not resize or remeasure the popup")
check(inert.list._elementHeightStates==nil and not inert.list.geometryOffsets,"pure label rules keep the fixed fast path without projected geometry states")
for _,context in ipairs(contexts) do context:Hide() end
print("LycheeUI menu geometry: "..count.." checks passed")
