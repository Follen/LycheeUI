-- Run from LycheeUI. Stable native setters isolate Lua lease bookkeeping.
local S=dofile('tests/stubs.lua');S.Install()
local private={};local f=assert(io.open('embeds.xml'));local xml=f:read('*a');f:close()
for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(file))('NativeCost',private) end
local ctx=private.LycheeUI:CreateContext({reducedMotion=true});local C=ctx.C
local home=CreateFrame('Frame',nil,UIParent);local controls={};local fields={};local options={}
for i=1,3 do
 local container=CreateFrame(i==3 and 'ScrollFrame' or 'EditBox',nil,home);container:SetSize(180,i==3 and 80 or 24);container:SetPoint('TOPLEFT',home,'TOPLEFT',3,-4)
 local box=i==3 and CreateFrame('EditBox',nil,container) or container;box:SetSize(150,24);box:SetFont('original',12,'');box:SetTextColor(.4,.5,.6,1);box:SetShadowOffset(1,-1)
 box.Instructions=C.Text(box,'Placeholder',12,'muted')
 for n=1,6 do local art=container:CreateTexture(nil,'ARTWORK');art:SetTexture(130871);art:SetSize(180,24) end
 fields[i]=C.Field(UIParent,320,i==3 and 96 or 44);controls[i]=box;options[i]={container=container,scripts={OnTextChanged=function() end}}
 C.NativeInput(fields[i],box,options[i]):Release()
end
-- Substitute native setters with stable storage. The real native methods do not
-- create the Lua tables used by the ordinary fixture's SetFont/SetPoint helpers.
for _,node in ipairs(S.nodes) do
 node.SetFont=function(self,a,b,c)local t=self.font;t[1],t[2],t[3]=a,b,c;return true end
 node.SetTextColor=function(self,a,b,c,d)local t=self.color or {};self.color=t;t[1],t[2],t[3],t[4]=a,b,c,d end
 node.SetShadowOffset=function(self,a,b)local t=self.shadowOffset or {};self.shadowOffset=t;t[1],t[2]=a,b end
 node.SetColorTexture=function(self,a,b,c,d)local t=self.fill or {};self.fill=t;t[1],t[2],t[3],t[4]=a,b,c,d end
 node.SetVertexColor=function(self,a,b,c,d)local t=self.vertex or {};self.vertex=t;t[1],t[2],t[3],t[4]=a,b,c,d or 1;self.alpha=d or 1 end
 local records={};for i,point in ipairs(node.points) do records[i]=point end
 node.ClearAllPoints=function(self) for i=#self.points,1,-1 do self.points[i]=nil end end
 node.SetPoint=function(self,a,b,c,x,y)
  local index=#self.points+1;for i,point in ipairs(self.points) do if point[1]==a then index=i;break end end
  local point=records[index] or {};records[index]=point;self.points[index]=point;point[1],point[2],point[3],point[4],point[5]=a,b,c,x,y
 end
 local regions,children={},{};for _,child in ipairs(node.children) do if child:GetObjectType()=='Texture' or child:GetObjectType()=='FontString' then regions[#regions+1]=child else children[#children+1]=child end end
 node.GetRegions=function() return unpack(regions) end;node.GetChildren=function() return unpack(children) end
end
for i=1,3 do C.NativeInput(fields[i],controls[i],options[i]):Release() end
local function run()
 for n=1,100 do for i=1,3 do local lease=C.NativeInput(fields[i],controls[i],options[i]);lease:RefreshStyle();lease:Release() end end
end
collectgarbage('collect');collectgarbage('stop');local before=collectgarbage('count');run();local allocated=collectgarbage('count')-before;collectgarbage('restart')
print(string.format('Native input: 100 x three acquire/refresh/release = %.3f KiB',allocated))
assert(next(ctx.nativeControls)==nil,'all benchmark leases must be released')

-- Retained ownership check uses the same warmed controls and native storage.
collectgarbage('collect');local retainedBefore=collectgarbage('count');local nodesBefore=#S.nodes
run();collectgarbage('collect')
local retained=collectgarbage('count')-retainedBefore
print(string.format('Native input warmed repeat: retainedKiB=%.3f nativeDelta=%d activeLeases=%s inputs=%d',retained,#S.nodes-nodesBefore,tostring(next(ctx.nativeControls)~=nil),#ctx.inputs))
assert(next(ctx.nativeControls)==nil and #ctx.inputs==0 and #S.nodes==nodesBefore,'released lease cycles leave neither registrations nor new native controls')
