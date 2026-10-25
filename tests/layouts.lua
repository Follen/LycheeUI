return function(S,library,check,near)
 local ctx=library:CreateContext({reducedMotion=true,
  recipeDefaults={action={base={surface={shown=false},hover={shown=false},label={color="muted"}},states={hover={label={color="brand"}}}}}})
 local C=ctx.C
 local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(300,100)
 local label=C.Text(parent,"Measured","label");C.SetLineHeight(label,"label",true);label:SetSize(73,31)
 local icon=C.Icon(parent,20);local before=#S.nodes;local uv={.1,.9,.2,.8};icon:SetTexCoord(unpack(uv))
 check(C.Box(icon,20)==icon and #S.nodes==before and icon.texCoords[1]==uv[1],"Box keeps native identity, UVs and zero extra frames")
 C.Box(label,{width=73});check(label:GetHeight()==31,"table Box axes stay independent and preserve text line boxes")
 local row=C.Row(parent,{{frame=label},{frame=icon,gapAfter=99}},{width="content",height=26,gap=6,align="center",anchor="TOPRIGHT",padding={right=16}})
 local w,h=row:Layout()
 check(w==115 and h==31 and label:GetWidth()==73 and label:GetHeight()==31,"omitted item axes retain measured width and existing line box")
 check(select(4,label:GetPoint())==185 and near(select(5,label:GetPoint()),2.5),"right anchoring includes padding and tall center alignment permits negative cross offset")
 local oldSize,oldPoint,oldClear=icon.SetSize,icon.SetPoint,icon.ClearAllPoints;local writes=0
 icon.SetSize=function(self,...) writes=writes+1;return oldSize(self,...) end
 icon.SetPoint=function(self,...) writes=writes+1;return oldPoint(self,...) end
 icon.ClearAllPoints=function(self,...) writes=writes+1;return oldClear(self,...) end
 local record,place=row.records[icon],icon._lycheeLayoutPlace;row:Layout();row:Layout()
 check(writes==0 and row.records[icon]==record and icon._lycheeLayoutPlace==place,"unchanged Layout reuses records and placement closures without native writes")
 local host=CreateFrame("Frame",nil,parent)
 local controller=C.Style(host,{slots={root=host,icon=icon,label=label},states={hover={icon={width=24},label={color="brand"}}}})
 controller:SetState("hover",true)
 check(icon:GetWidth()==24 and row.contentWidth==119,"state width overrides Box base and reflows its owning layout")
 controller:SetState("hover",false)
 check(icon:GetWidth()==20 and row.contentWidth==115,"leaving state restores the Box base width")
 writes=0;controller:SetState("hover",false)
 check(writes==0,"same-value SetState does no native geometry work")
 local foreign=CreateFrame("Frame",nil,parent);controller:Bind(foreign,{hover=true})
 foreign:Fire("OnEnter");check(icon:GetWidth()==24,"state sources can be separate from their target slots")
 host:Disable();controller:Apply(true);host:Enable();controller:Apply(true)
 check(icon:GetWidth()==20,"disabled clears stale source hover before re-enabling")
 foreign:Fire("OnEnter");foreign:Hide();check(icon:GetWidth()==20,"hiding a grouped source clears its contribution")
 row:SetItems({{frame=label},{frame=icon,hidden=true}});row:Layout()
 check(row.contentWidth==89 and icon._lycheeLayoutOwner==nil,"hidden items consume no gap or layout ownership")
 row:SetItems({{frame=icon,width="fill",minWidth=40,maxWidth=90},{frame=label,width=50}}):SetOptions({width=200,padding=0,gap=10});row:Layout()
 check(icon:GetWidth()==90 and label:GetWidth()==50,"fill distribution honors Box-axis maximums")
 row:Release();check(icon._lycheeLayoutOwner==nil,"released layouts relinquish existing native objects")
 local stack=C.Column(parent,{{frame=icon,height=30},{frame=label,height=20}},{width=100,height="content",gap=4,padding={2,3,5,7},align="end"})
 w,h=stack:Layout();check(w==97 and h==64 and select(4,label:GetPoint())==45,"Column measures content with four-sided padding")
 stack:Release()
 for _,factory in ipairs({C.Row,C.Column}) do
  local first,second=CreateFrame("Frame",nil,parent),CreateFrame("Frame",nil,parent)
  first:SetSize(20,10);second:SetSize(30,15)
  local released=setmetatable({},{__mode="v"})
  local replacement=factory(parent,{}, {width=100,height=100})
  do
   local descriptor={frame=first,width=20,height=10};released[1]=descriptor
   replacement:SetItems({descriptor});replacement:Layout()
  end
  replacement:SetItems({{frame=second,width=30,height=15}});replacement:Layout()
  collectgarbage("collect")
  check(released[1]==nil and first._lycheeLayoutOwner==nil and second._lycheeLayoutOwner==replacement,"replacing layout items releases the old Lua descriptor and native anchor ownership")
  do
   local descriptor={frame=second,width=35,height=18};released[2]=descriptor
   replacement:SetItems({descriptor});replacement:Layout()
  end
  replacement:SetItems({{frame=second,width=40,height=20}});replacement:Layout()
  collectgarbage("collect")
  check(released[2]==nil and second:GetWidth()==40 and second:GetHeight()==20,"a new descriptor for the same object releases the previous Lua descriptor")
  for _,nativeHidden in ipairs({false,true}) do
   do
    local descriptor={frame=second,width=40,height=20};released[4]=descriptor
    replacement:SetItems({descriptor});replacement:Layout()
   end
   if nativeHidden then second:Hide() end
   replacement:SetItems({{frame=second,width=40,height=20,hidden=not nativeHidden}});replacement:Layout()
   collectgarbage("collect")
   check(released[4]==nil and second._lycheeLayoutOwner==nil,"replacing an included item with a hidden descriptor releases its old Lua descriptor")
   second:Show()
  end
  local takeover=factory(parent,{second},{width=100,height=100,x=7,y=-9});takeover:Layout()
  replacement:SetItems({});replacement:Layout()
  check(next(replacement.records)==nil and replacement.contentWidth==0 and replacement.contentHeight==0 and second._lycheeLayoutOwner==takeover,"empty replacement clears layout records without taking anchors back from a newer owner")
  do
   local descriptor={frame=first,width=25,height=12};released[3]=descriptor
   replacement.items[1]=descriptor;replacement:Layout()
  end
  check(first._lycheeLayoutOwner==replacement and first:GetWidth()==25 and first:GetHeight()==12,"a removed object can rejoin the layout with its current descriptor")
  replacement.items[1]=nil;replacement:Layout();collectgarbage("collect")
  check(released[3]==nil and next(replacement.records)==nil and first._lycheeLayoutOwner==nil,"in-place item removal also releases the old Lua descriptor and record")
  replacement:Release();takeover:Release()
 end
 local texture=parent:CreateTexture(nil,"ARTWORK");texture:SetSize(80,40);texture:SetTexCoord(.1,.8,.2,.9)
 C.Box(host,{width=40,height=40,padding=4,fit="contain",content=texture})
 check(texture:GetWidth()==32 and texture:GetHeight()==16 and texture.texCoords[1]==.1,"Box contain uses padded rectangular content without changing crop")
 C.Box(host,{width=40,height=40,fit="cover",content=texture})
 check(texture:GetWidth()==80 and texture:GetHeight()==40,"Box cover preserves the content aspect ratio")
 for _,fit in ipairs({"contain","cover"}) do for _,axes in ipairs({{0,40},{40,0},{0,0}}) do
  local pending=parent:CreateTexture(nil,"ARTWORK");pending:SetSize(axes[1],axes[2])
  pending.GetWidth=function(self) return self.w end;pending.GetHeight=function(self) return self.h end
  C.Box(host,{width=40,height=32,fit=fit,content=pending})
  local expected=fit=="contain" and 32 or 40
  check(pending:GetWidth()==expected and pending:GetHeight()==expected,"Box "..fit.." uses a finite square fallback before either content axis is measured")
 end end
 local bound=CreateFrame("Frame",nil,parent);bound:SetSize(37,18)
 C.SetPoint(bound,"TOPLEFT",parent,"TOPLEFT",0,-8);bound:SetWidth(83);bound:SetAlpha(.4)
 C.SetPoint(bound,"TOPLEFT",parent,"TOPLEFT",4,-9)
 check(bound:GetWidth()==83 and bound:GetAlpha()==.4,"point-only updates do not reapply unrelated dimensions or alpha")
 bound:ClearAllPoints();bound:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-9,11)
 ctx:SetFont(nil,1)
 check(bound:GetPoint()=="BOTTOMRIGHT","font refresh does not resurrect an anchor explicitly replaced by its consumer")
 local button=C.Button(parent,"Action",80,nil,{recipe="action"})
 button:Fire("OnEnter")
 check(not button.fill:IsShown() and not button.hover:IsShown() and near(button.label.color[1],ctx.Theme.brand[1]),"component paint yields owned surfaces and text to the recipe")
 button:Fire("OnLeave")
 check(near(button.label.color[1],ctx.Theme.muted[1]) and not button.hover:IsShown(),"recipe idle paint survives mature component state refresh")
 C.SetFont(button.label,"caption");ctx:SetFont(nil,1.3)
 check(near(button.label.font[2],12*1.3),"direct business typography remains live under frozen paint rules")
 ctx:SetFont(nil,1)
 local themed=library:CreateContext({reducedMotion=true,recipes={checkbox={base={surface={color="good"}}},field={base={surface={color="blue"},outline={shown=false}}}}})
 local checkbox=themed.C.Checkbox(parent);checkbox:Fire("OnEnter");checkbox:Fire("OnLeave")
 check(checkbox.fill.color==themed.Theme.good,"checkbox state paint preserves component recipe overrides")
 local field=themed.C.Field(parent,100);field:SetFocused(true);field:SetFocused(false,true)
 check(field.fill.color==themed.Theme.blue and not field.focus:IsShown(),"field focus and hover preserve owned recipe surfaces")
 local variants=library:CreateContext({reducedMotion=true,recipes={button={variants={primary={base={label={color="good"}}},compact={base={label={color="blue"}}}}}}})
 local variant=variants.C.Button(parent,"Variant",80,nil,{variant="primary"})
 check(near(variant.label.color[2],variants.Theme.good[2]),"constructor variants select recipe leaves")
 variant:SetVariant("compact")
 check(near(variant.label.color[3],variants.Theme.blue[3]),"changing component variants also changes its recipe layer")
 local fontHost=CreateFrame("Frame",nil,parent);local font=C.Text(parent,"Font","label");C.SetLineHeight(font,"label",true)
 local styled=C.Style(fontHost,{slots={root=fontHost,label=font},states={hover={label={fontSize="heading",lineHeight="heading",flags="OUTLINE"}}}})
 styled:SetState("hover",true);check(font.font[2]==24 and font:GetHeight()==32,"state-only text styles apply paired metrics and flags")
 styled:SetState("hover",false);check(font.font[2]==14 and font:GetHeight()==20 and font.font[3]=="","state-only font metrics and flags restore their original baseline")
 local panel=C.Panel(parent,"panel",6);local surfaceStyle=C.Style(CreateFrame("Frame",nil,parent),{slots={root=fontHost,surface=panel},states={hover={surface={radius=12}}}})
 surfaceStyle:SetState("hover",true);surfaceStyle:SetState("hover",false)
 check(panel.radius==6,"state-only radius restores the original panel radius")
 local desat=C.Style(CreateFrame("Frame",nil,parent),{slots={root=host,icon=icon},states={hover={icon={desaturated=true}}}})
 desat:SetState("hover",true);desat:SetState("hover",false);check(not icon:IsDesaturated(),"state-only desaturation restores its initial value")
 local schema=library:GetStyleSchema(nil,{"iconButton.states.hover.icon.width"})
 check(schema["iconButton.states.hover.icon.width"].inherited and not library:GetStyleField("iconButton.states.hover.icon.width.extra"),"inherited slot properties are available without accepting trailing path segments")
 schema["button.base.root.height"].default=9
 check(library:GetStyleSchema()["button.base.root.height"].default=="buttonHeight","style schemas return independent metadata")
 local padded={card={base={root={padding={left=4,right=8}}}}}
 local paddingSchema=library:GetStyleSchema(padded)
 check(paddingSchema["card.base.root.padding"].default.right==8,"named Box padding survives schema copies")
 check(not library.SameRecipes(padded,{card={base={root={padding={left=4,right=9}}}}},ctx.Theme,ctx.Theme),"named padding changes participate in effective recipe comparison")
 check(not library:ValidateRecipes({button={base={root={width="missing"}}}}),"recipe validation rejects unknown geometry references at its public boundary")
 local other=library:CreateContext({reducedMotion=true});local otherButton=other.C.Button(parent,"Other",80)
 check(otherButton.label.color~=ctx.Theme.muted,"recipe contexts remain independent")
 local text=C.Text(parent,"Cache","label");text:SetWidth(100)
 local native=text.GetUnboundedStringWidth or text.GetStringWidth;local calls=0
 text.GetUnboundedStringWidth=function(self) calls=calls+1;return native(self) end
 local measured=C.MeasureText(text);C.MeasureText(text)
 check(calls==1,"unchanged text measurements reuse natural widths")
 local getWidth=text.GetWidth;local widths=0
 text.GetWidth=function(self) widths=widths+1;return getWidth(self) end
 check(C.MeasureTextWidth(text)==measured and widths==0,"width-only measurement shares the cache without reading allocated width")
 C.SetFont(text,"heading");check(C.MeasureText(text)>measured and calls==2,"font changes invalidate natural-width measurements")
 local visible=text:GetText();C.MeasureText(text,"Candidate");check(text:GetText()==visible,"candidate measurements preserve visible text")
 for i=1,11 do C.MeasureText(text,"Option "..i) end
 local nativeHeight=text.GetStringHeight;local heights=0
 text.GetStringHeight=function(self) heights=heights+1;return nativeHeight(self) end
 local countNodes=#S.nodes
 for i=1,11 do C.MeasureText(text,"Option "..i) end
 check(heights==0 and #S.nodes==countNodes,"warm candidate measurements retain their individual width, height and allocated-width cache")
 for i=1,40 do text:SetText("Dynamic "..i);C.MeasureText(text) end
 check(text:GetText()=="Dynamic 40","dynamic text remains measurable with a single current-value cache")
 local metricA=C.Text(parent,"First cached label","label")
 local metricB=C.Text(parent,"Second cached label","label")
 local widthA,widthB=C.MeasureTextWidth(metricA),C.MeasureTextWidth(metricB)
 metricA.GetUnboundedStringWidth=function() return widthA*2 end
 metricB.GetUnboundedStringWidth=function() return widthB*2 end
 C.InvalidateTextMetrics(metricA)
 check(C.MeasureTextWidth(metricA)==widthA*2 and C.MeasureTextWidth(metricB)==widthB,"targeted metric invalidation recomputes only its label")
 C.InvalidateTextMetrics()
 check(C.MeasureTextWidth(metricB)==widthB*2,"context metric invalidation also refreshes existing records")
 local candidateBefore=C.MeasureTextWidth(text,"Candidate")
 C.SetFont(text,"caption")
 local candidateAfter=C.MeasureTextWidth(text,"Candidate")
 check(candidateAfter<candidateBefore and text:GetText()=="Dynamic 40","font invalidation refreshes a retained candidate without changing visible text")
 for i=1,40 do C.MeasureTextWidth(text,"Evicted candidate "..i) end
 check(C.MeasureTextWidth(text,"Candidate")==candidateAfter,"candidate eviction and reuse preserve the correct current-font width")
 local left,right=CreateFrame("Frame",nil,parent),CreateFrame("Frame",nil,parent)
 left:SetSize(20,10);right:SetSize(30,10)
 local descriptors={{frame=left},{frame=right}}
 local options={width="content",height=20,gap=4,padding={left=2}}
 local stable=C.Row(parent,descriptors,options);stable:Layout();stable:Layout()
 options.gap=8;stable:Layout()
 check(select(4,right:GetPoint())==30,"stable-layout checks mutable option values")
 options.padding.left=5;stable:Layout()
 check(select(4,left:GetPoint())==5 and select(4,right:GetPoint())==33,"stable-layout checks nested mutable padding")
 descriptors[1].width=40;stable:Layout()
 check(left:GetWidth()==40 and select(4,right:GetPoint())==53,"stable-layout checks mutable item dimensions")
 right:Hide();stable:Layout();check(stable.contentWidth==45,"stable-layout notices native hidden items")
 right:Show();stable:Layout();left:ClearAllPoints();left:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",1,2);stable:Layout()
 check(left:GetPoint()=="TOPLEFT" and select(4,left:GetPoint())==5,"stable-layout repairs externally modified owned native anchors")
 descriptors[1].width=nil;left:SetWidth(22);stable:Layout()
 check(select(4,right:GetPoint())==35,"stable-layout observes external child size changes")
 parent:SetWidth(400);options.anchor="TOPRIGHT";stable:Layout()
 check(select(4,right:GetPoint())==370,"stable-layout observes parent dimensions and anchor changes")
 stable:SetItems({right,left});stable:Layout()
 check(select(4,right:GetPoint())<select(4,left:GetPoint()),"SetItems invalidates stable input order")
 stable:SetOptions({gap="switchInset"});stable:Layout();stable:SetOptions({gap=9});stable:Layout()
 check(select(4,left:GetPoint())-select(4,right:GetPoint())==39,"explicit layout options update resolved input values")
 stable.items[1],stable.items[2]=stable.items[2],stable.items[1];stable:Layout()
 check(select(4,left:GetPoint())<select(4,right:GetPoint()),"in-place item reordering invalidates stable placement")
 local content=C.Text(parent,"A","label");local natural=C.Row(parent,{{frame=content,width="content"}},{width="content",height=20})
 local first=natural:Layout();content:SetText("A much longer string");local second=natural:Layout()
 check(second>first,"content items keep natural measurement after text changes")
 check(not library:GetStyleField("button.base.root.color") and not library:GetStyleField("field.base.root.fontSize") and not library:GetStyleField("checkbox.states.hover.mark.desaturated"),"slot capability metadata rejects naked-frame colors/fonts and non-texture desaturation")
 check(not library:ValidateRecipes({field={base={root={color="brand"}}}}),"unsupported imported properties fail before rendering")
 for _,part in ipairs({{height=-5},{alpha=2},{width=math.huge}}) do
  local defaults={button={base={root=part}}}
  local valid,message=library:ValidateRecipes({},defaults)
  check(not valid and type(message)=="string","recipe default values are validated even with empty startup overrides")
  local before=#S.nodes
  check(not pcall(library.CreateContext,library,{recipeDefaults=defaults}) and #S.nodes==before,"invalid recipe defaults fail context construction before controls are created")
 end
 check(library:ValidateRecipes({},{custom={slotKinds={root="box"},base={root={height=12}}}}),"valid product recipe defaults remain accepted")
 local kinds={custom={slotKinds={root="box",glyph="shape",border="surface"},base={root={},glyph={},border={}}}}
 check(library:GetStyleField("custom.states.hover.glyph.color",kinds).slotKind=="shape" and library:GetStyleField("custom.base.border.radius",kinds).slotKind=="surface","custom slots declare capabilities without allocating decorations")
 check(not library:GetStyleField("custom.slotKinds.glyph",kinds),"slot kind metadata is not a configurable style property")
 local frameOnly=CreateFrame("Frame",nil,parent)
 check(not pcall(C.Style,frameOnly,{style={root={fontSize="heading"}}}),"direct binding rejects unsupported actual native targets once at its boundary")
 local late=C.Text(parent,"Pending metrics","label");late:SetWidth(100)
 local unbounded=late.GetUnboundedStringWidth or late.GetStringWidth;local available=false
 late.GetUnboundedStringWidth=function(self) return available and unbounded(self) or 0 end
 check(C.MeasureTextWidth(late)==0,"temporarily unavailable nonempty text metrics may report zero")
 available=true;check(C.MeasureTextWidth(late)>0,"zero nonempty text width is retried on the next existing layout callback")
 local oldHeight=late.GetStringHeight;available=false;late.GetStringHeight=function(self) return available and oldHeight(self) or 0 end
 C.InvalidateTextMetrics(late);local _,pendingHeight=C.MeasureText(late);available=true;local _,readyHeight=C.MeasureText(late)
 check(pendingHeight==0 and readyHeight>0,"zero nonempty wrapped height is not a permanent cache hit")
 local wrapText=C.Text(parent,"Current text that can wrap",14);wrapText:SetWidth(20);wrapText:SetWordWrap(false)
 local currentText=wrapText:GetText();local candidate="Candidate text that can wrap"
 local _,plainHeight=C.MeasureText(wrapText);local _,plainCandidate=C.MeasureText(wrapText,candidate)
 check(near(plainHeight,plainCandidate) and wrapText:GetText()==currentText,"candidate measurement copies disabled word wrap without changing visible text")
 wrapText:SetWordWrap(true)
 local _,wrappedHeight=C.MeasureText(wrapText);local _,wrappedCandidate=C.MeasureText(wrapText,candidate)
 check(near(wrappedHeight,wrapText:GetStringHeight()) and wrappedHeight>plainHeight and wrappedCandidate>plainCandidate and wrapText:GetText()==currentText,"native wrap changes invalidate current and candidate metrics")
 wrapText:SetWordWrap(false)
 local _,restoredHeight=C.MeasureText(wrapText);local _,restoredCandidate=C.MeasureText(wrapText,candidate)
 check(near(restoredHeight,plainHeight) and near(restoredCandidate,plainCandidate) and wrapText:GetText()==currentText,"word wrap round trip restores current and candidate measurement modes")
 local animated=library:CreateContext();local fill=animated.C.Panel(parent,"panel",4)
 local direct=animated.C.Style(frameOnly,{immediate=true,slots={root=frameOnly,surface=fill},states={hover={surface={color="brand"}}}})
 direct:SetState("hover",true)
 check(fill.color==animated.Theme.brand and not next(animated.Motion.jobs),"immediate style states preserve existing instantaneous feedback")
 local timed=animated.C.Style(CreateFrame("Frame",nil,parent),{duration=.25,slots={root=frameOnly,surface=fill},states={hover={surface={color="good"}}}})
 timed:SetState("hover",true);animated.Motion:Tick(.1)
 check(fill.color~=animated.Theme.good,"state duration preserves an explicit existing feedback period")
 animated.Motion:Tick(.15);check(fill.color==animated.Theme.good,"timed style feedback reaches its target at the requested duration")
 local tallItems={}
 for i=1,6 do local item=CreateFrame("Frame",nil,parent);item:SetSize(100,88);tallItems[i]={frame=item,width="fill"} end
 local tall=C.Column(parent,tallItems,{width=983.2,height="content"});local _,total=tall:Layout()
 check(total==528 and tallItems[1].frame:GetWidth()==983.2 and tallItems[1].frame:GetHeight()==88,"Column content height does not fall back to width or treat cross-axis fill as vertical grow")
 for _,vertical in ipairs({false,true}) do for _,boxed in ipairs({false,true}) do for _,stretch in ipairs({false,true}) do for _,maximum in ipairs({false,true}) do
  local child=CreateFrame("Frame",nil,parent);child:SetSize(10,10)
  local item={frame=child,width=10,height=10};local axis=vertical and "width" or "height"
  local constraint=(maximum and "max" or "min")..(vertical and "Width" or "Height");local limit=maximum and 20 or 120
  if stretch then item.align="stretch" else item[axis]="fill" end
  if boxed then C.Box(child,{[constraint]=limit}) else item[constraint]=limit end
  local layout=(vertical and C.Column or C.Row)(parent,{item},{width=100,height=100});layout:Layout()
  local actual=vertical and child:GetWidth() or child:GetHeight()
  check(actual==limit,(vertical and "Column" or "Row").." cross-axis "..(stretch and "stretch" or "fill").." respects "..(boxed and "Box " or "item ")..constraint)
 end end end end
 local wrapped=C.Text(parent,"A long wrapped content label","label");wrapped:SetWordWrap(true)
 C.Row(parent,{{frame=wrapped,width=30,height="content",maxHeight=20}},{width=100,height=100}):Layout()
 check(wrapped:GetHeight()==20,"Row clamps content text height after width-dependent remeasurement")
 local short=C.Text(parent,"A","label")
 C.Row(parent,{{frame=short,width=30,height="content",minHeight=40}},{width=100,height=100}):Layout()
 check(short:GetHeight()==40,"Row retains content text minimum height after remeasurement")
 local fixedText=C.Text(parent,"A long wrapped content label","label");fixedText:SetWordWrap(true)
 local fixedRow=C.Row(parent,{{frame=fixedText,width=30,height="content"}},{width=100,height=100})
 fixedRow:Layout();local contentHeight=fixedText:GetHeight()
 local fixedHeight=C.Style(fixedText,{style={root={height=60}},states={hover={root={height=80}}}})
 check(fixedText:GetHeight()==60 and fixedRow.contentHeight==60,"Row fixed height overrides the item's content measurement")
 fixedHeight:SetState("hover",true)
 check(fixedText:GetHeight()==80 and fixedRow.contentHeight==80,"Row state height reflows a content text item without remeasuring over the rule")
 fixedHeight:SetState("hover",false)
 check(fixedText:GetHeight()==60 and fixedRow.contentHeight==60,"Row state exit restores its fixed text height")
 fixedHeight:Release();fixedRow:Layout()
 check(near(fixedText:GetHeight(),contentHeight),"Row resumes content text measurement after releasing its fixed height")
 local narrow=C.Text(parent,"A long wrapped content label","label");narrow:SetWordWrap(true)
 C.Column(parent,{{frame=narrow,width="fill",maxWidth=30,height="content"}},{width=100,height="content"}):Layout()
 check(narrow:GetWidth()==30 and near(narrow:GetHeight(),narrow:GetStringHeight()),"Column measures content height at its constrained final cross-axis width")
 local beforeStyle=frameOnly._lycheeStyleController
 check(not pcall(C.Style,frameOnly,{duration="unknown"}) and frameOnly._lycheeStyleController==beforeStyle,"invalid state options are rejected before replacing an existing binding")
 local lazy=library:CreateContext({reducedMotion=true});local toggle=lazy.C.Check(parent,"Later override")
 local lazyController=toggle._lycheeStyleController;local apply=lazyController.Apply;local dispatches=0
 lazyController.Apply=function(self,...) dispatches=dispatches+1;return apply(self,...) end
 toggle:Fire("OnEnter");toggle:Fire("OnLeave")
 check(dispatches==0,"unmodified legacy controls do not dispatch an empty state controller on hover")
 local configured=library:CreateContext({reducedMotion=true,recipes={check={states={hover={surface={color="good"}}}}}})
 local explicit=configured.C.Check(parent,"Startup override");local explicitController=explicit.styleController
 explicit:Fire("OnEnter");check(explicit.track.bg.color==configured.Theme.good,"startup rules participate in component hover")
 local extra=CreateFrame("Frame",nil,parent);explicitController:Bind(extra,{hover=true});explicit:Fire("OnLeave");extra:Fire("OnEnter")
 check(explicit.track.bg.color==configured.Theme.good,"group hover combines with native component state")
 local idleHost=CreateFrame("Frame",nil,parent);local idle=lazy.C.Style(idleHost,{slots={root=idleHost},trackNative=true});idle:Bind(idleHost,{hover=true})
 idleHost:Fire("OnEnter");idleHost:Disable();idleHost:Fire("OnDisable");idleHost:Enable();idleHost:Fire("OnEnable")
 check(not idle.sources[idleHost].hover,"empty controllers still clear transient source state when disabled")
 for _,vertical in ipairs({false,true}) do for _,descriptor in ipairs({false,true}) do
  local first,second=CreateFrame("Frame",nil,parent),CreateFrame("Frame",nil,parent)
  first:SetSize(30,20);second:SetSize(40,20)
  local firstItem={frame=first};local items={firstItem,second}
  local layout=(vertical and C.Column or C.Row)(parent,items,{gap=10})
  layout:Layout()
  if descriptor then firstItem.hidden=true else first:Hide() end
  layout:Measure()
  if descriptor then firstItem.hidden=nil else first:Show() end
  first:ClearAllPoints();first:SetPoint("TOPLEFT",parent,"TOPLEFT",999,-999)
  layout:Layout()
  check(#layout.active==2 and select(4,first:GetPoint())==0 and select(5,first:GetPoint())==0,(vertical and "Column" or "Row").." restores all current items after a temporary "..(descriptor and "descriptor" or "native").." visibility measurement")
  firstItem.width,firstItem.height=80,45
  layout:Measure(180,70)
  firstItem.width,firstItem.height=nil,nil
  first:ClearAllPoints();first:SetPoint("TOPLEFT",parent,"TOPLEFT",999,-999)
  layout:Layout()
  check(first:GetWidth()==30 and first:GetHeight()==20 and select(4,first:GetPoint())==0 and select(5,first:GetPoint())==0,(vertical and "Column" or "Row").." restores placement dimensions after measuring temporary descriptor and available sizes")
  layout:Release()
 end end
 local hiddenDefaults={hiddenAction={base={surface={shown=false},hover={shown=false},label={color="muted"}},states={hover={label={color="brand"}}},variants={reveal={base={surface={shown=true}}}}}}
 local hidden=library:CreateContext({reducedMotion=true,recipeDefaults=hiddenDefaults});local action=hidden.C.Button(parent,"Hidden surface",80,nil,{recipe="hiddenAction"})
 local actionStyle=action.styleController
 action:SetPrimary(true);action:SetSurfaceColors("good","blue","primary");action:Fire("OnEnter");action:Fire("OnMouseDown")
 check(not action.fill:IsShown() and not action.hover:IsShown(),"fixed visibility preserves hidden panels through primary and pressed business states")
 actionStyle:SetVariant("reveal");action:RefreshStyle(true)
 check(action.fill:IsShown() and action.fill:GetAlpha()==1,"a variant can reveal a constructor-hidden surface")
 actionStyle:SetVariant(nil);action:SetAvailable(false);action:SetAvailable(true)
 check(not action.fill:IsShown(),"normal business availability does not replace fixed startup visibility")
end
