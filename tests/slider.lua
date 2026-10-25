return function(S,library,check,near)
 local ctx=library:CreateContext()
 local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(300,100)
 local commits,previews={},{}
 local control=ctx.C.Slider(parent,132,75,125,5,function(value) commits[#commits+1]=value end,{
  commitOnRelease=true,onPreview=function(value) previews[#previews+1]=value end,
 })
 local input=control.slider
 check(input.kind=="Frame" and control.thumb.kind=="Button","commit-on-release uses a manual track and a button thumb")
 check(input:GetHeight()==24 and control.thumb:GetWidth()==8 and control.thumb:GetHeight()==12,"manual slider preserves its track hit area and thumb geometry")
 local cursor,pressed=0,false
 local oldCursor,oldMouse=GetCursorPosition,IsMouseButtonDown
 GetCursorPosition=function() return cursor,0 end
 IsMouseButtonDown=function(button) return button=="LeftButton" and pressed end
 local scale,left,width=input:GetEffectiveScale(),input:GetLeft(),input:GetWidth()
 local function Move(value) cursor=(left+(value-75)/50*width)*scale end
 local function Begin(value,target) pressed=true;Move(value);(target or input):Fire("OnMouseDown","LeftButton") end
 control:SetValue(100)
 check(#commits==0 and control:GetValue()==100,"programmatic values never commit")
 Begin(105)
 check(control:IsDragging() and control:GetValue()==105 and previews[#previews]==105 and #commits==0,"track press previews its snapped value")
 Move(110);input:Fire("OnUpdate",.016)
 local getScale,getLeft=input.GetEffectiveScale,input.GetLeft
 input.GetEffectiveScale=function() error("drag must use captured scale") end
 input.GetLeft=function() error("drag must use captured origin") end
 Move(107.4);input:Fire("OnUpdate",.016)
 check(control:GetValue()==110,"dead band prevents oscillation across step boundaries")
 Move(106.6);input:Fire("OnUpdate",.016)
 check(control:GetValue()==105,"movement beyond the dead band changes the preview")
 Move(115);input:Fire("OnUpdate",.016)
 pressed=false;input:Fire("OnMouseUp","LeftButton")
 check(#commits==1 and commits[1]==115 and not control:IsDragging(),"mouse-up commits once and clears drag ownership")
 check(input:GetScript("OnUpdate")==nil,"release removes the sampler before callback completion")
 input:Fire("OnMouseUp","LeftButton");control:FinishDrag(true)
 check(#commits==1,"duplicate release does not commit again")
 input.GetEffectiveScale,input.GetLeft=getScale,getLeft
 Begin(75,control.thumb);Move(200);pressed=false;input:Fire("OnUpdate",.016)
 check(#commits==2 and commits[2]==125 and not control:IsDragging(),"thumb drag clamps and commits an outside release")
 Begin(75);control:Hide();pressed=false
 check(control:GetValue()==125 and previews[#previews]==125 and #commits==2,"hide restores the starting value and preview without committing")
 check(not control:IsDragging() and input:GetScript("OnUpdate")==nil,"hide removes all drag sampling")
 control:Show();Begin(100);control:FinishDrag(false);pressed=false
 check(control:GetValue()==125 and #commits==2,"explicit cancellation restores the drag's original value")
 local calls=0
 local native=ctx.C.Slider(parent,132,0,100,5,function() calls=calls+1 end)
 native:SetValue(30)
 check(native.slider.kind=="Slider" and native:GetValue()==30 and calls==0,"default slider remains native and programmatic updates stay silent")
 check(native.progress:GetFrameLevel()>native.track:GetFrameLevel(),"native fill draws over its track")
 check(near(native.progress:GetWidth(),native:GetWidth()*.3),"native slider fills from its left edge to the selected value")
 native:SetValue(0);check(native.progress:GetAlpha()==0,"native minimum has no visible filled length")
 native:SetValue(100);check(near(native.progress:GetWidth(),native:GetWidth()),"native maximum fills the whole track")
 native:SetValue(30);native.slider:SetWidth(200);native.slider:Fire("OnSizeChanged")
 check(near(native.progress:GetWidth(),60),"native fill follows a resized track without another input event")
 native.slider:Fire("OnValueChanged",35)
 check(calls==1 and not native:IsDragging(),"default slider preserves immediate input callbacks")
 check(near(native.progress:GetWidth(),70),"native value events update the fill before notifying the consumer")
 for _,mode in ipairs({"cancel","hide"}) do
  local candidate;local cancelOnPreview=false;local changed=0
  candidate=ctx.C.Slider(parent,132,0,100,5,function() changed=changed+1 end,{
   commitOnRelease=true,onPreview=function()
    if not cancelOnPreview then return end
    cancelOnPreview=false
    if mode=="hide" then candidate:Hide() else candidate:FinishDrag(false) end
   end,
  })
  candidate:SetValue(75);cancelOnPreview=true
  cursor=(candidate.slider:GetLeft()+candidate.slider:GetWidth()*.9)*candidate.slider:GetEffectiveScale()
  pressed=true;candidate.slider:Fire("OnMouseDown","LeftButton");pressed=false
  check(not candidate:IsDragging() and candidate:GetValue()==75 and changed==0,"preview callback "..mode.." restores the initial value without committing")
  check(candidate.slider:GetScript("OnUpdate")==nil,"preview callback "..mode.." leaves no stale sampler after Begin returns")
  candidate:Show();candidate.slider:Fire("OnUpdate",.016)
  check(changed==0 and candidate:GetValue()==75,"reopening after preview "..mode.." has no deferred drag work")
 end
 for _,manual in ipairs({false,true}) do
  local commits=0
  local fixed=ctx.C.Slider(parent,132,25,25,1,function(value) commits=commits+1;check(value==25,"a zero-range slider only commits its sole value") end,{commitOnRelease=manual})
  check(fixed:GetValue()==25 and fixed.progress.w==0,"a zero-range slider starts at its sole value with finite empty progress")
  fixed:SetValue(manual and 100 or 25)
  check(fixed:GetValue()==25 and fixed.progress.w==0 and commits==0,"programmatic updates keep zero-range progress finite and silent")
  if manual then
   pressed=true;fixed.slider:Fire("OnMouseDown","LeftButton");pressed=false;fixed.slider:Fire("OnMouseUp","LeftButton")
   check(not fixed:IsDragging() and fixed.slider:GetScript("OnUpdate")==nil and commits==1 and select(4,fixed.thumb:GetPoint())==0,"a zero-range manual drag keeps its thumb at the origin and releases sampling")
  else
   fixed.slider:SetWidth(200)
   check(fixed.progress.w==0,"resizing a zero-range native slider keeps finite empty progress")
  end
 end
 GetCursorPosition,IsMouseButtonDown=oldCursor,oldMouse
end
