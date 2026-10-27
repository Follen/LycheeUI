-- Run from LycheeUI: lua tests/icon_style_ownership.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('IconStyleOwnership',private) end
local Library=private.LycheeUI;local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b) return math.abs(a-b)<.000001 end
-- Native Frames have no region color getters. This client's Texture alpha is
-- shared by SetAlpha and the fourth GetVertexColor channel, as in the base stub.
local meta=getmetatable(UIParent);local original=meta.__index
local frameKinds={Frame=true,Button=true,ScrollFrame=true,Slider=true}
local textureMethods={GetVertexColor=true,SetVertexColor=true,IsDesaturated=true,SetDesaturated=true}
meta.__index=function(self,key)
 if frameKinds[self._objectType] and (textureMethods[key] or key=='GetTextColor' or key=='SetTextColor') then return nil end
 if self._objectType=='Texture' then
  if key=='GetTextColor' or key=='SetTextColor' then return nil end
 end
 if type(original)=='function' then return original(self,key) end
 return original[key]
end
local ctx=Library:CreateContext({reducedMotion=true})
local C,T=ctx.C,ctx.Theme
local red,blue={.8,.2,.1,1},{.1,.3,.9,1}
local function rgb(icon,color,message)
 local r,g,b=(icon._lycheeTexture or icon):GetVertexColor()
 check(near(r,color[1]) and near(g,color[2]) and near(b,color[3]),message)
end
local function tint(icon,value,message) rgb(icon,{value,value,value},message) end
local function glyph() local icon=C.Glyph(UIParent,'book',20);icon:SetSelected(false);return icon end

do
 local icon=glyph();local style=C.Style(icon,{style={root={color=red}}})
 icon:SetSelected(true);rgb(icon,red,'selected refresh preserves a declared Glyph color')
 check(not icon.texture:IsDesaturated() and icon.texture:GetAlpha()==1,'color ownership leaves grayscale and alpha selection active')
 icon:SetSelected(false,true);rgb(icon,red,'hover refresh preserves a declared Glyph color')
 check(icon.texture:IsDesaturated() and near(icon.texture:GetAlpha(),T.iconHoverAlpha),'color ownership leaves hover alpha active')
 style:Release();tint(icon,T.iconHoverTint,'release restores the latest default hover tint')
 icon:SetSelected(true);tint(icon,1,'selection resumes after release')
end

for _,state in ipairs({'hover','selected'}) do
 local icon=glyph();local style=C.Style(icon,{states={[state]={root={color=red}}}})
 icon:SetSelected(true);tint(icon,1,state..'-only declaration permits default selected tint outside its state')
 style:SetState(state,true);rgb(icon,red,state..'-only declaration applies while active')
 icon:SetSelected(false,true);rgb(icon,red,state..'-only declaration survives direct selection refresh')
 style:SetState(state,false);tint(icon,T.iconHoverTint,state..' exit restores latest default tint')
 icon:SetSelected(false,false);tint(icon,T.iconIdleTint,state..' exit continues default idle tint')
 style:Apply(true);tint(icon,T.iconIdleTint,state..' inactive reapply retains default state')
 style:Release()
end

for _,slot in ipairs({'icon','glyph'}) do
 local host=C.Button(UIParent,'Owner');host.icon=C.Glyph(host,'book',20)
 local style=ctx:_BindFixedElement(host,{base={[slot]={color=red}},states={hover={[slot]={color=red}},selected={[slot]={color=red}}}},{[slot]=host.icon})
 host:SetActive(true);rgb(host.icon,red,slot..' alias survives Button selected refresh')
 host:Fire('OnEnter');rgb(host.icon,red,slot..' equal hover color survives the old widget action')
 for _=1,5 do host:RefreshStyle();host.icon:SetSelected(false,true);rgb(host.icon,red,slot..' stable repeated refresh preserves its color') end
 style:Release();host:SetActive(false);host:Fire('OnLeave');tint(host.icon,T.iconIdleTint,slot..' release returns to Button defaults')
end

do
 local icon=glyph();local style=C.Style(icon,{style={root={alpha=.4,desaturated=false}}})
 icon:SetSelected(true);icon:SetSelected(false,true)
 check(icon:GetAlpha()==.4 and not icon.texture:IsDesaturated(),'Glyph alpha and grayscale declarations survive selection independently')
 tint(icon,T.iconHoverTint,'alpha ownership leaves default tint active')
 style:Release();check(near(icon:GetAlpha(),T.iconHoverAlpha) and icon.texture:IsDesaturated(),'release restores latest default alpha and grayscale')
 icon:SetSelected(true);check(icon.texture:GetAlpha()==1,'default texture alpha resumes after release')
end

do
 local image=C.GameIcon(UIParent,20);image:SetTexture(12345)
 local style=C.Style(image,{style={root={alpha=.35}}})
 ctx:SetIconState(image,false,true)
 check(image:GetAlpha()==.35 and image:IsDesaturated(),'raw texture alpha ownership preserves grayscale selection')
 tint(image,T.iconHoverTint,'raw texture alpha ownership preserves tint selection')
 style:Release();check(near(image:GetAlpha(),T.iconHoverAlpha),'raw texture release restores latest state alpha')
 ctx:SetIconState(image,true,false)
 check(image:GetTexture()==12345 and not image:IsDesaturated() and image:GetAlpha()==1,'unowned game icon keeps its original art and selected treatment')
 tint(image,1,'unowned game icon keeps selected white tint')
end

do
 local other=Library:CreateContext({reducedMotion=true});local image=glyph()
 local host=CreateFrame('Frame',nil,UIParent);local secondHost=CreateFrame('Frame',nil,UIParent)
 local first=C.Style(host,{slots={icon=image},style={icon={color=red}}})
 local second=other.C.Style(secondHost,{slots={glyph=image},style={glyph={alpha=.45}}})
 image:SetSelected(true);rgb(image,red,'foreign Context alpha ownership does not hide color ownership')
 check(image:GetAlpha()==.45,'foreign Context ownership is found from the actual visual target')
 first:Release();tint(image,1,'releasing color restores defaults while foreign alpha remains owned')
 image:SetSelected(false,true);check(image:GetAlpha()==.45,'remaining foreign alpha is preserved')
 second:Release();check(near(image:GetAlpha(),T.iconHoverAlpha),'last foreign owner releases latest fallback')
 local rebound=C.Style(image,{style={root={color=blue}}});image:SetSelected(true);rgb(image,blue,'rebound style owns color without stale records');rebound:Release();tint(image,1,'rebound release restores current defaults')
 other:Hide()
end

for _,releaseFirst in ipairs({true,false}) do
 local other=Library:CreateContext({reducedMotion=true});local image=glyph()
 local first=C.Style(CreateFrame('Frame',nil,UIParent),{slots={icon=image},style={icon={color=red}}})
 local second=other.C.Style(CreateFrame('Frame',nil,UIParent),{slots={glyph=image},style={glyph={color=blue}}})
 first:Apply(true);second:Apply(true)
 local r,g,b=image.texture:GetVertexColor()
 image:SetSelected(true)
 rgb(image,{r,g,b},'two Context color owners preserve their existing winner during selection')
 if releaseFirst then first:Release();rgb(image,blue,'releasing first color owner reveals the remaining Context') else second:Release();rgb(image,red,'releasing second color owner reveals the remaining Context') end
 image:SetSelected(false,true)
 if releaseFirst then second:Release() else first:Release() end
 tint(image,T.iconHoverTint,'last color owner restores current feedback in either release order')
 other:Hide()
end

do
 local image=glyph();local style=C.Style(image.texture,{style={root={color=blue,alpha=.3,desaturated=false}}})
 image:SetSelected(false,true);rgb(image,blue,'a direct internal Texture declaration is found through the public Glyph method')
 check(image.texture:GetAlpha()==.3 and not image.texture:IsDesaturated(),'direct Texture alpha and grayscale declarations remain independent')
 style:Release();tint(image,T.iconHoverTint,'direct Texture release restores current default tint')
 check(near(image.texture:GetAlpha(),T.iconHoverAlpha) and image.texture:IsDesaturated(),'direct Texture release restores current default alpha and grayscale')
end

do
 local custom=Library:CreateContext({reducedMotion=true,theme={iconIdleTint=.23,iconHoverTint=.67,iconIdleAlpha=.31,iconHoverAlpha=.81}})
 local image=custom.C.Glyph(UIParent,'book',20);image:SetSelected(false)
 local style=custom.C.Style(image,{style={root={color=red}}})
 local writes=0;local native=image.texture.SetVertexColor
 image.texture.SetVertexColor=function(self,...) writes=writes+1;native(self,...) end
 for _=1,120 do image:SetSelected(false,true);style:Apply(true) end
 check(writes==0,'unchanged declared color performs no native tint writes across repeated feedback and application')
 check(near(image.texture:GetAlpha(),.81),'custom Context hover alpha continues under color ownership')
 style:Release();tint(image,.67,'custom Context release resolves its latest feedback baseline')
 custom:Hide()
end

do
 local button=C.Button(UIParent,'Text ownership')
 local style=C.Style(button.label,{style={root={color=red}}})
 button:SetActive(true)
 local r,g,b=button.label:GetTextColor()
 check(r==red[1] and g==red[2] and b==red[3],'Button feedback respects a declaration on the actual label target')
 button:Fire('OnEnter');button:RefreshStyle()
 r,g,b=button.label:GetTextColor();check(r==red[1] and g==red[2] and b==red[3],'label ownership survives repeated hover refresh')
 style:Release();r,g,b=button.label:GetTextColor()
 check(r==T.onSecondaryContainer[1] and g==T.onSecondaryContainer[2] and b==T.onSecondaryContainer[3],'label release restores the latest Button default')
end

do
 -- Reproduce the native probe, including eight-bit color/alpha readback.
 local icon=C.Glyph(UIParent,'book',20);local texture=icon.texture
 local function byte(value) return math.floor(value*255+.5)/255 end
 texture.SetVertexColor=function(self,r,g,b,a) self.vertex={byte(r),byte(g),byte(b),byte(a or 1)};self.alpha=self.vertex[4] end
 texture.SetAlpha=function(self,alpha) self.alpha=byte(alpha);self.vertex[4]=self.alpha end
 local style=C.Style(icon,{style={root={color={.17,.38,.61,1}}}})
 icon:SetSelected(true,false);icon:SetSelected(false,true);icon:SetSelected(false,false)
 check(near(select(4,texture:GetVertexColor()),byte(T.iconIdleAlpha)),'native-style alpha feedback changes the fourth color channel')
 style:Release();tint(icon,byte(T.iconIdleTint),'release immediately restores the latest default RGB after shared-alpha feedback')
 check(near(texture:GetAlpha(),byte(T.iconIdleAlpha)) and texture:IsDesaturated(),'RGB release preserves the latest default alpha and grayscale')
end

do
 local icon=glyph();local style=C.Style(icon,{style={root={color=red}}})
 local foreign={.21,.43,.65,1}
 icon.texture:SetVertexColor(unpack(foreign))
 icon:SetSelected(false,true)
 style:Release();rgb(icon,foreign,'observing known alpha feedback does not adopt an external RGB change')
 check(near(icon.texture:GetAlpha(),T.iconHoverAlpha),'foreign RGB release retains the current feedback alpha')
end

for _,kind in ipairs({'texture','glyph'}) do
 local icon=kind=='texture' and C.Icon(UIParent,20) or C.Glyph(UIParent,'book',20)
 local texture=icon._lycheeTexture or icon
 local originalColor={.22,.44,.66,.64};texture:SetVertexColor(unpack(originalColor))
 if kind=='glyph' then icon:SetAlpha(.83) end
 local originalAlpha=icon:GetAlpha()
 local style=C.Style(icon,{style={root={color=red,alpha=.3}}})
 check(icon:GetAlpha()==.3,kind..' simultaneous explicit alpha wins over color channel alpha')
 style:Release();rgb(icon,originalColor,kind..' combined declaration restores the original RGB')
 check(near(icon:GetAlpha(),originalAlpha),kind..' combined declaration restores the original alpha baseline')
 check(near(select(4,texture:GetVertexColor()),originalColor[4]),kind..' combined declaration does not save its own alpha as a color baseline')
end

for _,releaseColorFirst in ipairs({true,false}) do
 local other=Library:CreateContext({reducedMotion=true})
 local texture=C.Icon(UIParent,20);texture:SetVertexColor(.22,.44,.66,1)
 local color=C.Style(CreateFrame('Frame',nil,UIParent),{slots={icon=texture},style={icon={color=red}},states={hover={icon={color=blue}}}})
 local alpha=other.C.Style(texture,{style={root={alpha=.37}}})
 ctx:SetIconState(texture,false,true)
 check(near(texture:GetAlpha(),.37),'default RGB feedback preserves a separate alpha declaration on the same Texture')
 color:SetState('hover',true)
 rgb(texture,blue,'color state applies while a foreign Context owns alpha')
 check(near(texture:GetAlpha(),.37),'color state change preserves the independent alpha owner')
 color:Apply(true);check(near(texture:GetAlpha(),.37),'explicit color application preserves the independent alpha owner')
 if releaseColorFirst then
  color:Release();check(near(texture:GetAlpha(),.37),'color release preserves the independent alpha owner')
  alpha:Release()
 else
  alpha:Release();color:Release();tint(texture,T.iconHoverTint,'releasing alpha first still permits the remaining color owner to restore current default RGB')
 end
 other:Hide()
end

do
 local other=Library:CreateContext()
 local texture=C.Icon(UIParent,20);texture:SetVertexColor(.22,.44,.66,1)
 local color=C.Style(CreateFrame('Frame',nil,UIParent),{slots={icon=texture},style={icon={color=red}},states={hover={icon={color=blue}}}})
 local alpha=other.C.Style(texture,{style={root={alpha=.37}},states={hover={root={alpha=.21}}}})
 alpha:SetState('hover',true);other.Motion:Tick(.05)
 local animatedAlpha=texture:GetAlpha()
 check(animatedAlpha<.37 and animatedAlpha>.21,'independent alpha state is in motion')
 color:SetState('hover',true)
 check(near(texture:GetAlpha(),animatedAlpha),'a color state preserves the current independently animated alpha')
 color:Release()
 rgb(texture,{.22,.44,.66},'color release restores RGB while another Context animates alpha')
 check(near(texture:GetAlpha(),.21),'color release retains the independently owned alpha state')
 alpha:Release();other:Hide()
end

do
 local icon=glyph();local host=CreateFrame('Frame',nil,UIParent)
 local style=C.Style(host,{slots={icon=icon},style={icon={color=red}}})
 local shared={.22,.44,.66,.83}
 C.OwnsStyle(host,'icon','color',shared)
 C._ObserveIconAlpha(icon.texture,T.iconIdleAlpha)
 check(shared[4]==.83,'default alpha observation does not mutate a caller-owned fallback color table')
 style:Release()
end

ctx:Hide();meta.__index=original
print('icon style ownership: '..checks..' checks passed')
