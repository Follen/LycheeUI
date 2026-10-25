return function(S,library,check,near)
 local ctx=library:CreateContext({reducedMotion=true})
 local C,T=ctx.C,ctx.Theme
 local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(400,300)
 local clicks=0
 local button=C.Button(parent,"Choice",80,function() clicks=clicks+1 end,{variant="compact"})
 button:SetActive(true);button:Fire("OnEnter")
 check(button:GetHeight()==30 and button.label.font[2]==14 and button.fill.color==T.secondaryContainer,"compact options use the shared label role and selected style")
 button:SetAvailable(false);button:Fire("OnClick")
 check(clicks==0 and button:GetAlpha()==.38 and not button.hover:IsShown(),"style variants preserve disabled input and feedback")
 button:SetAvailable(true);button:SetActive(false);button:SetVariant("primary");button:Fire("OnEnter")
 check(button.fill.color==T.primaryHover and button:GetHeight()==40,"variant changes replace compact geometry and primary feedback together")
 button:SetVariant("text");button:SetActive(true);button:Fire("OnLeave")
 check(button.fill.color==T.transparent and button.label.color[1]==T.brand[1],"selected text actions keep a transparent surface")
 button:SetVariant("ghost");button:Fire("OnClick")
 check(clicks==1,"changing styles keeps the original click handler")
 local iconButton=C.IconButton(parent,"plus",32)
 iconButton:Fire("OnEnter");iconButton:Fire("OnLeave")
 check(iconButton.icon.texture:GetAlpha()==1 and not iconButton.icon.texture.desaturated,"action glyphs retain their original color and alpha across hover")
 do
  local icon=C.Icon(parent,24)
  local desaturate,color,alpha=icon.SetDesaturated,icon.SetVertexColor,icon.SetAlpha
  local getColor,getAlpha=icon.GetVertexColor,icon.GetAlpha
  -- Native float32 readback differs slightly from the Lua input numbers.
  local function native(value)
   if value==.9 then return .89999997615814209 elseif value==.98 then return .98000001907348633
   elseif value==.72 then return .72000002861022949 end
   return value
  end
  function icon:GetVertexColor() local r,g,b,a=getColor(self);return native(r),native(g),native(b),native(a) end
  function icon:GetAlpha() return native(getAlpha(self)) end
  local grayWrites,colorWrites,alphaWrites=0,0,0
  function icon:SetDesaturated(value) grayWrites=grayWrites+1;desaturate(self,value) end
  function icon:SetVertexColor(...) colorWrites=colorWrites+1;color(self,...) end
  function icon:SetAlpha(value) alphaWrites=alphaWrites+1;alpha(self,value) end
  for _,state in ipairs({{false,false,.9,.72},{false,true,.98,.9},{true,false,1,1}}) do
   ctx:SetIconState(icon,state[1],state[2]);grayWrites,colorWrites,alphaWrites=0,0,0
   for i=1,10 do ctx:SetIconState(icon,state[1],state[2]) end
   check(grayWrites==0 and colorWrites==0 and alphaWrites==0,"ten unchanged icon states skip native setters despite float32 color and alpha readback")
   check(icon:IsDesaturated()==not state[1] and near(select(1,icon:GetVertexColor()),state[3]) and near(icon:GetAlpha(),state[4]),"icon state transitions retain selected and hovered grayscale, tint and opacity")
  end
  ctx:SetIconState(icon,false,false)
  color(icon,.2,.3,.4);desaturate(icon,false);alpha(icon,.3)
  grayWrites,colorWrites,alphaWrites=0,0,0;ctx:SetIconState(icon,false,false)
  check(grayWrites==1 and colorWrites==1 and near(select(1,icon:GetVertexColor()),.9) and icon:IsDesaturated() and near(icon:GetAlpha(),.72),"icon styling corrects external native color and grayscale edits and restores opacity after the color write")
  alpha(icon,.3);grayWrites,colorWrites,alphaWrites=0,0,0;ctx:SetIconState(icon,false,false)
  check(grayWrites==0 and colorWrites==0 and alphaWrites==1 and near(icon:GetAlpha(),.72),"an external opacity edit is corrected without rewriting unchanged icon color or grayscale")
  -- Retail stores texture channels as bytes, then returns float32 values.
  native=function(value)
   local byte=math.floor(value*255+.5)
   if byte==230 then return .9019608497619629 elseif byte==250 then return .9803922176361084
   elseif byte==184 then return .7215686440467834 end
   return byte/255
  end
  for _,state in ipairs({{false,false,.9,.72},{false,true,.98,.9},{true,false,1,1}}) do
   ctx:SetIconState(icon,state[1],state[2]);grayWrites,colorWrites,alphaWrites=0,0,0
   for i=1,10 do ctx:SetIconState(icon,state[1],state[2]) end
   check(grayWrites==0 and colorWrites==0 and alphaWrites==0,"ten unchanged icon states skip setters with real eight-bit texture readback")
   check(select(1,icon:GetVertexColor())==native(state[3]) and icon:GetAlpha()==native(state[4]) and icon:IsDesaturated()==not state[1],"eight-bit icon states retain the original setter's final tint, opacity and grayscale")
   local colorByte,alphaByte=math.floor(state[3]*255+.5),math.floor(state[4]*255+.5)
   color(icon,(colorByte-1)/255,state[3],state[3]);grayWrites,colorWrites,alphaWrites=0,0,0
   ctx:SetIconState(icon,state[1],state[2])
   check(grayWrites==0 and colorWrites==1 and select(1,icon:GetVertexColor())==native(state[3]) and icon:GetAlpha()==native(state[4]),"an external adjacent color byte is corrected without accepting a half-byte tolerance")
   alpha(icon,(alphaByte-1)/255);grayWrites,colorWrites,alphaWrites=0,0,0
   ctx:SetIconState(icon,state[1],state[2])
   check(grayWrites==0 and colorWrites==0 and alphaWrites==1 and icon:GetAlpha()==native(state[4]),"an external adjacent alpha byte is corrected without rewriting unchanged tint")
  end
 end
 local choice=C.ChoiceTrigger(parent,180,function() end,{radius=8,height=52})
 choice:SetExpanded(true);choice:SetRadius(10)
 check(choice.focus.regions[4]:GetWidth()==10 and choice.focusInner.regions[4]:GetWidth()==9,"changing a choice radius also updates its expanded outline")
 local checkboxChanges=0
 local checkBox
 checkBox=C.Checkbox(parent,function(value,widget) checkboxChanges=checkboxChanges+1;check(value and widget==checkBox,"checkbox callback reports native checked state and owner") end)
 checkBox:SetValue(true);checkBox:SetValue(false)
 check(checkboxChanges==0 and not checkBox.mark:IsShown(),"programmatic checkbox rebinding is silent and clears the mark")
 checkBox:SetChecked(true);checkBox:Fire("OnClick");checkBox:Fire("OnEnter")
 check(checkboxChanges==1 and checkBox.fill.color==T.primaryHover and checkBox.mark:IsShown(),"checkbox click and hover share the selected state")
 checkBox:SetAvailable(false);checkBox:Fire("OnClick")
 check(checkboxChanges==1 and checkBox.fill.color==T.primary,"disabled checkbox retains selection without hover or callback")
 local list=C.List(parent,200,96,48)
 list:SetStyle({rowHeight=44,radius=8,titleSize=16,titleLineHeight=22,singleLine=true,titleX=48,alternateRows=false})
 list:SetItems({1,2,3,4},function(row,key) ctx:SetText(row.title,key) end)
 local row=list.rows[1]
 check(row:GetHeight()==44 and not row.meta:IsShown() and row.title:GetPoint()=="LEFT","single-line list styling applies to the row pool")
 list:SetPixelOffset(48,false)
 check(row.key==2 and not row.meta:IsShown() and not row.alternate:IsShown(),"recycled rows keep the configured list appearance")
 list:SetStyle({singleLine=false,titleX=12,rowHeight=64,titleSize=18,titleLineHeight=24})
 check(row.meta:IsShown() and row.title:GetPoint()=="TOPLEFT","switching back to two lines restores metadata and title placement")
 C.Columns(list,{{key="value",x=130,width=60,size=16,lineHeight=24}},110)
 check(row.columns.value:GetHeight()==24,"numeric columns accept an explicit line box independently of font size")
 local surface=C.Surface(parent,{variant="floating"})
 surface:SetHovered(true);surface:Hide();surface:SetHovered(false);surface:Show()
 check(surface.fill.color==T.floatingSurface and near(surface.fill.regions[1]:GetAlpha(),.60),"floating surfaces restore the resting material without compounding alpha")
 local anchor=C.Button(parent,"Menu",80)
 check(ctx:GetMenu()==nil and not ctx:IsMenuOpen() and not ctx:IsMenuHovered(),"menu queries are safe before lazy construction")
 ctx:OpenMenu(anchor,{{value=1,label="One",checked=true}})
 local menu=ctx:GetMenu();menu.mouseOver=true
 check(ctx:GetMenuAnchor()==anchor and ctx:IsMenuOpen(anchor) and ctx:IsMenuHovered(anchor) and menu.list.rows[1].check:IsShown(),"menu queries and shared checkmark reflect the current owner")
 ctx:CloseMenuFor(anchor)
 check(not ctx:IsMenuOpen() and not ctx:IsMenuHovered() and ctx:GetMenuAnchor()==nil,"closing clears menu queries while retaining its reusable frame")
 ctx:Hide();check(ctx.Motion:Count()==0,"component lifecycle leaves no idle animation jobs")

 local animated=library:CreateContext()
 local AC,M=animated.C,animated.Motion
 local toggle=AC.Button(parent,"Animated",100,nil,{variant="compact"})
 toggle:SetActive(true);M:Tick(.07)
 local alpha=toggle.fill:GetAlpha()
 check(alpha>0 and alpha<1,"selection fades without delaying the active state")
 toggle:SetAvailable(true)
 check(near(toggle.fill:GetAlpha(),alpha),"unchanged availability does not finish an active selection transition")
 toggle:SetActive(false);toggle:SetActive(true)
 check(near(toggle.fill:GetAlpha(),alpha),"rapid active reversal keeps the displayed opacity")
 M:Tick(.14);check(toggle.fill:GetAlpha()==1,"selection reaches its complete tonal fill")
 toggle:Hide();check(M:Count()==0,"hiding a selected button releases its visual work")

 local nav=AC.Navigation(parent,"Page",160)
 nav:SetActive(true);M:Tick(.02);nav:Hide()
 check(M.jobs[nav.mark]==nil and nav.mark:GetAlpha()==1,"hiding Navigation settles its selected mark and releases the child task")
 nav:Show();nav:SetActive(false);M:Tick(.02);nav:Hide()
 check(M.jobs[nav.mark]==nil and nav.mark:GetAlpha()==0 and not nav.mark:IsShown(),"hiding Navigation settles a fading-out mark without a residual child task")
 local switch=AC.Check(parent,"Switch")
 for _,value in ipairs({true,false}) do
  switch:Show();switch:SetValue(value,true);M:Tick(.02);switch:Hide()
  local endpoint=value and 21 or 5
  check(M.jobs[switch.knob]==nil and switch.knob._slideX==endpoint and select(4,switch.knob:GetPoint())==endpoint,"hiding Check settles its knob at the current boolean state")
 end
 check(M:Count()==0 and not M.running,"hidden Navigation and Check controls leave no finite driver work")

 local changed,chosen=0,nil
 local booleanSegments=AC.Segmented(parent,240,{{value=false,label="No"},{value=true,label="Yes"}},function(value) changed=changed+1;chosen=value end)
 booleanSegments:SetValue(false)
 check(booleanSegments.buttons[1].value==false and booleanSegments.buttons[1].active and not booleanSegments.buttons[2].active and changed==0,"Segmented preserves false values in silent programmatic selection")
 booleanSegments.buttons[2]:Fire("OnClick","LeftButton");booleanSegments.buttons[1]:Fire("OnClick","LeftButton")
 check(changed==2 and chosen==false and booleanSegments.value==false and booleanSegments.buttons[1].active,"Segmented delivers false values unchanged through user callbacks")
 booleanSegments:Hide()

 local segments=AC.Segmented(parent,300,{{value="a",label="A"},{value="b",label="B"}})
 segments:SetValue("a");M:Tick(.2)
 local highlight=segments.selection
 local firstX=select(4,highlight:GetPoint())
 local nodes=#S.nodes
 segments:SetValue("b")
 check(select(4,highlight:GetPoint())==firstX and segments.buttons[2].active,"segmented input commits before its passive background moves")
 M:Tick(.08);local middleX=select(4,highlight:GetPoint())
 check(middleX>firstX and middleX<153,"the shared segmented background passes through intermediate positions")
 segments:SetValue("b");segments.buttons[2]:SetAvailable(true)
 check(select(4,highlight:GetPoint())==middleX,"same-value and availability refreshes preserve an in-flight segmented transition")
 segments:SetValue("a");check(select(4,highlight:GetPoint())==middleX,"segmented reversal starts at the current background position")
 M:Tick(.2);check(select(4,highlight:GetPoint())==firstX and #S.nodes==nodes,"repeated selection reuses all visual objects and reaches the requested endpoint")
 segments:SetValue("b");segments:Hide();check(M:Count()==0,"hiding the segmented control cancels its background motion")

 local rail=AC.List(parent,200,96,48)
 rail:SetGutter(0);rail:SetStyle({rowHeight=44,radius=8,alternateRows=false,selectionMotion=true})
 rail:SetItems({1,2,3,4},function(row,key) animated:SetText(row.title,key) end)
 rail:Select(1);M:Tick(.2);rail:Select(2);M:Tick(.08)
 local middleY=select(5,rail.indicator:GetPoint())
 check(middleY<0 and middleY>-48 and not rail.rows[2].selected:IsShown(),"navigation moves one background while every row and label keeps its own slot")
 rail:Select(1);check(select(5,rail.indicator:GetPoint())==middleY,"navigation reversal does not jump back to a row boundary")
 rail:SetPixelOffset(48,false)
 check(not rail.indicator:IsShown(),"scrolling a selected row out of the pool removes its highlight before row reuse")
 rail:Hide();M:Tick(.2);check(M:Count()==0,"hidden navigation leaves no animation work")
 rail:Show();rail:Select(2);M:Tick(.2);rail:Hide();rail:Show();M:Tick(.2)
 check(rail.selectedKey==2 and rail.indicator:IsShown(),"showing a retained navigation list restores its selected background")
 rail:Hide();rail:Select(3)
 check(M:Count()==0,"rebinding a hidden navigation list applies selection without starting a driver")
 local hidden=AC.List(parent,200,96,48)
 hidden:SetItems({1,2},function() end);hidden:Hide();hidden:Select(1)
 check(M:Count()==0 and hidden.rows[1].selected:GetAlpha()==1,"hidden menu refresh settles row markers without animation work")

 do
  local owner=library:CreateContext();local motion=owner.Motion
  local list=owner.C.List(parent,300,400,40)
  local ids={};for i=1,100 do ids[i]=i end
  local renders=0
  list:SetItems(ids,function() renders=renders+1 end)
  motion:Start("warm",function() return true end);motion:Tick(0)
  local shown,hit,mouse,ranges=0,0,0,0
  local function ObserveShown(region)
   local set=region.SetShown
   region.SetShown=function(self,value) shown=shown+1;set(self,value) end
  end
  for _,row in ipairs(list.rows) do
   ObserveShown(row)
   for _,panel in ipairs({row.alternate,row.hover}) do for _,region in ipairs(panel.regions) do ObserveShown(region) end end
   local setHit,enable=row.SetHitRectInsets,row.EnableMouse
   row.SetHitRectInsets=function(self,...) hit=hit+1;setHit(self,...) end
   row.EnableMouse=function(self,value) mouse=mouse+1;enable(self,value) end
  end
  ObserveShown(list.slider)
  local setRange=list.slider.SetMinMaxValues
  list.slider.SetMinMaxValues=function(self,...) ranges=ranges+1;setRange(self,...) end
  local nodes=#S.nodes;renders=0
  list:SetPixelOffset(20,true);for i=1,14 do motion:Tick(.01) end
  check(shown==0 and ranges==0,"within-row scrolling does not resubmit unchanged native visibility or scrollbar range")
  check(hit==28 and mouse==1,"within-row scrolling writes only the two changed edge crops and the newly visible row input state")
  check(#S.nodes==nodes and renders==0,"within-row scrolling keeps the original row objects and business bindings")
  motion:Tick(.001)
  local slice=list.rows[2].alternate.regions[2];slice:Hide();list.rows[2].alternate:Show()
  check(slice:IsShown(),"Panel visibility still reconciles an individually changed public slice")
  list:SetPixelOffset(0,false);list:SetPixelOffset(80,true);motion:Tick(.02)
  list:SetItems({1,2},function() end)
  check(list.pixelOffset==0 and not motion.jobs[list] and not motion.running,"shrinking data to a fitting list immediately stops its now-motionless scroll task")
  list:SetItems(ids,function() end);list:SetPixelOffset(80,false);list:SetPixelOffset(0,true);motion:Tick(.02)
  local current=list.pixelOffset;local originalJob=motion.jobs[list]
  list:SetItems({1,2,3,4,5,6,7,8,9,10,11},function() end)
  check(list.pixelOffset<current and motion.jobs[list]==originalJob,"a smaller range retains the existing scroll trajectory while visible movement remains")
  motion:Tick(.04);local phase=.06/.14
  check(near(list.pixelOffset,80*(1-phase*(2-phase))),"data shrink does not restart or shorten a scroll that still has visible movement")
  motion:Tick(.2);check(list.pixelOffset==0 and not motion.jobs[list],"the retained scroll reaches its original target and stops")
  list:Hide()
 end
end
