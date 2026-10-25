return function(library,S,check)
 local ctx=library:CreateContext();local C=ctx.C
 local original=CreateFrame("Frame",nil,UIParent)
 local native=CreateFrame("EditBox",nil,original);native:SetSize(180,24);native:SetPoint("LEFT",original,"LEFT",3,4)
 native.Instructions=C.Text(native,"Native placeholder",12,{.4,.5,.6,1})
 native:SetFrameStrata("HIGH");native:SetFrameLevel(5)
 native:SetText("engine text");native.secureText=true
 local stockChanges,ownChanges,lost=0,0,0
 local changed=function() stockChanges=stockChanges+1 end
 native:SetScript("OnTextChanged",changed)
 local shell=C.Edit(UIParent,320,44);local ordinary=shell.box;local count=#ctx.inputs
 local lease=C.NativeInput(shell,native,{scripts={OnTextChanged=function() ownChanges=ownChanges+1 end},onLost=function() lost=lost+1 end})
 check(lease:IsOwned() and shell.box==native and not ordinary:IsShown(),"native input keeps engine identity in the shared field")
 check(#ctx.inputs==count+1 and native:GetText()=="engine text","native input adds one focus owner without writing text")
 check(select(1,native.Instructions:GetTextColor())==ctx.Theme.muted[1],"native placeholder uses the legible secondary text color while borrowed")
 native:SetFocus();check(shell.focused,"native focus drives shared field surface")
 native:UserType("12-15");check(ownChanges==1 and stockChanges==0,"explicit text callback replaces layout-dependent native callback while borrowed")
 native:SetFrameStrata("DIALOG");native:SetFrameLevel(20)
 lease:Release()
 check(native:GetFrameStrata()=="HIGH" and native:GetFrameLevel()==5,"release restores original strata and level")
 check(native:GetParent()==original and native:GetWidth()==180 and select(1,native:GetPoint())=="LEFT","release restores native geometry")
 check(native:GetScript("OnTextChanged")==changed and shell.box==ordinary and ordinary:IsShown(),"release restores scripts and ordinary edit")
 check(#ctx.inputs==count and not native:HasFocus() and native:GetText()=="12-15","release removes focus ownership while preserving native text")
 check(select(2,native.Instructions:GetFont())==12 and select(1,native.Instructions:GetTextColor())==.4,"releasing the input restores its original placeholder font and color")
 lease=C.NativeInput(shell,native,{scripts={OnTextChanged=function() ownChanges=ownChanges+1 end},onLost=function() lost=lost+1 end})
 local foreign=CreateFrame("Frame",nil,UIParent);native:SetParent(foreign);native:SetFont("foreign",19,"")
 native:Fire("OnTextChanged",false)
 check(not lease.active and lost==1 and stockChanges==1,"a foreign handoff releases and delegates to the prior callback")
 check(native:GetParent()==foreign and native:GetFont()=="foreign","lost lease never restores over the new host's layout or font")
 check(#ctx.inputs==count,"foreign handoff releases its focus registry slot")
 -- A client/font layer can normalize setters. Ownership compares the values
 -- read back after styling, not the unnormalized arguments sent to setters.
 native:SetFont("original",12,"");native:SetTextColor(.4,.5,.6,1)
 local setFont,setColor=native.SetFont,native.SetTextColor
 native.SetFont=function(self,path,size,flags) setFont(self,path,size==14 and 15.0000019 or size,flags) end
 native.SetTextColor=function(self,r,g,b,a) setColor(self,r+0.00000003,g+0.00000003,b+0.00000003,a) end
 lease=C.NativeInput(shell,native)
 native:SetParent(original);native:Fire("OnSizeChanged")
 check(not lease.active and select(2,native:GetFont())==12,"handoff restores the prior font after client size normalization")
 check(math.abs(select(1,native:GetTextColor())-.4)<.000001,"handoff restores prior color after native float normalization")
 native.SetFont,native.SetTextColor=setFont,setColor
 native:SetParent(foreign)
 lease=C.NativeInput(shell,native)
 ctx:Hide()
 check(not lease.active and native:GetParent()==foreign and #ctx.inputs==count,"context hide releases native controls")
 local other=library:CreateContext()
 check(next(other.nativeControls)==nil and other.nativeControls~=ctx.nativeControls,"contexts independently own native leases")
 -- Multiline input retains its registered scroll container and native cursor script.
 local scroll=CreateFrame("ScrollFrame",nil,original);scroll:SetSize(180,80)
 local note=CreateFrame("EditBox",nil,scroll);note:SetWidth(150);note.secureText=true
 note.Instructions=C.Text(note,"Native multiline placeholder",12,{.4,.5,.6,1},150)
 local cursor=function() end;note:SetScript("OnCursorChanged",cursor)
 -- Retail InputScrollFrameTemplate owns a MinimalScrollBar, not a Slider.
 local bar=CreateFrame("Frame",nil,scroll);scroll.ScrollBar=bar;bar:SetWidth(8)
 local track=CreateFrame("Frame",nil,bar);bar.Track=track
 local thumb=CreateFrame("Button",nil,track);track.Thumb=thumb;thumb:SetSize(8,23)
 local function Art(owner,key,atlas)
  local texture=owner:CreateTexture(nil,"ARTWORK");texture:SetAtlas(atlas);owner[key]=texture;return texture
 end
 for _,key in ipairs({"Begin","Middle","End"}) do Art(track,key,"minimal-track-"..key);Art(thumb,key,"minimal-thumb-"..key) end
 thumb.Begin:SetAlpha(.65);track.End:Hide()
 for _,key in ipairs({"Back","Forward"}) do bar[key]=CreateFrame("Button",nil,bar);Art(bar[key],"Texture","minimal-arrow-"..key) end
 local function State(state)
  for _,key in ipairs({"Begin","Middle","End"}) do thumb[key]:SetAtlas("minimal-thumb-"..key..state) end
 end
 local range=function(_,_,vertical) bar:SetShown(vertical>0);thumb:SetShown(vertical>0);thumb:SetHeight(vertical>0 and 36 or 23) end
 local wheel=function(_,delta) scroll:SetVerticalScroll(scroll:GetVerticalScroll()-delta*30) end
 local drag=function() State("-down");scroll:SetVerticalScroll(42) end
 scroll:SetScript("OnScrollRangeChanged",range);scroll:SetScript("OnMouseWheel",wheel)
 thumb:SetScript("OnEnter",function() State("-over") end);thumb:SetScript("OnLeave",function() State("") end)
 thumb:SetScript("OnMouseDown",drag);thumb:SetScript("OnMouseUp",function() State("") end)
 scroll:Fire("OnScrollRangeChanged",0,0)
 local field=C.Field(UIParent,320,96)
 local multiline=C.NativeInput(field,note,{container=scroll})
 check(note:GetParent()==scroll and scroll:GetParent()==field and note:GetScript("OnCursorChanged")==cursor,"multiline native input preserves scrolling and cursor behavior")
 check(note.Instructions:GetWidth()==note:GetWidth() and note:GetWidth()==284,"multiline placeholder uses the expanded input width instead of wrapping at the native width")
 note:UserType("Keep native text while resizing")
 field:SetSize(460,160);scroll:SetSize(440,146)
 check(note:GetWidth()==424 and note.Instructions:GetWidth()==424,"resizing the native viewport updates text and placeholder wrapping width")
 field:SetSize(280,96);scroll:SetSize(260,82)
 check(note:GetWidth()==244 and note.Instructions:GetWidth()==244,"shrinking the native viewport restores the current content width")
 check(note:GetText()=="Keep native text while resizing","native viewport resize preserves the engine-owned text")
 local skin=thumb._lycheeNativeScrollArt
 check(skin~=nil and not thumb.Begin:IsShown() and not track.Begin:IsShown() and not bar.Back.Texture:IsShown(),"native multiline leases replace the nested scrollbar art, not only the input border")
 check(not bar:IsShown() and not thumb:IsShown(),"skinning does not force an unscrollable native bar visible")
 scroll:Fire("OnScrollRangeChanged",0,100);scroll:Fire("OnMouseWheel",-1);thumb:Fire("OnEnter");thumb:Fire("OnMouseDown")
 check(bar:IsShown() and thumb:IsShown() and scroll:GetVerticalScroll()==42 and thumb:GetScript("OnMouseDown")==drag and scroll:GetScript("OnMouseWheel")==wheel,"overflow, wheel and thumb dragging still use the original native controls and callbacks")
 local first,relative=skin:GetPoint();local last,lastRelative=skin:GetPoint(2)
 check(skin:GetWidth()==6 and skin.fill[1]==ctx.Theme.accent[1] and skin.fill[2]==ctx.Theme.accent[2] and first=="TOP" and last=="BOTTOM" and relative==thumb and lastRelative==thumb,"the six-pixel brand thumb follows the native thumb's live height and position")
 check(skin:IsShown() and not thumb.Middle:IsShown() and thumb.Middle:GetAtlas()=="minimal-thumb-Middle-down","native hover and drag atlas changes cannot uncover the original gray thumb")
 thumb:Fire("OnMouseUp");thumb:Fire("OnLeave");scroll:Fire("OnScrollRangeChanged",0,0)
 check(not bar:IsShown() and not thumb:IsShown() and skin:IsShown(),"native overflow logic still hides the complete bar without separate skin polling")
 multiline:Release();check(scroll:GetParent()==original and note:GetWidth()==150,"multiline release restores container and child width")
 check(note.Instructions:GetWidth()==150,"multiline release restores the original placeholder width")
 check(not skin:IsShown() and thumb.Begin:IsShown() and thumb.Begin:GetAlpha()==.65 and not track.End:IsShown() and bar.Back.Texture:IsShown(),"release removes our thumb and restores the native scrollbar's original art visibility and alpha")
 check(scroll:GetScript("OnScrollRangeChanged")==range and scroll:GetScript("OnMouseWheel")==wheel and thumb:GetScript("OnMouseDown")==drag,"releasing a multiline lease never replaces native scrolling scripts")
 local nativeNodes=#S.nodes
 multiline=C.NativeInput(field,note,{container=scroll})
 check(#S.nodes==nativeNodes and thumb._lycheeNativeScrollArt==skin and skin:IsShown(),"reopening a native multiline input reuses its one thumb texture")
 scroll:SetParent(foreign);scroll:Fire("OnSizeChanged")
 check(not multiline.active and scroll:GetParent()==foreign and not skin:IsShown() and thumb.Begin:GetAlpha()==.65 and bar.Forward.Texture:IsShown(),"a foreign container handoff releases our skin and restores native art without moving the new host")
 check(note.Instructions:GetWidth()==150,"foreign handoff returns the placeholder width when the new host has not changed it")
 multiline=C.NativeInput(field,note,{container=scroll})
 note.Instructions:SetWidth(210);scroll:SetParent(original);scroll:Fire("OnSizeChanged")
 check(not multiline.active and note.Instructions:GetWidth()==210,"foreign handoff preserves a placeholder width already set by the new host")
 local nativeButton=CreateFrame("Button",nil,original);nativeButton:SetText("Native submit");nativeButton:SetAlpha(.8)
 local label=C.Text(nativeButton,"Native submit",12);nativeButton.GetFontString=function() return label end
 local clicks=0;local onClick=function() clicks=clicks+1 end;nativeButton:SetScript("OnClick",onClick)
 local submit=C.NativeButton(nativeButton)
 nativeButton:Fire("OnEnter");ctx.Motion:Tick(.12);nativeButton:Fire("OnMouseDown");ctx.Motion:Tick(.12)
 check(submit.fill.color==ctx.Theme.primaryPressed and label:GetAlpha()==1,"native button shares the pressed surface without changing label alpha")
 nativeButton:Fire("OnMouseUp");ctx.Motion:Tick(.12)
 check(submit.fill.color==ctx.Theme.primaryHover and nativeButton:GetScript("OnClick")==onClick and clicks==0,"native visual events preserve the original submit callback without invoking it")
 nativeButton:SetEnabled(false);nativeButton:Fire("OnDisable");nativeButton:Fire("OnEnter");ctx.Motion:Tick(.12)
 check(nativeButton:GetAlpha()==.38 and submit.fill.color==ctx.Theme.primary,"native disabled state dims the complete control and ignores hover")
 submit:Release()
 check(nativeButton:GetAlpha()==.8 and nativeButton:GetScript("OnClick")==onClick and ctx.Motion:Count()==0,"native release restores opacity and removes pending surface work")
 do
  local owner=library:CreateContext();local controls=owner.C
  local home=CreateFrame("Frame",nil,UIParent)
  local input=CreateFrame("EditBox",nil,home);input:SetSize(180,24)
  local field=controls.Field(UIParent,300,44)
  local lostCalls,finishes,restores=0,0,0
  local reentrant=controls.NativeInput(field,input,{scripts={OnEditFocusLost=function()
   lostCalls=lostCalls+1;owner:ReleaseNativeControls()
  end}})
  local finish,setParent=reentrant.finish,input.SetParent
  function reentrant:finish(owned) finishes=finishes+1;finish(self,owned) end
  function input:SetParent(parent) restores=restores+1;setParent(self,parent) end
  input:SetFocus();reentrant:Release()
  check(lostCalls==1 and finishes==1 and restores==1,"a focus callback can release the context without repeating lease cleanup")
  check(not reentrant.active and input:GetParent()==home and #owner.inputs==0,"reentrant release restores the original host and clears registration")
  local foreign=CreateFrame("Frame",nil,UIParent);local lost=0
  local moved=controls.NativeInput(field,input,{scripts={OnEditFocusLost=function() input:SetParent(foreign) end},onLost=function() lost=lost+1 end})
  input:SetFocus();moved:Release()
  check(input:GetParent()==foreign and lost==1 and not moved.active,"release rechecks ownership after a focus callback transfers the input")
  local ordinary=controls.Edit(UIParent,300,44);local originalBox=ordinary.box;local focusLease
  focusLease=controls.NativeInput(ordinary,input,{scripts={OnEditFocusGained=function() input:SetParent(home);focusLease:Release() end}})
  input:SetFocus()
  check(not focusLease.active and ordinary.box==originalBox and input:GetParent()==home,"focus callback release returns the ordinary edit without moving the new host")
  check(not ordinary.focused and not ordinary.focus:IsShown() and input:HasFocus(),"a released input handler cannot light the old shell after a foreign handoff")
  local button=CreateFrame("Button",nil,home);button:SetText("Submit")
  local text=controls.Text(button,"Submit",12);button.GetFontString=function() return text end
  local enters=0;button:SetScript("OnEnter",function() enters=enters+1;owner:Hide() end)
  local borrowed=controls.NativeButton(button);button:Fire("OnEnter")
  check(enters==1 and not borrowed.active and not borrowed.fill:IsShown(),"a native button callback may close its context and release the appearance")
  check(owner.Motion:Count()==0 and not owner.Motion.running,"released native buttons do not restart visual work after their original callback")
 end
 do
  local owner=library:CreateContext();local controls=owner.C
  local home=CreateFrame("Frame",nil,UIParent)
  local input=CreateFrame("EditBox",nil,home);input:SetSize(180,24)
  local shell=controls.Edit(UIParent,300,44);local ordinary=shell.box;local count=#owner.inputs
  ordinary:HookScript("OnEditFocusLost",function() owner:Hide() end);ordinary:SetFocus()
  local lease=controls.NativeInput(shell,input)
  check(not lease.active and input:GetParent()==home and shell.box==ordinary and ordinary:IsShown(),"clearing the ordinary input may close the context before NativeInput takes the native field")
  check(#owner.inputs==count and next(owner.nativeControls)==nil,"cancelled NativeInput initialization never appends an inactive input registration")
 end
 do
  local owner=library:CreateContext();local controls=owner.C
  local home=CreateFrame("Frame",nil,UIParent)
  local input=CreateFrame("EditBox",nil,home);input:SetSize(180,24)
  local shell=controls.Edit(UIParent,300,44);local ordinary=shell.box;local count=#owner.inputs
  ordinary:HookScript("OnHide",function() owner:Hide() end)
  local lease=controls.NativeInput(shell,input)
  check(not lease.active and input:GetParent()==home and shell.box==ordinary and ordinary:IsShown(),"ordinary OnHide cancellation restores its original visibility before NativeInput returns")
  owner:Resume();shell:Hide();shell:Show()
  check(shell.box==ordinary and ordinary:IsShown() and #owner.inputs==count and next(owner.nativeControls)==nil,"reopening a shell after ordinary OnHide cancellation retains its visible ordinary input")
 end
 for _,event in ipairs({"OnEditFocusLost","OnHide"}) do
  for _,target in ipairs({"container","box","owner"}) do
   local owner=library:CreateContext();local controls=owner.C
   local home=CreateFrame("Frame",nil,UIParent);local foreign=CreateFrame("Frame",nil,UIParent)
   local container=CreateFrame("ScrollFrame",nil,home);container:SetSize(180,80)
   local input=CreateFrame("EditBox",nil,container);input:SetSize(150,24);input:SetFont("original",12,"")
   local shell=controls.Edit(UIParent,300,96);local ordinary=shell.box;local count=#owner.inputs
   local host=CreateFrame("Frame",nil,home);local hostLease=controls.NativeFrame(host,UIParent)
   ordinary:HookScript(event,function()
    if target=="owner" then hostLease:Release()
    else (target=="container" and container or input):SetParent(foreign) end
   end)
   if event=="OnEditFocusLost" then ordinary:SetFocus() end
   local lost=0
   local lease=controls.NativeInput(shell,input,{container=container,owner=hostLease,onLost=function() lost=lost+1 end})
   check(not lease.active and lost==1 and shell.box==ordinary and ordinary:IsShown(),"ordinary "..event.." "..target.." handoff stops NativeInput acquisition and restores its shell")
   check(container:GetParent()==(target=="container" and foreign or home) and input:GetParent()==(target=="box" and foreign or container),"ordinary "..event.." "..target.." handoff keeps the native controls at their new host")
   check(#owner.inputs==count and select(2,input:GetFont())==12 and not shell.focused,"ordinary "..event.." "..target.." handoff leaves no input registration or borrowed presentation")
   hostLease:Release()
  end
 end
 for _,event in ipairs({"OnSizeChanged","OnShow"}) do
  for _,mode in ipairs({"hide","handoff"}) do
   local owner=library:CreateContext();local controls=owner.C
   local home=CreateFrame("Frame",nil,UIParent);local foreign=CreateFrame("Frame",nil,UIParent)
   local input=CreateFrame("EditBox",nil,home);input:SetSize(180,24);if event=="OnShow" then input:Hide() end
   local shell=controls.Edit(UIParent,300,44);local ordinary=shell.box;local count=#owner.inputs
   local once=true;local lost=0
   local callback=function(self)
    if not once then return end;once=false
    if mode=="hide" then owner:Hide() else self:SetParent(foreign) end
   end
   input:SetScript(event,callback)
   local lease=controls.NativeInput(shell,input,{onLost=function() lost=lost+1 end})
   check(not lease.active and input:GetParent()==(mode=="hide" and home or foreign) and shell.box==ordinary,"NativeInput stops initialization after native "..event.." "..mode)
   check(#owner.inputs==count and next(owner.nativeControls)==nil and ordinary:IsShown(),"NativeInput "..event.." "..mode.." restores its shell without an inactive input slot")
   check(input:GetScript(event)==callback and (mode~="handoff" or lost==1),"NativeInput "..event.." "..mode.." returns the original script and reports a handoff once")
  end
 end
 for _,event in ipairs({"OnSizeChanged","OnShow"}) do
  for _,mode in ipairs({"hide","handoff"}) do
   local owner=library:CreateContext();local controls=owner.C
   local home=CreateFrame("Frame",nil,UIParent);local foreign=CreateFrame("Frame",nil,UIParent)
   local button=CreateFrame("Button",nil,home);button:SetSize(60,24);button:SetText("Native");button:Hide()
   local label=controls.Text(button,"Native",12);button.GetFontString=function() return label end
   local decoration=button:CreateTexture(nil,"BACKGROUND");decoration:SetTexture(130871);decoration:SetAlpha(.7)
   local once=true;local lost=0;local calls=0
   local callback=function(self)
    calls=calls+1
    if not once then return end;once=false
    if mode=="hide" then owner:Hide() else self:SetParent(foreign) end
   end
   button:SetScript(event,callback)
   local lease=controls.NativeButton(button,{onLost=function() lost=lost+1 end})
   check(not lease.active and button:GetParent()==(mode=="hide" and home or foreign) and not lease.fill:IsShown(),"NativeButton stops initialization and removes its fill after native "..event.." "..mode)
   check(select(2,label:GetFont())==12 and decoration:IsShown() and decoration:GetAlpha()==.7,"NativeButton "..event.." "..mode.." restores borrowed font and decoration")
   local before=calls;button:Fire(event)
   check(calls==before+1 and next(owner.nativeControls)==nil and (mode~="handoff" or lost==1),"NativeButton "..event.." "..mode.." preserves its original callback without an active lease")
  end
 end
 for _,event in ipairs({"OnSizeChanged","OnShow"}) do
  local owner=library:CreateContext();local controls=owner.C
  local home=CreateFrame("Frame",nil,UIParent);local foreign=CreateFrame("Frame",nil,UIParent)
  local button=CreateFrame("Button",nil,home);button:SetSize(60,24);button:SetText("Native");button:Hide()
  local label=controls.Text(button,"Native",12);button.GetFontString=function() return label end
  local once=true
  button:SetScript(event,function(self)
   if not once then return end;once=false
   self:SetParent(foreign);self:SetSize(321,45);self:SetText("Foreign");self:SetAlpha(.73)
   label:SetFont("foreign-font",21,"OUTLINE");label:SetTextColor(.2,.3,.4,.5)
  end)
  local lease=controls.NativeButton(button,{text="Borrowed"})
  check(not lease.active and next(owner.nativeControls)==nil and not lease.fill:IsShown(),"NativeButton "..event.." handoff ends acquisition and cleans its lease")
  check(button:GetParent()==foreign and button:GetWidth()==321 and button:GetHeight()==45 and button:GetText()=="Foreign","NativeButton "..event.." handoff preserves the new host's size and text")
  check(label:GetFont()=="foreign-font" and select(2,label:GetFont())==21 and select(3,label:GetFont())=="OUTLINE" and label:GetTextColor()==.2 and button:GetAlpha()==.73,"NativeButton "..event.." handoff preserves the new host's font, color and alpha")
 end
end
