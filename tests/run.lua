-- Run from the LycheeUI directory: lua tests/run.lua. No client or addon packages.
local S=dofile("tests/stubs.lua");S.Install()
local manifest=assert(io.open("embeds.xml","r"));local xml=manifest:read("*a");manifest:close()
local function Embed(addon)
 local private={}
 for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(file))(addon,private) end
 return private
end
local coldNodes=#S.nodes
local private=Embed("FirstHost")
local library=_G.LycheeUI
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function near(a,b) return math.abs(a-b)<.00001 end
check(#S.nodes==coldNodes,"loading embedded definitions creates no native objects")
check(private.LycheeUI==library and library.version==10000 and library.versionString=="1.0.0","the completed manifest exposes V1.0.0")
check(library.media=="Interface\\AddOns\\FirstHost\\Libs\\LycheeUI\\Media\\","the embedded default follows its installed host")
local theme,factory=library.Theme,library.CreateComponents
local second=Embed("SecondHost")
check(_G.LycheeUI==library and second.LycheeUI==library and library.Theme==theme and library.CreateComponents==factory,"a second copy reuses the completed definitions")
check(#S.nodes==coldNodes,"a second embedded copy creates no context, frame or driver")
local reduced=false
local released,left=0,0
local a=library:CreateContext({reducedMotion=function() return reduced end,text={on="开",off="关"},onRowRelease=function() released=released+1 end,onRowLeave=function() left=left+1 end})
local b=library:CreateContext({reducedMotion=true})
local C,M=a.C,a.Motion
local ownAssets=library:CreateContext({addon="SecondHost"})
local customAssets=library:CreateContext({media="Interface\\AddOns\\CustomSkin\\Art\\"})
check(ownAssets.Theme.media=="Interface\\AddOns\\SecondHost\\Libs\\LycheeUI\\Media\\" and customAssets.Theme.media=="Interface\\AddOns\\CustomSkin\\Art\\","consumers choose their own embedded or custom asset path")
check(a.Theme.media==library.media and a.Theme.media~=customAssets.Theme.media,"a context asset override never changes another consumer")
check(library:CreateContext({addon="LycheeUI"}).Theme.media=="Interface\\AddOns\\LycheeUI\\Media\\","the optional development addon keeps its direct media path")
check(#S.nodes==coldNodes,"explicit contexts defer all native objects until controls or work need them")
local firstButton,secondButton=a.C.Button(UIParent,"One"),a.C.Button(UIParent,"Two")
check(firstButton.SetVariant==secondButton.SetVariant and firstButton.SetExpanded==secondButton.SetExpanded,"buttons in one context share stateless methods")
local task=function() return false end;M:Start("embedding",task);local driver=M.driver;local beforeEmbed=#S.nodes
Embed("ThirdHost")
check(a.C==C and a.Motion==M and M.driver==driver and M.jobs.embedding==task and #S.nodes==beforeEmbed,"another copy preserves the current context, task and driver")
library.version=10001;Embed("OlderHost")
check(library.version==10001 and library.CreateComponents==factory,"an older incoming version leaves a newer library untouched")
library.Context.oldRevisionExtension=function() end
library.version=47;Embed("UpgradeHost")
check(library.Context.oldRevisionExtension==nil and a.oldRevisionExtension~=nil,"upgrades expose only current context methods while retaining existing context prototypes")
check(_G.LycheeUI==library and library.version==10000 and a.C==C and a.Motion==M and M.jobs.embedding==task,"V1.0.0 replaces pre-release copies while preserving live context ownership")
check(a.Theme.media=="Interface\\AddOns\\FirstHost\\Libs\\LycheeUI\\Media\\" and library:CreateContext().Theme.media=="Interface\\AddOns\\UpgradeHost\\Libs\\LycheeUI\\Media\\","an upgrade keeps old context assets and uses the new provider for future defaults")
check(#S.nodes==beforeEmbed,"upgrading definitions allocates no native objects")
M:Stop("embedding")
check(a.inputs~=b.inputs and a.Motion.jobs~=b.Motion.jobs,"contexts must not share owners")
check(a.Theme.width==nil and a.Theme.contentHeight==nil and a.Theme.logoSize==nil,"product window composition is absent from shared theme defaults")
check(near(a.Theme.surface[1],24/255) and near(a.Theme.surfaceLow[1],36/255) and near(a.Theme.surfaceContainer[1],44/255) and near(a.Theme.surfaceHigh[1],52/255) and near(a.Theme.secondaryContainer[1],68/255),"the five resting surfaces are 18, 24, 2c, 34 and 44")
check(near(a.Theme.surfaceHighest[1],52/255+(1-52/255)*13/255) and near(a.Theme.surfaceLowHover[1],36/255+(1-36/255)*13/255),"hover colors are derived from the owning surface, not extra resting panels")
local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(1160,840)
a.frame=parent
local defaultList=C.List(parent,300,192)
check(defaultList.slider:GetThumbTexture()==defaultList.slider.thumb and near(defaultList.slider.thumb.fill[1],a.Theme.accent[1]) and near(defaultList.slider.thumb.fill[2],a.Theme.accent[2]),"lists use the shared native scrollbar and theme accent")
local ownScrollBar=C.ScrollBar(parent)
local scrollValue;ownScrollBar:SetScript("OnValueChanged",function(_,value) scrollValue=value end);ownScrollBar:SetMinMaxValues(0,100);ownScrollBar:SetValue(25)
check(scrollValue==25 and ownScrollBar:GetThumbTexture()==ownScrollBar.thumb,"custom scrolling keeps native value callbacks with the shared scrollbar")
defaultList:SetItems({1,2},function(row,key) a:SetText(row.title,"Player "..key);a:SetText(row.meta,"Class and specialization") end)
local defaultRow=defaultList.rows[1]
local titleTop=-select(3,defaultRow.title:GetPoint())
local metaAnchor,_,metaY=defaultRow.meta:GetPoint()
local metaTop=metaAnchor=="BOTTOMLEFT" and defaultRow:GetHeight()-metaY-defaultRow.meta:GetHeight() or -metaY
check(titleTop>=8 and defaultRow:GetHeight()-metaTop-defaultRow.meta:GetHeight()>=8 and metaTop-titleTop-defaultRow.title:GetHeight()>=4,"the default two-line list keeps both line boxes and their padding inside the row highlight")
check(defaultList.rowHeight==64 and defaultRow.title.font[2]==18 and defaultRow.title:GetHeight()==24 and defaultRow.meta.font[2]==14 and defaultRow.meta:GetHeight()==20,"default content list uses 18/24 titles and 14/20 metadata within the 64px row")
C.Columns(defaultList,{{key="score",x=200,width=60}},180)
check(defaultRow.columns.score.font[2]==14 and defaultRow.columns.score:GetHeight()==20 and defaultRow.columns.score.justify=="RIGHT","default numeric columns use 14/20 while retaining their right-aligned boundary")
local typography=library:CreateContext({theme={listTitleSize=20,listTitleLineHeight=28,listMetaSize=16,listMetaLineHeight=22}})
local customList=typography.C.List(parent,300,144,72)
check(customList.rows[1].title.font[2]==20 and customList.rows[1].title:GetHeight()==28 and customList.rows[1].meta.font[2]==16 and customList.rows[1].meta:GetHeight()==22,"content lists consume all four context typography tokens")
local panelHost=CreateFrame("Frame",nil,parent);panelHost:SetSize(100,80)
local firstPanel=C.Panel(panelHost,"primary",20);local secondPanel=b.C.Panel(panelHost,"good",30)
check(firstPanel.SetColor==C.Panel(parent,"primary",20).SetColor,"panels share their methods within each context")
panelHost:SetSize(20,10)
check(firstPanel.regions[4]:GetWidth()==5 and secondPanel.regions[4]:GetWidth()==5,"one resize dispatcher updates panels from different contexts on a shared parent")
local lowHover=C.Panel(parent,{1,1,1,.05},12)
M:Alpha(lowHover,.7,.1,0);M:Tick(.05)
local uniformAlpha=true
for _,region in ipairs(lowHover.regions) do
 uniformAlpha=uniformAlpha and near(region:GetAlpha(),lowHover:GetAlpha()*.05)
 uniformAlpha=uniformAlpha and near(region.vertex[4],lowHover:GetAlpha()*.05)
end
check(uniformAlpha,"animated translucent panel uses one material-alpha composition for corners and center")
M:StopAll();check(near(lowHover:GetAlpha(),.7) and near(lowHover.regions[4]:GetAlpha(),.035),"StopAll settles motion alpha without losing material alpha")
lowHover:SetColor({1,1,1,.1});check(near(lowHover:GetAlpha(),.7) and near(lowHover.regions[1]:GetAlpha(),.07) and near(lowHover.regions[4]:GetAlpha(),.07),"changing panel color preserves motion alpha and updates every slice equally")
lowHover:SetColor({.24,.24,.24,.1})
local uniformRGB=true
for _,region in ipairs(lowHover.regions) do
 uniformRGB=uniformRGB and region:GetTexture()==(region.corner and a.Theme.media.."rounded-corner.tga" or 130871) and region.fill==nil and near(region.vertex[1],.24) and near(region.vertex[2],.24) and near(region.vertex[3],.24)
end
check(uniformRGB,"panel center and corners use white image textures with identical vertex RGB tint")
do
 local panel=C.Panel(parent,{.2,.3,.4,.5},12)
 local rgbWrites,alphaWrites=0,0
 for _,region in ipairs(panel.regions) do
  local color,alpha=region.SetVertexColor,region.SetAlpha
  region.SetVertexColor=function(self,...) rgbWrites=rgbWrites+1;color(self,...) end
  region.SetAlpha=function(self,...) alphaWrites=alphaWrites+1;alpha(self,...) end
 end
 panel:SetColor({.2,.3,.4,.5});panel:SetAlpha(1)
 check(rgbWrites==0 and alphaWrites==0,"equal panel appearance does not resubmit seven slices")
 local tint={.4,.5,.6,.5};panel:SetColor(tint)
 check(rgbWrites==7 and alphaWrites==0,"RGB-only color changes preserve the existing material alpha without extra writes")
 tint[1]=.7;panel:SetColor(tint)
 check(rgbWrites==14 and near(panel.regions[1].vertex[1],.7),"in-place animation color updates are compared by components, not table identity")
 panel:SetAlpha(.6);tint[4]=.25;panel:SetColor(tint)
 check(alphaWrites==14 and near(panel:GetAlpha(),.6) and near(panel.regions[7]:GetAlpha(),.15),"motion and material alpha still compose across independent updates")
 M:Color(panel,{.1,.2,.3,.25},.1);M:Tick(.05)
 check(alphaWrites==14,"a color animation does not resubmit unchanged alpha on each slice")
 M:StopAll()
end
local label=C.Text(parent,"Line",20);C.SetLineHeight(label,20,true);C.SetLineHeight(label,20,true)
check(label.spacing<0 and near(label:GetLineHeight(),20) and label:GetHeight()==20,"line boxes measure native height and do not accumulate spacing")
local flow=C.Text(parent,"Two lines",12,a.Theme.text,nil,18)
check(near(flow:GetLineHeight(),18) and flow.h==0,"optional text line height retains automatic multiline height")
local auto=C.Text(parent,"Automatic",14);check(auto.spacing==nil and auto.h==0,"old text calls retain native automatic height")
local nativeEdit=CreateFrame("EditBox",nil,parent);nativeEdit:SetFont("font",14,"")
check(nativeEdit.GetLineHeight==nil,"EditBox substitute follows actual missing GetLineHeight API")
C.SetLineHeight(nativeEdit,20);local measureNodes=#S.nodes
check(near(nativeEdit.spacing,20-14*1.2),"EditBox spacing uses matching-font FontString metrics")
nativeEdit:SetFont("second-font",18,"");C.SetLineHeight(nativeEdit,22)
check(near(nativeEdit.spacing,22-18*1.2) and #S.nodes==measureNodes,"EditBox measurements reuse one label and refresh changed fonts")
local wrongType,message=pcall(C.SetLineHeight,parent,20)
check(not wrongType and message:find("expects a FontString or EditBox",1,true),"line height rejects unrelated Frames instead of inventing metrics")
local field=C.Field(parent,220,44);check(#a.inputs==0 and field.box==nil,"native field shell does not create or register replacement input")
field:SetFocused(true);local fieldNodes=#S.nodes;field:SetFocused(false,true)
check(not field.focus:IsShown() and field.fill.color==a.Theme.surfaceHighest,"native shell hover uses shared surface")
field:SetFocused(true);field:SetFocused(false);check(#S.nodes==fieldNodes and field.fill:IsShown(),"native field focus reuses all visual regions")
local innerAbove=true
for i,region in ipairs(field.inner.regions) do innerAbove=innerAbove and region.layer==field.focus.regions[i].layer and region.sublevel>field.focus.regions[i].sublevel end
check(innerAbove,"focused field inner fill has explicit precedence above every focus-ring slice")
local modalEdit=C.Edit(parent,200,44,false,false,"modal")
check(modalEdit.fill.color==a.Theme.surfaceLow,"modal edit starts on lower surface")
modalEdit:SetFocused(false,true);check(modalEdit.fill.color==a.Theme.surfaceContainer,"modal field hover uses container")
modalEdit:SetFocused(true);check(modalEdit.inner.color==a.Theme.field and modalEdit.focus:IsShown(),"modal field focus uses field surface and shared focus ring")
check(C.RoleButton==nil and C.Roster==nil and a.SetMemberIcon==nil and a.SetRoleIcon==nil and a.SetActivityIcon==nil and a.StyleMemberIcon==nil,"business factories and resolvers belong to the consuming addon")
check(a.Theme.rosterSize==nil and a.Theme.roleButtonIconSize==nil,"shared theme does not define product roster or role geometry")
local edit=C.Edit(parent,200,44);edit:SetPlaceholder("搜索")
check(edit.placeholder:IsShown(),"empty placeholder")
edit.box:Fire("OnEnter")
local function luminance(color)
 local result=0
 for i,weight in ipairs({.2126,.7152,.0722}) do local value=color[i];result=result+weight*(value<=.04045 and value/12.92 or ((value+.055)/1.055)^2.4) end
 return result
end
check((luminance({edit.placeholder:GetTextColor()})+.05)/(luminance(edit.fill.color)+.05)>=4.5,"an empty hovered input keeps its placeholder legible against the actual hover surface")
edit.box:Fire("OnLeave")
local editChanges=0
edit.box:HookScript("OnTextChanged",function() editChanges=editChanges+1 end);edit.box:SetText("abc")
check(not edit.placeholder:IsShown() and editChanges==1,"placeholder and consumer HookScript callback both run")
edit.box:SetFocus();check(edit.focus:IsShown(),"focus ring")
a:ClearFocus();check(not edit.box:HasFocus() and not edit.focus:IsShown(),"context clears only own focus")
local numberChange
local num=C.Number(parent,120,44,function(value) numberChange=value end);num.box:SetText("270")
check(numberChange=="270" and not num.placeholder:IsShown() and num.increase==nil and num.decrease==nil,"numeric callback and placeholder visibility update together")
num.box:SetText("");check(numberChange=="" and num.placeholder:GetText()=="","empty numeric input has no implied domain meaning")
num:SetPlaceholder("Quantity");check(num.placeholder:IsShown() and num.placeholder:GetText()=="Quantity","numeric placeholder is supplied by the caller")
local button=C.Button(parent,"Action",100);button:SetActive(true)
check(button.fill:IsShown() and button.fill.color==a.Theme.secondaryContainer,"active button is tonal")
button:SetPrimary(true);check(button.label._color==a.Theme.onPrimary,"primary uses on-primary text")
button:Fire("OnEnter");M:Tick(.12);button:Fire("OnMouseDown");M:Tick(.06)
check(button.fill.color[2]<a.Theme.primaryHover[2] and button.label:GetAlpha()==1,"press transitions the primary surface while preserving white text")
M:Tick(.06);check(near(button.fill.color[1],a.Theme.primary[1]*(1-a.Theme.pressed[4])) and near(button.fill.color[2],a.Theme.primary[2]*(1-a.Theme.pressed[4])),"primary press reaches the shared base-color and state-alpha result")
button:Fire("OnLeave");M:Tick(.12);button:Fire("OnMouseUp");M:Tick(.12)
check(button.fill.color==a.Theme.primary and button.pressCancelled,"dragging off clears the press and restores the default surface")
button:SetAvailable(false);button:Fire("OnEnter");button:Fire("OnMouseDown");M:Tick(.12)
check(button:GetAlpha()==.38 and button.fill:GetAlpha()==1 and button.label:GetAlpha()==1 and button.fill.color==a.Theme.primary,"disabled opacity applies once to the entire button and ignores press colors")
button:SetAvailable(true);button:Fire("OnLeave");M:Tick(.12)
check(button:GetAlpha()==1 and button.fill.color==a.Theme.primary,"re-enabling restores the control without a stuck press")
button:Fire("OnEnter");M:Tick(.06);button:Fire("OnLeave");button:Hide()
check(M.jobs[button.fill]==nil and button.fill.color==a.Theme.primary,"hiding mid-transition settles the surface and removes its pending color work")
button:Show()
local secondary=C.Button(parent,"Secondary",110)
secondary:Fire("OnEnter");M:Tick(.12);secondary:Fire("OnMouseDown");M:Tick(.12)
check(near(secondary.hover.regions[1]:GetAlpha(),20/255) and secondary.label:GetAlpha()==1,"secondary press uses the reference background alpha without dimming text")
secondary:Fire("OnMouseUp");M:Tick(.12)
check(near(secondary.hover.regions[1]:GetAlpha(),13/255),"releasing the secondary button restores hover")
secondary:Hide();check(not secondary.hover:IsShown(),"hidden button releases its visual state")
local switchChanges=0
local switchNodes=#S.nodes
local switch=C.Check(parent,"Switch",function() switchChanges=switchChanges+1 end);switch:SetValue(true,true)
check(#S.nodes-switchNodes==18 and switch.fill==nil and switch.hover==nil,"switch allocates only its button, label, track and knob art")
check(switch.track:GetWidth()==44 and switch.track:GetHeight()==26 and switch.knob:GetWidth()==20,"switch geometry")
M:Tick(.3);check(near(switch.knob._slideX,21),"switch reaches true endpoint")
switch:Fire("OnMouseDown");switch:Fire("OnMouseUp");switch:Fire("OnClick");M:Tick(.3)
check(switchChanges==1 and not switch.value and near(switch.knob._slideX,5),"switch input toggles once and reaches the off endpoint")
switch:SetAvailable(false);switch:Fire("OnClick")
check(switchChanges==1 and not switch.value and switch:GetAlpha()==.38,"disabled switch cannot dispatch its action")
switch:SetAvailable(true);switch:Fire("OnMouseDown");switch:Hide();switch:Fire("OnClick")
check(switchChanges==1 and not switch.value,"hiding cancels an in-progress switch press")
switch:Show();switch:Fire("OnMouseDown");switch:Fire("OnMouseUp");switch:Fire("OnClick");M:Tick(.3)
check(switchChanges==2 and switch.value and near(switch.knob._slideX,21),"reused switch retains its click and motion lifecycle")
local sliderChanges,sliderValue=0
local scaleSlider=C.Slider(parent,240,75,150,5,function(value) sliderChanges=sliderChanges+1;sliderValue=value end)
scaleSlider:SetValue(110)
check(scaleSlider:GetValue()==110 and scaleSlider.value==110 and sliderChanges==0,"setting a slider value synchronizes its state without a business callback")
scaleSlider.slider:SetValue(115)
check(sliderChanges==1 and sliderValue==115 and scaleSlider.value==115,"native slider changes still deliver the current value once")
check(scaleSlider.slider:GetThumbTexture()==scaleSlider.thumb and scaleSlider.slider.valueStep==5 and scaleSlider.slider.obeyStepOnDrag,"the visible thumb belongs to the native stepped slider drag path")
check(scaleSlider.thumb:GetTexture()==130871 and scaleSlider.thumb:GetWidth()==8 and scaleSlider.thumb:GetHeight()==12,"the native thumb is a compact solid vertical bar")
check(near(scaleSlider.progress:GetWidth(),240*(115-75)/(150-75)),"selected track fills the fraction represented by the current value")
check(scaleSlider.track:GetFrameLevel()<scaleSlider.slider:GetFrameLevel() and scaleSlider.progress:GetFrameLevel()<scaleSlider.slider:GetFrameLevel(),"track surfaces cannot cut through the native thumb")
check(scaleSlider.track:GetHeight()==4 and scaleSlider.progress:GetHeight()==4 and near(scaleSlider.progress.children[1].vertex[1],a.Theme.accent[1]),"four-pixel tracks retain a red selected portion")
local selected
do
 local renders=0
 local selection=C.List(parent,300,120,40)
 selection:SetItems({1,2,3,4,5,6,7,8},function(row,key) renders=renders+1;a:SetText(row.title,key) end)
 renders=0;selection:Select(2)
 check(renders==0 and selection.selectedKey==2,"selection changes only the shared selection presentation, without rebinding data")
 selection:Select(8,true)
 check(renders==3 and selection.rows[3].key==8 and selection.selectedKey==8,"locating an offscreen selection binds the new viewport once")
 renders=0;selection:Select(8,true)
 check(renders==0,"locating the current item does not rebind an unchanged viewport")
 selection:Refresh()
 check(renders==3,"explicit refresh still updates all visible data")
 selection:Hide()
end
local list=C.List(parent,300,120,40,function(key) selected=key end)
list.clip.mouseOver=true
list:SetItems({1,2,3,4,5,6,7,8},function(row,key) a:SetText(row.title,key) end)
check(#list.rows==5,"bounded visible row pool")
check(near(list.slider.children[1].fill[1],a.Theme.accent[1]) and near(list.slider.children[1].fill[2],a.Theme.accent[2]),"shared list thumb uses Lychee accent")
check(list.rows[2].alternate:IsShown(),"newly bound even row retains alternate fill")
local row=list.rows[1];row:Fire("OnMouseDown");list:SetPixelOffset(80,false);row:Fire("OnClick","LeftButton")
check(selected==nil,"recycled press cannot select replacement item")
local nodeCount=#S.nodes;list:SetGutter(0);list:SetPixelOffset(100,true);M:Tick(.2)
check(#S.nodes==nodeCount and list.rows[1]:GetWidth()==300,"scroll and gutter preserve object pool")
check(list.offset==2 and near(list.pixelOffset,100),"pixel scroll uses full row and remainder")
row:Fire("OnLeave");check(left==1,"row tooltip ownership is external")
row.mouseOver=true;row.symbol=C.Glyph(row,"book",24);row.icon=C.Icon(row,24);row.icon:SetTexture(123)
list:Refresh();check(row.symbol.texture.desaturated and row.symbol.texture:GetAlpha()==.72,"category row refresh sets inactive original art")
list:Select(row.key);row:Fire("OnEnter");row:Fire("OnLeave")
check(not row.symbol.texture.desaturated and row.symbol.texture:GetAlpha()==1,"selected category stays colored across hover")
row:Fire("OnEnter");M:Tick(.1);check(not row.hover:IsShown(),"selected rows preserve their selected fill on hover")
list:Select(8);row:Fire("OnEnter");check(row.symbol.texture:GetAlpha()==.9,"inactive category hover is lighter")
M:Tick(.1);check(near(row.hover.regions[1]:GetAlpha(),13/255),"unselected row hover reaches the prototype's full state-layer alpha")
row:Fire("OnLeave");check(row.symbol.texture:GetAlpha()==.72 and row.icon:GetTexture()==123,"category leave restores gray without touching business art")
list:Hide();check(M:Count()==0,"list hide stops row and scroll work")
local detailKey,contextKey,contextButton
local plain=C.List(parent,200,80,40,function(key,button) contextKey,contextButton=key,button end,function(_,key) detailKey=key end)
plain.hoverFill=false;plain.selectionFill=false;plain.selectionMark=false;plain.idleTextColor=a.Theme.muted;plain.clip.mouseOver=true
plain:SetItems({"application"},function() end)
local plainRow=plain.rows[1];plainRow.mouseOver=true;plainRow:Fire("OnEnter");M:Tick(.11)
check(detailKey=="application" and plainRow.title._color==a.Theme.text and not plainRow.hover:IsShown(),"disabling hover fill preserves detail callbacks and hovered foregrounds without a row background")
plainRow:Fire("OnMouseDown");check(not plainRow.hover:IsShown(),"a background-free row also suppresses the pressed surface")
plainRow:Fire("OnMouseUp");plainRow:Fire("OnClick","RightButton")
check(contextKey=="application" and contextButton=="RightButton" and not plainRow.selected:IsShown(),"background-free rows retain their real right-click callback")
plainRow:Fire("OnLeave");plain:Hide()
local resized=C.List(parent,300,80,40)
local resizeNodes=#S.nodes
check(resized.canvas:GetWidth()==282 and resized.rows[1]:GetWidth()==282,"list starts with the default scrollbar gutter")
resized:SetWidth(200)
check(resized.canvas:GetWidth()==182 and resized.rows[#resized.rows]:GetWidth()==182,"direct list shrink updates canvas and every pooled row")
resized:SetGutter(14)
check(resized.canvas:GetWidth()==186 and resized.rows[1]:GetWidth()==186,"gutter changes resize list content at its current width")
resized:SetWidth(320)
check(resized.canvas:GetWidth()==306 and resized.rows[#resized.rows]:GetWidth()==306,"direct list growth preserves the configured gutter")
resized:SetGutter(0);resized:SetWidth(200)
check(resized.canvas:GetWidth()==200 and resized.rows[1]:GetWidth()==200 and #S.nodes==resizeNodes,"zero-gutter resize reuses the complete row pool")
local initializedRows=0
resized:SetRowInitializer(function(row) initializedRows=initializedRows+1;row.extra=C.Text(row,"Reusable row") end)
resized:SetItems({1,2,3,4,5,6,7,8,9,10},function(row,key) row.extra:SetText(tostring(key)) end)
resized:SetViewport(280)
check(#resized.rows==9 and initializedRows==9 and resized.rows[8].extra:GetText()=="8","growing an adaptive viewport initializes and binds every added row")
check(resized.rows[9]:GetWidth()==200,"new rows use the current width and gutter")
local grownNodes=#S.nodes
resized:SetViewport(80);resized:SetViewport(280)
check(#S.nodes==grownNodes and initializedRows==9,"shrinking and restoring a viewport reuses its high-water row pool")
local clipped=C.List(parent,200,100,48)
for _,item in ipairs(clipped.rows) do item:SetHeight(44) end
clipped:SetItems({1,2,3,4,5,6},function() end);clipped:SetPixelOffset(42,false)
check(clipped.rows[1]:IsShown() and clipped.rows[1].mouseEnabled and clipped.rows[1].hitRect[3]==42,"top partial row stays visible with only its 2px visible hit area")
check(clipped.rows[4]:IsShown() and not clipped.rows[4].mouseEnabled and clipped.rows[4].hitRect[4]==44,"fully clipped spare row cannot receive mouse input")
clipped.rows[1]:Fire("OnEnter");check(not clipped.rows[1].hover:IsShown(),"pointer outside viewport cannot light a clipped row")
clipped.clip.mouseOver=true;clipped.rows[1].mouseOver=true;clipped.rows[1]:Fire("OnEnter")
check(clipped.rows[1].hover:IsShown(),"visible part of partial row still supports hover")
clipped.clip.mouseOver=false;clipped:Refresh();check(not clipped.rows[1].hover:IsShown(),"scroll refresh clears stale hover outside viewport")
for _,items in ipairs({{1,2},{1,2,3}}) do
 clipped:SetViewport(#items*48-4);clipped:SetItems(items,function() end)
 check(not clipped.slider:IsShown(),"short activity lists do not scroll through the final row gap")
 clipped:SetPixelOffset(1000,false);check(clipped.pixelOffset==0,"fitting activity lists reject empty wheel movement")
end
clipped:SetItems({1,2,3,4},function() end);clipped:SetPixelOffset(1000,false)
check(clipped.slider:IsShown() and clipped.pixelOffset==48,"overflowing activity lists scroll exactly to the last visible row edge")
clipped:Clear()
local renderCalls=0
local moving=C.List(parent,200,100,40)
local movingIDs={1,2,3,4,5,6}
local function RenderMoving(item,key) renderCalls=renderCalls+1;a:SetText(item.title,"Item "..key) end
moving:SetItems(movingIDs,RenderMoving)
local initialRenders=renderCalls
moving:SetPixelOffset(20,true);M:Tick(.07);M:Tick(.07)
check(renderCalls==initialRenders,"pixel movement inside the same row interval does not rerender business data")
moving:SetPixelOffset(60,true);local scrollJob=M.jobs[moving];M:Tick(.04)
local interrupted=moving.pixelOffset;moving:SetPixelOffset(0,true)
check(M.jobs[moving]==scrollJob and moving.pixelOffset==interrupted,"repeated wheel input reuses its job and continues from the current position")
M:Tick(.14);check(near(moving.pixelOffset,0) and M.jobs[moving]==nil,"reversed reused scroll animation reaches its new target and stops")
moving:SetItems(movingIDs,RenderMoving)
check(renderCalls==initialRenders*2,"data refresh rerenders existing keys even while the ID array is reused")
moving:SetPixelOffset(60,false)
check(renderCalls>initialRenders*2 and moving.rows[1].title:GetText()=="Item 2","crossing a row boundary binds and renders the new visible records")
moving:Clear()
do
 local ctx=library:CreateContext()
 local edge=ctx.C.List(parent,200,100,40)
 edge:SetItems({1,2},function(row,key) ctx:SetText(row.title,key) end)
 local refresh=edge.Refresh;local refreshes=0
 edge.Refresh=function(self,...) refreshes=refreshes+1;return refresh(self,...) end
 edge:Fire("OnMouseWheel",1)
 for i=1,14 do ctx.Motion:Tick(.01) end
 check(refreshes==1 and edge.pixelOffset==0 and not ctx.Motion.jobs[edge],"a fitting list handles boundary wheel input once without a zero-distance scroll animation")
 edge:SetItems({1,2,3,4,5,6,7,8},function(row,key) ctx:SetText(row.title,key) end)
 edge:SetPixelOffset(10000,false);local last=edge.pixelOffset;refreshes=0
 edge:Fire("OnMouseWheel",-1)
 for i=1,14 do ctx.Motion:Tick(.01) end
 check(refreshes==1 and edge.pixelOffset==last and edge.rows[3].key==8 and not ctx.Motion.jobs[edge],"bottom-edge scrolling keeps the last item and avoids idle animation frames")
 edge:Select(8,true)
 check(edge.selectedKey==8 and edge.rows[3].selected:IsShown(),"locating a new selection at the same offset still updates selection presentation")
 edge:SetPixelOffset(0,false);edge:SetPixelOffset(80,true);edge:SetPixelOffset(0,true)
 check(edge.pixelOffset==0 and not ctx.Motion.jobs[edge],"a return to the current position cancels the previous scroll request immediately")
 edge:Clear();ctx:Hide()
end
local game=C.GameIcon(parent,32);a:SetGameTexture(game,123,.25,.5,.5,.75)
check(near(game.texCoords[1],.265) and near(game.texCoords[2],.485),"crop is relative to subrect")
a:SetGameAtlas(game,"test");check(near(game.texCoords[1],.224) and near(game.texCoords[4],.776),"atlas crop stays inside atlas")
check(game.mask~=nil,"game icon has rounded mask")
local glyph=C.Glyph(parent,"book",24);glyph:SetSelected(false);check(glyph.texture.desaturated and glyph.texture:GetAlpha()==.72,"inactive original art is grayscale")
glyph:SetSelected(true);check(not glyph.texture.desaturated and glyph.texture:GetAlpha()==1,"selected original art restores color")
local choice=C.Choice(parent,200,{{value=1,label="First"},{value=2,label="Second"}},function(value) selected=value end)
check(select(2,choice.label:GetPoint())==14 and choice.label:GetWidth()==154,"select text uses 14px left inset with separate arrow reservation")
choice:SetWidth(260);check(choice.label:GetWidth()==214,"select resize updates label width through native size event")
parent:SetScale(.8);choice.GetRight=function() return 2100 end;choice.GetBottom=function() return 600 end
choice:Fire("OnClick");check(a.menu:IsShown() and b.menu==nil,"menu state belongs to one context")
check(a.menu.list.rows[1].title.font[2]==16 and a.menu.list.rows[1].title:GetHeight()==22 and a.menu.list.rowHeight==40,"choice menus retain 16/22 navigation typography instead of inheriting the larger content title")
check(choice.expanded and choice.focus:IsShown() and choice.focusInner:IsShown(),"open choice retains its inset focus ring after the pointer leaves")
check(choice.label:GetParent()==choice.choiceForeground and choice.choiceForeground:GetFrameLevel()>choice:GetFrameLevel(),"choice text and arrow stay in a foreground frame above changing surface batches")
a.menu.list.clip.mouseOver=false
check(near(a.menu:GetEffectiveScale(),choice:GetEffectiveScale()) and select(1,a.menu:GetPoint())=="TOPLEFT","scaled menu bounds use physical coordinates and keep anchor scale")
parent:SetScale(1);choice.GetRight=nil;choice.GetBottom=nil
a.menu.list.rows[2]:Fire("OnMouseDown");a.menu.list.rows[2]:Fire("OnClick","LeftButton");check(selected==2 and choice.value==2 and not a.menu:IsShown(),"programmatic menu click commits without a cursor-position dependency")
check(not choice.expanded and not choice.focus:IsShown(),"selecting an option releases the trigger's expanded state")
choice:Fire("OnClick")
local menuCheck=a.menu.list.rows[2].check
check(menuCheck:GetObjectType()=="Frame" and #menuCheck.strokes==2 and menuCheck:GetWidth()==16 and menuCheck:GetHeight()==20 and menuCheck:IsShown(),"selected menu check uses two thin native strokes in its original slot")
a:CloseMenu()
choice:Fire("OnClick");choice:Hide();check(not a.menu:IsShown() and not choice.focus:IsShown(),"hiding a choice closes its menu and ring")
choice:Show()
do
 local entries={{value=1,label="最新"},{value=2,label="评分"},{value=3,label="装等"}}
 local narrow=C.Choice(parent,144,entries,function(value) selected=value end)
 narrow:SetValue(1,"最新");narrow:Fire("OnClick")
 check(a.menu:GetWidth()==narrow:GetWidth(),"short choices match the trigger instead of inheriting a wider 168px minimum")
 local contentLeft=select(2,a.menu.list:GetPoint())
 check(a.menu.gutter==0 and not a.menu.list.slider:IsShown() and a.menu:GetWidth()-contentLeft-a.menu.list.rows[1]:GetWidth()==contentLeft,"non-scrolling selection rows have equal left and right outer insets")
 check(a.menu.list.rows[1].selected.regions[4]:GetWidth()==8 and select(2,a.menu.list.rows[1].title:GetFont())==16,"balanced menus preserve 8px selection corners and enlarged text")
 local menuRows=a.menu.list.rows
 local many={};for i=1,14 do many[i]={value=i,label="选项 "..i} end
 a:OpenMenu(narrow,many,function(value) selected=value end,{kind="select",selectedValue=14})
 check(a.menu.list.slider:IsShown() and a.menu.gutter==C.listRightInset,"overflowing menus reserve the actual shared scrollbar gutter")
 check(#a.menu.list.ids==14 and a.menu.list.rows[10].key==14,"all options remain reachable through the bounded scrolling pool")
 local longLabel=string.rep("Long option ",5)
 a:OpenMenu(narrow,{{value=1,label=longLabel}},nil,{kind="select"})
 check(a.menu:GetWidth()>narrow:GetWidth() and a.menu.list.rows[1].title:GetWidth()>=a.menu.list.rows[1].title:GetStringWidth(),"real long labels may widen a menu without shrinking the font")
 local menuNodes=#S.nodes
 narrow:Fire("OnClick")
 check(a.menu:GetWidth()==144 and a.menu.gutter==0 and a.menu.list.rows==menuRows and #S.nodes==menuNodes,"reopening a short menu removes old scroll space and reuses its row pool")
 a:CloseMenu()
end
do
 local skin=library:CreateContext({reducedMotion=true})
 local defaultBackground=skin.Theme.selectBackground
 local controls=skin.C;local entries={{value=1,label="One"},{value=2,label="Two"}};local picked
 local light=controls.Choice(parent,160,entries);light:SetValue(1,"One")
 local dark=controls.Choice(parent,160,entries,function(value) picked=value end);dark:SetValue(1,"One");dark:SetSurfaceVariant("dark")
 light:Fire("OnEnter");check(light.fill.color==defaultBackground and light.hover:IsShown() and light.hover.color[1]==0 and near(light.hover.color[4],.18),"a light-surface choice keeps its dark field visible under a black hover layer")
 light:Fire("OnMouseDown");check(light.fill.color==defaultBackground and light.hover:IsShown() and near(light.hover.color[4],.26),"pressing a default choice strengthens its black layer without changing the field")
 light:Fire("OnMouseUp");check(near(light.hover.color[4],.18),"releasing a default choice restores hover rather than a parent-colored fill")
 light:Fire("OnLeave");check(light.fill.color==defaultBackground and near(defaultBackground[1],24/255) and near(defaultBackground[2],24/255) and near(defaultBackground[3],24/255),"a dark variant never changes a neighboring 181818 default field")
 dark:Fire("OnEnter")
 check(dark.fill.color==skin.Theme.surfaceLow and dark.hover:IsShown() and near(dark.hover.regions[1]:GetAlpha(),13/255),"dark choices retain their filled field under a translucent hover layer")
 dark:Fire("OnMouseDown");check(dark.fill.color==skin.Theme.surfaceLow and near(dark.hover.color[4],20/255),"pressing a dark choice strengthens the white layer over its existing field")
 dark:Fire("OnMouseUp")
 dark:Fire("OnClick")
 check(skin.menu.fill.color==skin.Theme.raised and dark.focusInner.color==skin.Theme.surfaceLow and skin.menu.list.rows[1].selected.color==skin.Theme.secondaryContainer,"the expanded menu is brighter than its dark parent while the field and selected item keep their roles")
 skin.menu.list.rows[2]:Fire("OnMouseDown");skin.menu.list.rows[2]:Fire("OnClick","LeftButton")
 check(picked==2 and dark.value==2 and not skin.menu:IsShown(),"variant styling preserves the actual menu selection callback")
 light:Fire("OnClick");check(skin.menu.fill.color==skin.Theme.raised and light.fill.color==defaultBackground,"reusing the menu for a default choice restores its original colors")
 skin:CloseMenu();dark:Fire("OnLeave");dark:SetSurfaceVariant(nil)
 check(dark.fill.color==defaultBackground and not dark.hover:IsShown(),"clearing the explicit variant restores the default field")
 light:Fire("OnClick");check(skin.menu:IsShown(),"the default choice opens its real menu before availability changes")
 light:Fire("OnEnter");light:SetAvailable(false)
 check(not light.hover:IsShown() and light.fill.color==defaultBackground and near(light:GetAlpha(),.38),"disabling a hovered choice clears its layer while preserving the field and disabled opacity")
 check(not skin.menu:IsShown() and not light.expanded,"disabling an expanded choice closes its menu and clears the field focus state")
 skin:Hide()
end
do
 local previousCursor=GetCursorPosition
 local cursorX,cursorY=640,480
 _G.GetCursorPosition=function() return cursorX,cursorY end
 parent:SetScale(.8)
 local entries={{value=1,label="Cursor action"}}
 a:OpenMenu(choice,entries,nil,{cursor=true})
 M:Tick(.16)
 local function pixel(value) return math.floor(value*.8+.5)/.8 end
 local point,relative,relativePoint,x,y=a.menu:GetPoint()
 check(point=="TOPLEFT" and relative==UIParent and relativePoint=="BOTTOMLEFT" and near(x,pixel(804)) and near(y,pixel(596)),"cursor menus settle 4px right and below the pointer, aligned to physical pixels")
 check(near(a.menu:GetEffectiveScale(),choice:GetEffectiveScale()),"cursor positioning preserves the anchor's effective menu scale")
 cursorX,cursorY=1918,2;a:OpenMenu(choice,entries,nil,{cursor=true})
 M:Tick(.16)
 x,y=select(4,a.menu:GetPoint())
 check(near(x,pixel(UIParent:GetWidth()/.8-a.menu:GetWidth()-4)) and near(y,pixel(a.menu:GetHeight()+4)),"cursor menus shift inward at the bottom-right screen edge")
 cursorX,cursorY=0,1080;a:OpenMenu(choice,entries,nil,{cursor=true})
 M:Tick(.16)
 x,y=select(4,a.menu:GetPoint())
 check(near(x,pixel(4)) and near(y,pixel(UIParent:GetHeight()/.8-4)),"cursor menus also stay within the top-left screen edge")
 a:CloseMenu();parent:SetScale(1);_G.GetCursorPosition=previousCursor
 choice:Fire("OnClick")
 check(select(2,a.menu:GetPoint())==choice,"a later default choice still uses its trigger anchor")
 a:CloseMenu()
end
do
 parent:ClearAllPoints();parent:SetPoint("CENTER",UIParent,"CENTER",0,0);parent:SetScale(.75);M:CapturePosition();M:SetPresence(0)
 local setPoint,clearPoints=parent.SetPoint,parent.ClearAllPoints
 local writes,clears,tailWrites,fractional=0,0,0,false
 parent.SetPoint=function(self,...)
  writes=writes+1;setPoint(self,...)
  local pixelY=select(5,self:GetPoint())*self:GetEffectiveScale()
  if not near(pixelY,math.floor(pixelY+.5)) then fractional=true end
 end
 parent.ClearAllPoints=function(self) clears=clears+1;clearPoints(self) end
 M:Presence(true)
 for i=1,60 do local before=writes;M:Tick(.007);if i>=55 then tailWrites=tailWrites+writes-before end end
 check(not fractional,"Presence keeps its moving window aligned to physical pixels at a fractional scale")
 check(tailWrites==0 and clears==0,"the final six frames do not reanchor a window already in its destination pixel")
 check(M.phase==1 and select(5,parent:GetPoint())==0 and parent:GetScale()==.75,"pixel alignment preserves the 420ms endpoint and window scale")
 parent.SetPoint,parent.ClearAllPoints=setPoint,clearPoints;parent:SetScale(1)
end
M:Presence(true);M:Tick(.21);local phase=M.phase;M:Presence(false);M:Tick(.1)
check(M.phase<phase and M.phase>0,"presence reverses continuously")
M:Tick(.5);check(M.phase==0 and M:Count()==0,"420ms presence leaves idle driver")
do
 local completed=0
 M:SetPresence(1);M:Presence(false,function() completed=completed+1 end)
 M:Tick(.42-1/60)
 check(parent:GetAlpha()<.1,"the final 60Hz interval must not cut away a still-opaque window")
 local alpha=parent:GetAlpha();local y=select(5,parent:GetPoint())
 M:Presence(true)
 check(parent:GetAlpha()==alpha and select(5,parent:GetPoint())==y,"reversing the fade preserves the current opacity and position")
 M:Tick(.5);check(completed==0 and M.phase==1,"reopening cancels the old close completion")
 M:Presence(false,function() completed=completed+1 end);M:Tick(.42)
 check(completed==1 and parent:GetAlpha()==0 and M:Count()==0,"the close finishes once at full transparency with no idle driver")
end
do
 local drag=C.Draggable(parent)
 local surface=CreateFrame("Frame",nil,parent);drag:AddHandle(surface)
 local child=C.Button(surface,"Action",80)
 surface:Fire("OnMouseDown","RightButton");check(parent.movable and not parent.moving,"passive window surfaces accept only left-button dragging")
 child:Fire("OnMouseDown","LeftButton");check(not parent.moving,"interactive children do not inherit a drag handler")
 M:Presence(true);local active=M:Count()
 surface:Fire("OnMouseDown","LeftButton");check(parent.moving and drag.handle==surface and M.phase==1 and M:Count()==active-1,"dragging settles only the entrance animation")
 parent:ClearAllPoints();parent:SetPoint("TOPLEFT",UIParent,"TOPLEFT",180,-90)
 surface:Fire("OnMouseUp","LeftButton");check(not parent.moving and not drag.handle,"mouse release ends the active drag")
 M:Presence(false);M:Tick(.5);M:Presence(true);M:Tick(.5)
 local point,relative,relativePoint,x,y=parent:GetPoint()
 check(point=="TOPLEFT" and relative==UIParent and relativePoint=="TOPLEFT" and x==180 and y==-90,"close and reopen animate around the dragged position")
 surface:Fire("OnMouseDown","LeftButton");parent:Hide();check(not parent.moving and not drag.handle,"hiding the window stops a child-surface drag")
 parent:Show()
end
do
 local reveal=CreateFrame("Frame",nil,parent)
 local revealClear=reveal.ClearAllPoints
 local clears=0;reveal.ClearAllPoints=function(self) clears=clears+1;revealClear(self) end
 M:Reveal(reveal,"TOPLEFT",parent,"TOPLEFT",10,20,4,-6,.18);local setupClears=clears
 for i=1,18 do M:Tick(.01) end
 check(clears==setupClears and near(select(4,reveal:GetPoint()),10) and near(select(5,reveal:GetPoint()),20),"reveal reaches its final position without rebuilding the anchor each frame")
 M:FinishPlacement(reveal)
end
do
 M:SetPresence(0)
 S.preciseNow=100.055;M:Presence(true)
 S.preciseNow=100.056
 local reveal=CreateFrame("Frame",nil,parent)
 M:Reveal(reveal,"TOPLEFT",parent,"TOPLEFT",10,20,4,-6,.18)
 local initialX,initialY,initialAlpha=select(4,reveal:GetPoint()),select(5,reveal:GetPoint()),reveal:GetAlpha()
 S.preciseNow=100.057;M.driver:Fire("OnUpdate",.057)
 check(near(M.phase,.002/.42),"a 57ms cold frame only advances Presence for its actual 2ms lifetime")
 check(initialX==14 and initialY==14 and initialAlpha==.35,"Reveal starts at its offset and initial alpha before the first render")
 local revealP=(.001/.18)*(2-.001/.18)
 check(select(4,reveal:GetPoint())==math.floor(10+4*(1-revealP)+.5) and near(reveal:GetAlpha(),.35+.65*revealP),"each new Reveal uses its own start time and pixel-aligned geometry rather than the frame's elapsed")
 S.preciseNow=100.064;M.driver:Fire("OnUpdate",.007)
 check(near(M.phase,.009/.42),"later driver ticks retain the normal elapsed-time progression")
 local beforeReverse=M.phase;local closed=false
 S.preciseNow=100.067;M:Presence(false,function() closed=true end)
 S.preciseNow=100.068;M.driver:Fire("OnUpdate",.057)
 check(near(M.phase,beforeReverse-.001/.42) and not closed,"a rapid reversal starts continuously without inheriting the earlier cold frame")
 M:StopAll();M:SetPresence(1)
 check(next(M.startTimes)==nil and not M.driver:GetScript("OnUpdate"),"stopping clears first-tick clocks and the idle driver")
 S.preciseNow=0
end
do
 local schedule=library:CreateContext().Motion
 schedule:Start("warm",function() end);schedule:Stop("warm")
 local driver=schedule.driver
 local script,show,hide,clock=driver.SetScript,driver.Show,driver.Hide,GetTimePreciseSec
 local scriptWrites,shows,hides,reads=0,0,0,0
 driver.SetScript=function(self,...) scriptWrites=scriptWrites+1;script(self,...) end
 driver.Show=function(self,...) shows=shows+1;show(self,...) end
 driver.Hide=function(self,...) hides=hides+1;hide(self,...) end
 _G.GetTimePreciseSec=function() reads=reads+1;return clock() end
 for i=1,50 do schedule:Start(i,function() return false end) end
 for i=1,120 do S.preciseNow=i*.01;driver:Fire("OnUpdate",.01) end
 check(reads==51,"fifty simultaneous animations read the native clock once on their first frame, not every frame")
 schedule:StopAll()
 for i=1,100 do schedule:Stop(i) end
 check(scriptWrites==2 and shows==1 and hides==1,"one busy interval installs and removes the driver once despite repeated starts and stops")
 check(next(schedule.startTimes)==nil and schedule:Count()==0,"scheduler shutdown releases all first-frame clocks")
 driver.SetScript,driver.Show,driver.Hide=script,show,hide;_G.GetTimePreciseSec=clock;S.preciseNow=0
end
local refresh=C.Glyph(parent,"refresh",22)
do
 local region=C.Icon(parent,44)
 local clear=region.ClearAllPoints;local clears=0
 region.ClearAllPoints=function(self) clears=clears+1;clear(self) end
 region:SetPoint("BOTTOM",parent,"BOTTOM",0,30);M:Waiting(region,true)
 check(region:GetPoint()=="BOTTOM","waiting preserves its initial presentation until its first frame")
 for i=1,120 do M:Tick(.01) end
 check(clears==1 and region:GetNumPoints()==1,"waiting establishes its anchor once for an entire cycle")
 M:Waiting(region,false)
 check(region:GetWidth()==44 and region:GetAlpha()==1 and not region:IsShown(),"waiting cancellation still restores size and opacity")
 region:Show();clears=0;M:Switch(region,2,20)
 for i=1,18 do M:Tick(.01) end
 check(clears==1 and region:GetNumPoints()==1 and near(select(4,region:GetPoint()),20),"switch keeps one anchor and reaches the original 180ms endpoint")
 M:Switch(region,20,2);M:Tick(.03);M:StopAll()
 check(region._slideX==2 and select(4,region:GetPoint())==2,"stopping a reversed switch places its intended endpoint")
 region.ClearAllPoints=clear
end
M:Spin(refresh,true);M:Tick(.225);check(near(refresh.texture.rotation,-math.pi/2) and M:Count()==1,"refresh turns linearly over 900ms using the shared driver")
M:Spin(refresh,true);M:Tick(.225);check(near(refresh.texture.rotation,-math.pi),"busy refresh updates do not restart rotation")
refresh:Hide();check(refresh.texture.rotation==0 and M:Count()==0,"hiding refresh owner resets spin and stops driver")
refresh:Show();M:Spin(refresh,true);M:Tick(.1);M:StopAll();check(refresh.texture.rotation==0 and M:Count()==0,"StopAll cancels and resets refresh")
reduced=true;M:Presence(true);check(M.phase==1 and M:Count()==0,"reduced motion has no jobs")
M:Spin(refresh,true);check(refresh.texture.rotation==0 and M:Count()==0,"reduced motion keeps refresh static without jobs")
local modal=C.Modal(parent,500,320,"Title");check(modal.content~=nil and modal.close:GetHeight()==40,"modal is a native shell with shared close")
check(select(1,modal:GetPoint())=="CENTER" and select(2,modal:GetPoint())==parent,"modal defaults to center on its parent")
check(select(2,modal.content:GetPoint())==24 and select(3,modal.content:GetPoint())==-80 and select(3,modal.close:GetPoint())==-24,"modal content and header follow 24 inset and 80 top contract")
check(not modal:IsShown() and not modal.scrim:IsShown(),"new modal and scrim start hidden")
check(modal.scrim:GetParent()==parent and modal.scrim.allPoints==parent and modal.scrim:GetFrameLevel()<modal:GetFrameLevel(),"scrim covers only the owning window below modal")
modal:Show();check(modal.scrim:IsShown(),"modal show enables input-blocking scrim")
modal.scrim:Fire("OnClick");check(not modal:IsShown() and not modal.scrim:IsShown(),"scrim click closes default modal and releases input")
local closes=0;local hooked=0
local customModal=C.Modal(parent,400,200,"Close",function(frame) closes=closes+1;frame:Hide() end)
customModal:HookScript("OnHide",function() hooked=hooked+1 end)
customModal:Show();customModal.scrim:Fire("OnClick");customModal:Show();customModal.close:Fire("OnClick")
check(closes==2 and hooked==2 and not customModal.scrim:IsShown(),"scrim and close share callback without replacing consumer hide hooks")
local shadow=C.Shadow(parent,28);check(#shadow.regions==9,"shadow has nine reusable native slices")
local segmented=C.Segmented(parent,300,{{value="a",label="A"},{value="b",label="B"}},function() end);segmented:SetValue("b")
check(segmented:GetHeight()==36 and segmented.buttons[2].active and segmented.buttons[2]:GetHeight()==30,"36/30 segmented geometry")
check(segmented.buttons[2].fill.regions[4]:GetWidth()==8 and segmented.buttons[2].hover.regions[4]:GetWidth()==8,"segmented selection and hover keep the requested small radius")
a:Hide();check(M:Count()==0 and not a.menu:IsShown(),"context shutdown has no pending work")
local ran,replacements=0,0
local keys={"first","second","third"}
local function cancelAndReplace()
 ran=ran+1
 for _,key in ipairs(keys) do M:Stop(key) end
 M:Start("second",function() replacements=replacements+1;return true end)
 M:Start("new",function() replacements=replacements+1;return true end)
 return true
end
for _,key in ipairs(keys) do M:Start(key,cancelAndReplace) end
local tickBuffer=M.tickBuffer
M:Tick(.01)
check(ran==1 and replacements==0 and M:Count()==2,"animation callback may cancel and replace other jobs; new jobs wait until next tick")
check(next(tickBuffer)==nil,"tick snapshot clears completed and cancelled job references")
M:Tick(.01)
check(replacements==2 and M:Count()==0 and M.tickBuffer==tickBuffer and next(tickBuffer)==nil,"next tick uses the same buffer and finishes replacement jobs")
check(released>0,"list releases external ownership")
do
 local entries={{value=1,label="One"}}
 local ctx,first,pending
 ctx=library:CreateContext({onMenuClosed=function(owner) if owner==first then ctx:Hide() end end})
 first=ctx.C.ChoiceTrigger(UIParent,150);pending=ctx.C.ChoiceTrigger(UIParent,150)
 ctx:OpenMenu(first,entries);ctx:OpenMenu(pending,entries)
 check(ctx:IsHiding() and not ctx:IsMenuOpen() and not pending.expanded,"a menu close callback may hide the context before a pending replacement")
 check(ctx.Motion:Count()==0 and not ctx:GetMenu().catcher:IsShown(),"cancelled menu replacement leaves no animation or mouse catcher")
 local hidden,old,target
 hidden=library:CreateContext({onMenuClosed=function(owner) if owner==old then target:Hide() end end})
 old=hidden.C.ChoiceTrigger(UIParent,150);target=hidden.C.ChoiceTrigger(UIParent,150)
 hidden:OpenMenu(old,entries);hidden:OpenMenu(target,entries)
 check(not hidden:IsMenuOpen() and not target.expanded,"replacement rechecks the anchor after the close callback hides it")
 local latest,a,b,c
 local three={{value=1,label="One"},{value=2,label="Two"},{value=3,label="Three"}}
 latest=library:CreateContext({onMenuClosed=function(owner) if owner==a then latest:OpenMenu(c,three) end end})
 a=latest.C.ChoiceTrigger(UIParent,150);b=latest.C.ChoiceTrigger(UIParent,150);c=latest.C.ChoiceTrigger(UIParent,150)
 latest:OpenMenu(a,entries);latest:OpenMenu(b,entries)
 check(latest:GetMenuAnchor()==c and c.expanded and not a.expanded and not b.expanded,"a menu opened by the close callback keeps sole ownership")
 check(#latest:GetMenu().list.ids==3 and latest:GetMenu().list.rows[3].title:GetText()=="Three","a longer reentrant menu keeps all its own entries without stale-key indexing")
 latest:CloseMenu()
 check(not c.expanded and not latest:IsMenuOpen(),"the callback-opened menu still follows the normal close lifecycle")
 local disabled,choice
 disabled=library:CreateContext({onMenuClosed=function(owner) if owner==choice then disabled:OpenMenu(choice,entries) end end})
 choice=disabled.C.ChoiceTrigger(UIParent,150)
 disabled:OpenMenu(choice,entries);choice:SetAvailable(false)
 check(not disabled:IsMenuOpen() and not choice.expanded and not choice:IsEnabled(),"disabling a Choice cannot be undone by reopening from its close callback")
 disabled:OpenMenu(choice,entries)
 check(not disabled:IsMenuOpen(),"direct menu requests also respect a Choice's disabled state")
end
do
 local ctx=library:CreateContext({reducedMotion=true})
 local anchor=ctx.C.ChoiceTrigger(parent,200)
 ctx:OpenMenu(anchor,{{value=1,label="Warm"}},nil,{width=216});ctx:CloseMenu()
 local menu=ctx:GetMenu();local measure=menu.measure;local getWidth=measure.GetStringWidth
 local measured=0
 measure.GetStringWidth=function(self) measured=measured+1;return getWidth(self) end
 local entries={}
 for i=1,100 do entries[i]={value=i,label="An intentionally long menu choice "..i} end
 ctx:OpenMenu(anchor,entries,nil,{width=216,selectedValue=100})
 check(measured==0 and menu:GetWidth()==216 and #menu.list.ids==100,"explicit menu width skips discarded text measurement while retaining every item")
 check(menu.list.rows[10].title:GetText()==entries[100].label,"the final choice remains reachable in a fixed-width menu")
 ctx:CloseMenu();ctx:OpenMenu(anchor,entries)
 check(measured==100 and menu:GetWidth()>216,"automatic menu width still measures all labels and preserves long text sizing")
 ctx:Hide()
end

do
 local motion=library:CreateContext().Motion
 local region=CreateFrame("Frame",nil,UIParent)
 motion:Reveal(region,"TOPLEFT",UIParent,"TOPLEFT",100,-50,20,-20,.18)
 motion:Tick(.05);motion:Stop(region)
 region:ClearAllPoints();region:SetPoint("TOPLEFT",UIParent,"TOPLEFT",777,-888)
 motion:StopAll()
 check(select(4,region:GetPoint())==777 and select(5,region:GetPoint())==-888 and next(motion.placements)==nil,"cancelled Reveal releases its old endpoint before the caller repositions the region")
 motion:Reveal(region,"TOPLEFT",UIParent,"TOPLEFT",100,-50,20,-20,.18)
 motion:Tick(.05);motion:FinishPlacement(region)
 check(select(4,region:GetPoint())==100 and select(5,region:GetPoint())==-50 and region:GetAlpha()==1,"FinishPlacement still explicitly lands a running Reveal at its endpoint")
 local completed=0
 motion:Alpha(region,.2,0,nil,function() completed=completed+1 end)
 check(region:GetAlpha()==.2 and completed==1 and motion:Count()==0,"zero-duration Alpha finishes immediately with exactly one completion callback")
 motion:Reveal(region,"TOPLEFT",UIParent,"TOPLEFT",30,-40,15,-15,0)
 check(select(4,region:GetPoint())==30 and select(5,region:GetPoint())==-40 and region:GetAlpha()==1 and motion:Count()==0,"zero-duration Reveal applies finite endpoint coordinates without scheduling a frame")
 local runs=0
 local restart
 restart=function()
  runs=runs+1
  if runs==1 then motion:Start("same",restart) end
  return true
 end
 motion:Start("same",restart);motion:Tick(.01)
 check(runs==1 and motion.jobs.same==restart and motion:Count()==1,"restarting the same key with the same function survives the old run's completion")
 motion:Tick(.01)
 check(runs==2 and motion:Count()==0 and next(motion.jobIds)==nil and next(motion.startTimes)==nil and next(motion.tickBuffer)==nil,"the restarted run finishes next frame and releases its scheduler references")
 motion:Start("pending",restart);motion:StopAll()
 check(next(motion.jobIds)==nil and next(motion.startTimes)==nil and not motion.driver:GetScript("OnUpdate"),"StopAll releases task identities together with jobs and first-frame clocks")
end

dofile("tests/native.lua")(library,S,check)
dofile("tests/native_background.lua")(library,S,check)
dofile("tests/context.lua")(S,library,check,near)

dofile("tests/motion.lua")(S,library,check,near)
dofile("tests/motion_lifecycle.lua")(S,library,check,near)
dofile("tests/slider.lua")(S,library,check,near)
dofile("tests/styles.lua")(S,library,check,near)
dofile("tests/fonts.lua")(library,check,near)
dofile("tests/table.lua")(S,library,check,near)
dofile("tests/theme.lua")(S,library,check,near)
dofile("tests/typography.lua")(S,library,check,near)
dofile("tests/layouts.lua")(S,library,check,near)
dofile("tests/elements.lua")(S,library,check,near)
dofile("tests/sparse_state.lua")(S,library,check,near)
dofile("tests/catalog_defaults.lua")(S,library,check,near)
dofile("tests/fixed_fonts.lua")(S,library,check,near)
dofile("tests/glyph_style.lua")(S,library,check,near)
print("LycheeUI: "..count.." focused assertions passed")
