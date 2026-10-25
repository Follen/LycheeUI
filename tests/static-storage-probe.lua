-- Isolated shared-runtime metadata costs. Run from LycheeUI: lua tests/static-storage-probe.lua
-- Native substitute objects are counted separately. Diagnostic GC is not a runtime policy.
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,name in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Elements','Native','Menu'}) do assert(loadfile(name..'.lua'))('StorageProbe',private) end
local UI=private.LycheeUI:CreateContext({reducedMotion=true});local C=UI.C
local parent=CreateFrame('Frame',nil,UIParent);parent:SetSize(800,600)
local function Phase(label,fn)
 collectgarbage('collect');local before=collectgarbage('count');local n=#S.nodes;collectgarbage('stop');fn();local allocated=collectgarbage('count')-before;collectgarbage('restart');collectgarbage('collect')
 print(string.format('%s allocatedKiB=%.3f retainedKiB=%.3f nativeDelta=%d',label,allocated,collectgarbage('count')-before,#S.nodes-n))
end
local labels={}
Phase('100_text_native',function() for i=1,100 do local t=parent:CreateFontString(nil,'OVERLAY');t:SetFont(UI.fontPath,14,'');t:SetShadowOffset(0,0);t:SetJustifyH('LEFT');t:SetTextColor(unpack(UI.Theme.text));t:SetText('Label');labels[#labels+1]=t end end)
Phase('100_text_C.Text',function() for i=1,100 do labels[#labels+1]=C.Text(parent,'Label',14,'text') end end)
local hosts={};for i=1,100 do hosts[i]=CreateFrame('Frame',nil,parent) end
local declarations={};for i=1,100 do declarations[i]={slots={root=hosts[i]}} end
Phase('100_empty_controllers_existing_declarations',function() for i=1,100 do C.Style(hosts[i],declarations[i]) end end)
local styled={};for i=1,100 do styled[i]=CreateFrame('Frame',nil,parent) end
local rules={hover={root={alpha=.7}}}
Phase('100_state_controllers',function() for i=1,100 do C.Style(styled[i],{slots={root=styled[i]},states=rules}) end end)
Phase('100_state_hover_roundtrip',function() for _,host in ipairs(styled) do host.styleController:SetState('hover',true);host.styleController:SetState('hover',false) end end)
local layouts={};local layoutParents,items={},{}
for i=1,100 do layoutParents[i]=CreateFrame('Frame',nil,parent);layoutParents[i]:SetSize(300,30);local a,b=CreateFrame('Frame',nil,layoutParents[i]),CreateFrame('Frame',nil,layoutParents[i]);a:SetSize(20,20);b:SetSize(30,20);items[i]={a,b} end
Phase('100_2item_layout_construction',function() for i=1,100 do layouts[i]=C.Row(layoutParents[i],items[i],{width=300,height=30,gap=4,align='center'});layouts[i]:Layout() end end)
Phase('1000_warm_layouts',function() for i=1,10 do for _,layout in ipairs(layouts) do layout:Layout() end end end)
-- Native SetFont normally writes C-side fields; remove its substitute table per call.
local function Font(self,a,b,c) local t=self.font;t[1],t[2],t[3]=a,b,c;return true end
local fontUI=private.LycheeUI:CreateContext({reducedMotion=true})
for i=1,100 do local label=fontUI.C.Text(parent,'Font label',14,'text');label.SetFont=Font end
Phase('100_plain_text_100_font_scale_updates',function() for i=1,50 do fontUI:SetFont(nil,1.3);fontUI:SetFont(nil,1) end end)
