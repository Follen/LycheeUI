-- Glyph stays a Frame: color reads/writes use its texture, geometry uses the
-- public Frame and its real parent. Native Frames have no texture/font getters.
return function(S,Library,check,near)
 local meta=getmetatable(CreateFrame("Frame",nil,UIParent))
 local originalIndex=meta.__index
 local frameOnly={Frame=true,Button=true,ScrollFrame=true,Slider=true}
 local regionMethods={GetVertexColor=true,SetVertexColor=true,GetTextColor=true,SetTextColor=true,GetFont=true,SetFont=true,GetTexture=true,SetTexture=true,GetAtlas=true,SetAtlas=true,GetTexCoord=true,SetTexCoord=true,GetBlendMode=true,SetBlendMode=true,GetRotation=true,SetRotation=true,GetDrawLayer=true,SetDrawLayer=true,IsDesaturated=true,SetDesaturated=true,GetStringWidth=true,GetStringHeight=true,GetUnboundedStringWidth=true}
 local function Original(self,key)
  if type(originalIndex)=="function" then return originalIndex(self,key) end
  return originalIndex[key]
 end
 meta.__index=function(self,key)
  if frameOnly[self._objectType] and regionMethods[key] then return nil end
  if self._objectType=="Texture" and (key=="GetWidth" or key=="GetHeight") then
   local native=Original(self,key)
   return function(region)
    -- A texture with SetAllPoints keeps the parent's computed dimensions;
    -- SetSize alone does not cancel those native anchor constraints.
    local anchor=region.allPoints
    if anchor then return anchor[key](anchor) end
    return native(region)
   end
  end
  return Original(self,key)
 end
 local ok,err=pcall(function()
  local ctx=Library:CreateContext({reducedMotion=true,elementDefaults={
   glyph={slotKinds={root="texture"}},
   host={slotKinds={root="box",icon="texture"}},
  },elements={
   glyph={base={root={width=19,height=15,color="good",points={{"CENTER","$parent","CENTER",3,-2}}}},states={hover={root={color="brand"}}}},
   host={base={icon={width=19,height=15,color="good",points={{"CENTER","$parent","CENTER",3,-2}}}},states={hover={icon={color="brand"}}}},
  }})
  local C,T=ctx.C,ctx.Theme
  local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(160,60)
  local function Color(glyph,expected,label)
   local r,g,b,a=glyph.texture:GetVertexColor()
   check(near(r,expected[1]) and near(g,expected[2]) and near(b,expected[3]) and near(a,expected[4] or 1),label)
  end
  local function Geometry(glyph,label,expectedParent)
   expectedParent=expectedParent or parent
   local point,relative,relativePoint,x,y=glyph:GetPoint()
   check(glyph:GetObjectType()=="Frame" and glyph:GetParent()==expectedParent,label..": public Glyph identity and parent remain a Frame")
   check(near(glyph:GetWidth(),19) and near(glyph:GetHeight(),15),label..": geometry resizes the public Frame")
   check(point=="CENTER" and relative==expectedParent and relativePoint=="CENTER" and x==3 and y==-2,label..": $parent resolves to the Frame's external parent")
   check(glyph.texture:GetParent()==glyph and glyph.texture.allPoints==glyph and near(glyph.texture:GetWidth(),19) and near(glyph.texture:GetHeight(),15),label..": texture remains constrained to fill the Frame")
   check(glyph.GetTextColor==nil and glyph.GetVertexColor==nil,label..": no invented native Frame color getter hides a regression")
  end
  local constrained=C.Glyph(parent,"book",16)
  constrained.texture:SetSize(19,15)
  check(constrained.texture:GetWidth()==16 and constrained.texture:GetHeight()==16,"strict texture anchors reject replacing public Glyph geometry with raw texture SetSize")
  local native={.12,.23,.34,1}
  local glyph=C.Glyph(parent,"book",16,native)
  local style=C.Style(glyph,{style={root={width=19,height=15,color="good",points={{"CENTER","$parent","CENTER",3,-2}}}},states={hover={root={color="brand"}}}})
  style:Bind(glyph,{hover=true})
  Geometry(glyph,"Style resting");Color(glyph,T.good,"Style reads the native texture and writes through Glyph:SetColor")
  glyph:Fire("OnEnter");Geometry(glyph,"Style hover");Color(glyph,T.brand,"Style hover recolors the existing texture")
  glyph:Fire("OnLeave");Geometry(glyph,"Style leave");Color(glyph,T.good,"Style leave restores the declared resting color")
  style:Release();Color(glyph,native,"Style release restores the original native texture color")
  check(glyph:GetWidth()==16 and glyph:GetHeight()==16,"Style release restores the public Frame's original dimensions")

  local element=C.Glyph(parent,"book",16,native)
  C.Element(element,"glyph")
  Geometry(element,"Element resting");Color(element,T.good,"Element color works on a public Glyph Frame")
  C.SetElementState(element,"hover",true);Geometry(element,"Element hover");Color(element,T.brand,"Element hover retains the Frame slot")
  C.SetElementState(element,"hover",false);Color(element,T.good,"Element hover exit restores its resting color")
  C.ReleaseElement(element);Color(element,native,"Element release restores the original native texture color")
  check(element:GetWidth()==16 and element:GetHeight()==16,"Element release restores the Frame geometry")

  local host=CreateFrame("Frame",nil,parent);host:SetSize(32,32)
  local icon=C.Glyph(host,"book",16,native)
  host.icon=icon;C.Element(host,"host",{slots={root=host,icon=icon}})
  Geometry(icon,"Nested element resting",host);Color(icon,T.good,"nested texture slot accepts a Glyph Frame without product adapters")
  C.SetElementState(host,"hover",true);Geometry(icon,"Nested element hover",host);Color(icon,T.brand,"nested hover follows the declared Glyph Frame slot")
  C.SetElementState(host,"hover",false);Color(icon,T.good,"nested hover exit restores resting color")
  C.ReleaseElement(host);Color(icon,native,"nested release restores native color")
 end)
 meta.__index=originalIndex
 if not ok then error(err,0) end
end
