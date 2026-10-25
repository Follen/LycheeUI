-- A focused UI substitute: native identity, parenting, visibility and scripts,
-- not a claim about game rendering, security/taint or protected API permissions.
local S={nodes={}}
local N={}
N.__index=function(self,key)
 if key=="GetLineHeight" and self._objectType~="FontString" then return nil end
 return N[key]
end
local function Fire(self,event,...) local f=self.scripts[event];if f then f(self,...) end end
function S.New(kind,name,parent)
 local n=setmetatable({kind=kind,_objectType=kind,parent=parent,children={},shown=true,enabled=true,alpha=1,points={},scripts={},events={},text="",w=0,h=0,font={"font",14,""}},N)
 S.nodes[#S.nodes+1]=n;if parent then parent.children[#parent.children+1]=n end
 if name then _G[name]=n end
 return n
end
function N:SetScript(k,v) self.scripts[k]=v end
function N:GetScript(k) return self.scripts[k] end
function N:HookScript(k,v)
 local previous=self.scripts[k]
 self.scripts[k]=function(self,...) if previous then previous(self,...) end;v(self,...) end
end
function N:Fire(k,...) Fire(self,k,...) end
function N:RegisterEvent(k) self.events[k]=true end
function N:UnregisterEvent(k) self.events[k]=nil end
function N:GetParent() return self.parent end
function N:GetChildren() local children={};for _,child in ipairs(self.children) do if child._objectType~="Texture" and child._objectType~="FontString" then children[#children+1]=child end end;return unpack(children) end
function N:SetParent(parent) if self.parent then for i,n in ipairs(self.parent.children) do if n==self then table.remove(self.parent.children,i);break end end end;self.parent=parent;parent.children[#parent.children+1]=self end
function N:Show() local was=self.shown;self.shown=true;if not was then Fire(self,"OnShow") end end
function N:Hide() local was=self.shown;self.shown=false;if was then Fire(self,"OnHide") end end
function N:IsShown() return self.shown end
function N:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function N:SetShown(v) if v then self:Show() else self:Hide() end end
function N:SetSize(w,h) local changed=self.w~=w or self.h~=h;self.w=w;self.h=h;if changed then Fire(self,"OnSizeChanged",w,h) end end
function N:SetWidth(w) self:SetSize(w,self.h) end
function N:SetHeight(h) self:SetSize(self.w,h) end
function N:GetWidth() return self.w>0 and self.w or self.parent and self.parent:GetWidth() or 0 end
function N:GetHeight() return self.h>0 and self.h or self.parent and self.parent:GetHeight() or 0 end
function N:ClearAllPoints() self.points={};self.allPoints=nil end
function N:SetPoint(...) local p={...};for i,v in ipairs(self.points) do if v[1]==p[1] then self.points[i]=p;return end end;self.points[#self.points+1]=p end
function N:GetNumPoints() return #self.points end
function N:GetPoint(i) return unpack(self.points[i or 1] or {}) end
function N:SetAllPoints(parent) self.allPoints=parent or self.parent;self.points={} end
function N:GetRight() return self:GetWidth() end
function N:GetLeft() return 0 end
function N:GetTop() return self:GetHeight() end
function N:IsMouseOver() return self.mouseOver==true end
function N:UnregisterAllEvents() self.events={} end
function N:SetScale(v) self.scale=v end
function N:GetScale() return self.scale or 1 end
function N:GetEffectiveScale() return self:GetScale()*(self.parent and self.parent:GetEffectiveScale() or 1) end
function N:SetAlpha(v)
 self.alpha=v
 if self._objectType=="Texture" then self.vertex=self.vertex or {1,1,1,1};self.vertex[4]=v end
end
function N:GetAlpha() return self.alpha end
function N:SetFont(...) self.font={...};return true end
function N:GetFont() return unpack(self.font) end
function N:SetText(v) assert(not self.secureText,"addon SetText on protected text");self.text=tostring(v);Fire(self,"OnTextChanged",false) end
function N:UserType(v) self.text=v;Fire(self,"OnTextChanged",true) end
function N:GetText() return self.text end
function N:GetStringWidth()
 local width=0
 for ch in self.text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do width=width+(#ch>1 and 1 or .55)*(self.font[2] or 14) end
 return width
end
N.GetUnboundedStringWidth=N.GetStringWidth
function N:GetStringHeight()
 local lines=0
 for line in (self.text.."\n"):gmatch("(.-)\n") do
  local count=0;for ch in line:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do count=count+(#ch>1 and 1 or .55) end
  lines=lines+math.max(1,self.wrap and math.ceil(count*(self.font[2] or 14)/math.max(1,self.w)) or 1)
 end
 if self.maxLines then lines=math.min(lines,self.maxLines) end
 return lines*((self.font[2] or 14)*1.2+(self.spacing or 0))
end
function N:SetSpacing(v) self.spacing=v end
function N:GetSpacing() return self.spacing or 0 end
function N:GetLineHeight() return (self.font[2] or 14)*1.2+(self.spacing or 0) end
function N:SetMaxLines(v) self.maxLines=v end
function N:SetTextColor(...) self.color={...} end
function N:GetTextColor() return unpack(self.color or {1,1,1,1}) end
function N:GetObjectType() return self._objectType end
function N:GetRegions() local regions={};for _,child in ipairs(self.children) do if child._objectType=="Texture" or child._objectType=="FontString" then regions[#regions+1]=child end end;return unpack(regions) end
function N:SetColorTexture(...) self.fill={...} end
function N:SetVertexColor(r,g,b,a) self.vertex={r,g,b,a or 1};self.alpha=a or 1 end
function N:GetVertexColor() return unpack(self.vertex or {1,1,1,1}) end
function N:SetRotation(radians,x,y) self.rotation=radians;if x~=nil then self.rotationPivot={x=x,y=y} end end
function N:SetTexture(v) self.texture=v;self.atlas=nil end
function N:GetTexture() return self.texture end
function N:SetAtlas(v) self.atlas=v;self.texture=nil end
function N:GetAtlas() return self.atlas end
function N:SetTexCoord(...) self.texCoords={...} end
function N:GetTexCoord() return unpack(self.texCoords or {0,1,0,1}) end
function N:GetRotation() return self.rotation or 0,self.rotationPivot or {x=0,y=0} end
function N:SetBlendMode(value) self.blendMode=value end
function N:GetBlendMode() return self.blendMode or "BLEND" end
function N:SetJustifyH(v) self.justify=v end
function N:SetJustifyV(v) self.justifyV=v end
function N:GetJustifyH() return self.justify or "LEFT" end
function N:GetJustifyV() return self.justifyV or "MIDDLE" end
function N:CanWordWrap() return self.wrap==true end
function N:SetWordWrap(v) self.wrap=v end
function N:SetFrameLevel(v) self.level=v end
function N:GetFrameLevel() return self.level or 1 end
function N:SetEnabled(v) self.enabled=v end
function N:IsEnabled() return self.enabled end
function N:Enable() self:SetEnabled(true) end
function N:Disable() self:SetEnabled(false) end
function N:SetFocus() self.focus=true;Fire(self,"OnEditFocusGained") end
function N:ClearFocus() if self.focus then self.focus=false;Fire(self,"OnEditFocusLost") end end
function N:HasFocus() return self.focus==true end
function N:SetChecked(v) self.checked=v end
function N:GetChecked() return self.checked end
function N:SetValue(v) self.value=v;Fire(self,"OnValueChanged",v) end
function N:SetMinMaxValues(a,b) self.min=a;self.max=b end
function N:GetVerticalScroll() return self.scroll or 0 end
function N:SetVerticalScroll(v) self.scroll=v end
function N:GetVerticalScrollRange() return 100 end
function N:SetScrollChild(v) self.scrollChild=v end
function N:CreateTexture(name,layer,template,sublevel) local n=S.New("Texture",name,self);n.layer=layer;n.sublevel=sublevel;return n end
function N:SetDrawLayer(layer,sublevel) self.layer=layer;self.sublevel=sublevel end
function N:GetDrawLayer() return self.layer,self.sublevel or 0 end
function N:CreateFontString(name,layer) local n=S.New("FontString",name,self);n.layer=layer;return n end
function N:SetBackdropColor(...) self.backdropColor={...} end
for _,k in ipairs({"RegisterForDrag","SetMaxLetters","SetMultiLine","SetAutoFocus","SetBackdrop","SetBackdropBorderColor","SetCursorPosition","HighlightText","SetNumeric","RegisterForClicks","EnableMouseWheel","EnableKeyboard","SetPropagateKeyboardInput","SetOrientation","SetClampedToScreen"}) do N[k]=function() end end
function N:SetValueStep(value) self.valueStep=value end
function N:SetObeyStepOnDrag(value) self.obeyStepOnDrag=value end
function N:SetThumbTexture(texture) self.thumbTexture=texture end
function N:GetThumbTexture() return self.thumbTexture end
function N:SetFrameStrata(value) self.strata=value end
function N:GetFrameStrata() return self.strata or "MEDIUM" end

function N:GetBottom() return 0 end
function N:GetValue() return self.value end
function N:GetMinMaxValues() return self.min,self.max end
function N:CreateMaskTexture(name,layer) return S.New("MaskTexture",name,self) end
function N:AddMaskTexture(mask) self.mask=mask end
function N:SetDesaturated(value) self.desaturated=value end
function N:IsDesaturated() return self.desaturated==true end
function N:SetHitRectInsets(left,right,top,bottom) self.hitRect={left,right,top,bottom} end
function N:GetHitRectInsets() if self.hitRect then return unpack(self.hitRect) end;return 0,0,0,0 end
function N:IsMouseEnabled() return self.mouseEnabled==true end
function N:EnableMouse(value) self.mouseEnabled=value end
function N:SetMovable(value) self.movable=value end
function N:StartMoving() self.moving=true end
function N:StopMovingOrSizing() self.moving=false end
function N:GetShadowOffset() return unpack(self.shadow or {0,0}) end
function N:SetShadowOffset(...) self.shadow={...} end
function N:GetTextInsets() return unpack(self.insets or {0,0,0,0}) end
function N:SetTextInsets(...) self.insets={...} end
function S.Install()
 S.nodes={};_G.CreateFrame=S.New
 _G.wipe=function(value) for key in pairs(value) do value[key]=nil end;return value end
 S.preciseNow=0;_G.GetTimePreciseSec=function() return S.preciseNow end
 _G.UIParent=S.New("Frame");UIParent:SetSize(1920,1080)
 _G.STANDARD_TEXT_FONT="font"
 _G.GetLocale=function() return "zhCN" end
 _G.C_Texture={GetAtlasInfo=function() return {leftTexCoord=.2,rightTexCoord=.6,topTexCoord=.4,bottomTexCoord=.8} end}
end
return S
