-- Run from LycheeUI: lua tests/motion_color.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('MotionColor',private) end
local Library=private.LycheeUI;local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b) return math.abs(a-b)<.000001 end
local meta=getmetatable(UIParent);local original=meta.__index
meta.__index=function(self,key)
 if self._objectType=='Frame' and (key=='GetVertexColor' or key=='GetTextColor') then return nil end
 if type(original)=='function' then return original(self,key) end
 return original[key]
end
local ctx=Library:CreateContext();local C,M=ctx.C,ctx.Motion
local red,blue,green={.8,.2,.1,1},{.1,.3,.9,1},{.2,.8,.3,1}
local function rgb(icon,expected,message)
 local r,g,b=(icon._lycheeTexture or icon):GetVertexColor()
 check(near(r,expected[1]) and near(g,expected[2]) and near(b,expected[3]),message)
end
local function mix(from,to,progress)
 local p=progress*(2-progress);local value={}
 for i=1,4 do value[i]=(from[i] or 1)+((to[i] or 1)-(from[i] or 1))*p end
 return value
end

do
 local glyph=C.Glyph(UIParent,'book',20)
 local style=C.Style(glyph,{duration=.1,style={root={color=red}},states={hover={root={color=blue}}}})
 style:Bind(glyph,{hover=true})
 glyph:Fire('OnEnter');M:Tick(.007)
 rgb(glyph,mix(red,blue,.07),'Glyph Style hover interpolates from its actual native color on the first frame')
 M:Tick(.093);rgb(glyph,blue,'Glyph hover reaches the declared endpoint')
 glyph:Fire('OnLeave');M:Tick(.025)
 local current={glyph.texture:GetVertexColor()}
 M:Color(glyph,green,.1)
 rgb(glyph,current,'mid-flight retargeting preserves the current visible color until the next frame')
 M:Tick(.025);rgb(glyph,mix(current,green,.25),'mid-flight retargeting interpolates from the current visible color')
 M:Tick(.075);rgb(glyph,green,'retargeted Glyph reaches its latest endpoint')
 style:Release()
end

do
 local glyph=C.Glyph(UIParent,'book',20)
 M:Color(glyph,blue,.1);M:Tick(.025)
 rgb(glyph,mix({1,1,1,1},blue,.25),'a Glyph without an explicit constructor color starts from native white')
 M:StopAll();rgb(glyph,blue,'StopAll settles a native-color Glyph transition')
 glyph.texture:SetVertexColor(unpack(red));M:Color(glyph,green,.1);M:Tick(.025)
 rgb(glyph,mix(red,green,.25),'native color changes become the next animation start without a stale Lua color cache')
 M:StopAll()
end

do
 local mark=C.CheckMark(UIParent,red)
 local style=C.Style(mark,{duration=.1,style={root={color=red}},states={hover={root={color=blue}}}})
 style:SetState('hover',true);M:Tick(.025)
 local expected=mix(red,blue,.25)
 for _,stroke in ipairs(mark.strokes) do
  check(near(stroke.fill[1],expected[1]) and near(stroke.fill[2],expected[2]) and near(stroke.fill[3],expected[3]),'shape strokes share the current interpolated material color')
 end
 M:Color(mark,green,.1);M:Tick(.025)
 expected=mix(expected,green,.25)
 check(near(mark.strokes[1].fill[1],expected[1]),'shape retargeting begins from its last applied color')
 M:StopAll();check(mark.color==green,'shape StopAll reaches the latest target')
 style:Release()
end

do
 local applied;local unknown={SetColor=function(_,color) applied=color end}
 M:Color(unknown,blue,.1)
 check(applied==blue and not M:IsRunning(unknown),'a SetColor target without a readable starting color applies its endpoint without an invalid transition')
 local panel=C.Panel(UIParent,red,8)
 M:Color(panel,blue,.1);M:Tick(.025)
 local expected=mix(red,blue,.25)
 check(near(panel.color[1],expected[1]) and near(panel.color[2],expected[2]),'ordinary Panel interpolation retains its existing behavior')
 M:StopAll()
end

ctx:Hide();meta.__index=original
print('motion color: '..checks..' checks passed')
