-- Offline Lua 5.1 comparison: lua tests/style_feedback_cost.lua [baseline git ref]
-- CPU uses os.clock; GC controls are offline only. No game calls or source edits.
local S=dofile('tests/stubs.lua')
local baseline=arg[1] or '40a900539510fe8af259a90d1e3c328093756fde'
local function Boot(ref)
 _G.LycheeUI=nil;S.Install()
 local meta=getmetatable(UIParent);local original=meta.__index
 meta.__index=function(self,key)
  if self._objectType=='Frame' and (key=='GetTextColor' or key=='GetVertexColor') then return nil end
  if type(original)=='function' then return original(self,key) end
  return original[key]
 end
 local p={}
 for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do
  if ref=='working' then assert(loadfile(file..'.lua'))('FeedbackCost',p)
  else
   local h=assert(io.popen('git show '..ref..':'..file..'.lua'));local source=h:read('*a');h:close()
   assert(loadstring(source,file..'.lua'))('FeedbackCost',p)
  end
 end
 return p.LycheeUI,meta,original
end
local function Measure(name,run,counts)
 for i=1,100 do run(i) end
 for key in pairs(counts or {}) do counts[key]=0 end
 collectgarbage('collect');collectgarbage('stop')
 local before=collectgarbage('count');local started=os.clock()
 for i=1,10000 do run(i) end
 local elapsed=(os.clock()-started)*1000;local allocated=collectgarbage('count')-before
 collectgarbage('restart')
 local extra=''
 for _,key in ipairs({'GetVertexColor','GetAlpha','IsDesaturated','SetVertexColor','SetAlpha','SetDesaturated'}) do
  if counts and counts[key] then extra=extra..' '..key..'='..counts[key] end
 end
 print(string.format('%s iterations=10000 CPU_ms=%.3f GC_stopped_KiB=%.3f%s',name,elapsed,allocated,extra))
end
local function MutableNative(image)
 -- A real native setter does not allocate the general stub's Lua vertex table.
 image.vertex={1,1,1,1}
 image.SetVertexColor=function(self,r,g,b,a)
  self.vertex[1],self.vertex[2],self.vertex[3],self.vertex[4]=r,g,b,a or 1;self.alpha=a or 1
 end
end
local function CheckColor(icon,expected,alpha)
 local image=icon._lycheeTexture or icon;local r,g,b=image:GetVertexColor()
 assert(math.abs(r-expected[1])<.000001 and math.abs(g-expected[2])<.000001 and math.abs(b-expected[3])<.000001,'RGB changed')
 assert(math.abs(image:GetAlpha()-alpha)<.000001,'alpha changed')
end
print('Lua='.._VERSION..'; baseline='..baseline..'; candidate=working; clock=os.clock; native writes normalized for Motion allocation tests')
for _,file in ipairs({'Components.lua','Styles.lua','Motion.lua'}) do
 local h=assert(io.popen('git hash-object '..file));local hash=h:read('*l');h:close();print('working_blob '..file..' '..hash)
end
for _,ref in ipairs({baseline,'working'}) do
 local library,meta,original=Boot(ref);local ctx=library:CreateContext({reducedMotion=true});local C=ctx.C
 print('SCENES '..ref..' version='..library.versionString)
 local glyph=C.Glyph(UIParent,'book',20);glyph:SetSelected(false,false)
 local counters={}
 for _,name in ipairs({'GetVertexColor','GetAlpha','IsDesaturated','SetVertexColor','SetAlpha','SetDesaturated'}) do
  local method=glyph.texture[name];counters[name]=0
  glyph.texture[name]=function(self,...) counters[name]=counters[name]+1;return method(self,...) end
 end
 Measure('unowned_feedback',function() glyph:SetSelected(false,false) end,counters)
 CheckColor(glyph,{ctx.Theme.iconIdleTint,ctx.Theme.iconIdleTint,ctx.Theme.iconIdleTint},ctx.Theme.iconIdleAlpha)
 local fixed=C.Glyph(UIParent,'book',20);local red={.17,.38,.61,1}
 local style=C.Style(fixed,{style={root={color=red}}})
 Measure('fixed_feedback_apply',function() fixed:SetSelected(false,false);style:Apply(true) end)
 CheckColor(fixed,red,ctx.Theme.iconIdleAlpha)
 style:Release();CheckColor(fixed,{ctx.Theme.iconIdleTint,ctx.Theme.iconIdleTint,ctx.Theme.iconIdleTint},ctx.Theme.iconIdleAlpha)
 local plain=C.Glyph(UIParent,'book',20);plain:SetSelected(false,false)
 local button=C.Button(UIParent,'button',100)
 for _,name in ipairs({'glyph','button'}) do
  local run=name=='glyph' and function() plain:SetSelected(false,false) end or function() button:RefreshStyle(true) end
  for i=1,100 do run() end
  local samples={}
  for sample=1,3 do
   collectgarbage('collect');local started=os.clock();for i=1,100000 do run() end
   samples[sample]=(os.clock()-started)*1000
  end
  print(name..'_CPU iterations=100000 samples_ms='..table.concat(samples,','))
 end
 for _,kind in ipairs({'reduced','no_duration'}) do
  local owner=library:CreateContext({reducedMotion=kind=='reduced'})
  local icon=owner.C.Glyph(UIParent,'book',20);MutableNative(icon.texture)
  local counts={GetVertexColor=0};local getter=icon.texture.GetVertexColor
  icon.texture.GetVertexColor=function(self) counts.GetVertexColor=counts.GetVertexColor+1;return getter(self) end
  Measure('Motion_immediate_'..kind,function() owner.Motion:Color(icon,red,kind=='reduced' and .1 or nil) end,counts)
  CheckColor(icon,red,1);assert(owner.Motion:Count()==0);owner:Hide()
 end
 local animated=library:CreateContext();local M=animated.Motion
 local icon=animated.C.Glyph(UIParent,'book',20);MutableNative(icon.texture)
 local a,b={.2,.3,.4,1},{.7,.8,.9,1}
 M:Color(icon,a,100)
 Measure('Motion_stable_frame',function() M:Tick(.000001) end)
 Measure('Motion_retarget',function(i) M:Color(icon,i%2==0 and a or b,1);M:Tick(.000001) end)
 M:StopAll();CheckColor(icon,a,1)
 assert(M:Count()==0 and next(M.tickBuffer)==nil and not M.running and not M.driver:GetScript('OnUpdate'),'motion cleanup changed')
 animated:Hide();ctx:Hide();meta.__index=original
end
print('All measured scene RGB/alpha and Motion cleanup checks passed')
