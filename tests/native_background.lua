return function(library,S,check)
 local ctx=library:CreateContext({reducedMotion=true});local C=ctx.C
 for _,mode in ipairs({"search","title","multiline"}) do
  local home=CreateFrame("Frame",nil,UIParent);local foreign=CreateFrame("Frame",nil,UIParent)
  local container=mode=="multiline" and CreateFrame("ScrollFrame",nil,home) or nil
  if container then container:SetSize(187,80) end
  local box=CreateFrame("EditBox",nil,container or home);box:SetSize(187,mode=="multiline" and 80 or 18)
  container=container or box
  box:SetText("engine-owned text");box.secureText=true
  local originalChanges,changes=0,0;local original=function() originalChanges=originalChanges+1 end
  box:SetScript("OnTextChanged",original)
  -- Captured client sequence: before reparent both decorations match the input;
  -- after reparent the all-points pure-color fill reports 1x1, border 0x0.
  -- Their native dimensions resolve later, without another explicit style pass.
  local phase="before"
  local fill=box:CreateTexture(nil,"BACKGROUND");fill:SetColorTexture(.02,.02,.02,1);fill:SetAllPoints(box)
  fill.GetWidth=function() return phase=="reparented" and 1 or box:GetWidth() end
  fill.GetHeight=function() return phase=="reparented" and 1 or box:GetHeight() end
  local border=CreateFrame("Frame",nil,box);border:SetAllPoints(box)
  border.GetWidth=function() return phase=="reparented" and 0 or box:GetWidth() end
  border.GetHeight=function() return phase=="reparented" and 0 or box:GetHeight() end
  for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
   local line=border:CreateTexture(nil,"OVERLAY");line:SetTexture(130871);line:SetVertexColor(.25,.25,.25,1)
   line:SetSize((side=="TOP" or side=="BOTTOM") and 187 or .8333,(side=="TOP" or side=="BOTTOM") and .8333 or box:GetHeight()-1.6666)
  end
  local cursor=box:CreateTexture(nil,"OVERLAY");cursor:SetSize(2,14)
  local selection=box:CreateTexture(nil,"OVERLAY");selection:SetSize(30,14);selection:SetAlpha(.75)
  local child=CreateFrame("Button",nil,box);child:SetSize(12,12)
  local setParent=container.SetParent
  container.SetParent=function(self,parent) setParent(self,parent);phase=parent==home and "before" or "reparented" end
  local field=C.Field(UIParent,800,mode=="multiline" and 140 or 54)
  local lease=C.NativeInput(field,box,{container=container,scripts={OnTextChanged=function() changes=changes+1 end}})
  check(phase=="reparented" and fill:GetWidth()==1 and border:GetWidth()==0,mode..": fixture reproduces captured post-reparent native geometry")
  check(lease:IsOwned() and not fill:IsShown() and fill:GetAlpha()==0,mode..": native black fill is hidden on first acquisition before anchor dimensions resolve")
  check(not border:IsShown() and border:GetAlpha()==0,mode..": all four native border strips are hidden on first acquisition")
  check(cursor:IsShown() and cursor:GetAlpha()==1 and selection:IsShown() and selection:GetAlpha()==.75 and child:IsShown(),mode..": cursor, selection and functional child controls remain visible")
  phase="settled"
  check(not fill:IsShown() and not border:IsShown(),mode..": resolving native anchors cannot reveal the old field background")
  box:UserType("typed in native input");box:SetFocus();ctx:SetFont("changed",1.3)
  check(changes==1 and originalChanges==0 and box:GetText()=="typed in native input" and field.focused,mode..": native editing and focus callbacks remain functional")
  lease:Release()
  check(fill:IsShown() and fill:GetAlpha()==1 and border:IsShown() and border:GetAlpha()==1,mode..": release restores the original background and four-line border")
  check(container:GetParent()==home and box:GetScript("OnTextChanged")==original and box:GetText()=="typed in native input",mode..": release restores ownership and scripts without writing engine text")
  lease=C.NativeInput(field,box,{container=container})
  fill:SetAlpha(.6);fill:Show();border:SetAlpha(.55);border:Show();container:SetParent(foreign)
  lease:Release()
  check(fill:GetAlpha()==.6 and fill:IsShown() and border:GetAlpha()==.55 and border:IsShown() and container:GetParent()==foreign,mode..": handoff preserves decorations already changed by the new host")
 end
end
