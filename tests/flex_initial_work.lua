-- Offline work for the unchanged native probe's 16 construction/warmup scenes.
-- Diagnostic only: lua tests/flex_initial_work.lua [embedded|embedded-layout]
local S=dofile('tests/stubs.lua');S.Install()
local prefix=arg and arg[1]=='embedded' and '../LycheeGroup/addon/LycheeGroup/Libs/LycheeUI/' or ''
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do local dir=arg and arg[1]=='embedded-layout' and file=='Layouts' and '../LycheeGroup/addon/LycheeGroup/Libs/LycheeUI/' or prefix;assert(loadfile(dir..file..'.lua'))('FlexInitialWork',private) end
-- Optional second argument `heap` stops GC only in this offline Lua process.
local heap=arg and arg[2]=='heap';local initialHeap
if heap then collectgarbage('collect');collectgarbage('stop');initialHeap=collectgarbage('count') end
local function work(fn) local n=0;debug.sethook(function() n=n+1 end,'',100);fn();debug.sethook();return n*100 end
local host,driver,ui;local objects,scenes={},{}
local context=work(function() host=CreateFrame('Frame',nil,UIParent);host:SetSize(720,640);host.GetSize=function(self) return self.w,self.h end;driver=CreateFrame('Frame',nil,host);ui=LycheeUI:CreateContext({parent=host,reducedMotion=true}) end)
local nodes=work(function() for i=1,24 do local f
 if i%2==0 then f=host:CreateFontString(nil,'OVERLAY');f:SetFont('font',14,'');f:SetText('L'..i);f:SetWordWrap(false)
 else f=CreateFrame('Frame',nil,host);f.GetStringHeight=false;f.GetStringWidth=false end
 f:SetSize(20,16);f.GetSize=function(self) return self.w,self.h end;objects[i]=f
end end)
local constructors=work(function() for _,mode in ipairs({'legacy','flex'}) do for _,vertical in ipairs({false,true}) do for _,kind in ipairs({'fixed','content_text','width_change','stable_relayout'}) do
 local items={};for i,f in ipairs(objects) do local text=i%2==0;items[i]={frame=f,width=kind=='content_text' and text and 'content' or 20,height=kind=='content_text' and text and 'content' or 16};if kind=='width_change' and (vertical or i==1) then items[i].width='fill' end end
 local factory=vertical and ui.C.Column or ui.C.Row;scenes[#scenes+1]={name=mode..':'..(vertical and 'column_' or 'row_')..kind,layout=factory(host,items,{mode=mode=='flex' and 'flex' or nil,gap=3,height=640})}
end end end end)
local warmups=0
for _,scene in ipairs(scenes) do local n=work(function() scene.layout:Layout() end);warmups=warmups+n;print(scene.name..' warmupInstructions='..n) end
print('initialWork context='..context..' nativeStubs='..nodes..' constructors='..constructors..' warmups='..warmups..' total='..(context+nodes+constructors+warmups))
if heap then print(string.format('initialHeap allocatedKiB=%.4f',collectgarbage('count')-initialHeap));collectgarbage('restart') end
for _,scene in ipairs(scenes) do scene.layout:Release() end
