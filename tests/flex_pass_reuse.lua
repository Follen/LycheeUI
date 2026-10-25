-- Native observation reuse still detects external changes and setter effects.
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('FlexPassReuse',private) end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function frame(parent,w,h)
 local f=CreateFrame('Frame',nil,parent or UIParent);f:SetSize(w or 20,h or 16);f.GetStringHeight=false;f.GetStringWidth=false
 f.GetSize=function(self) return self.w,self.h end
 return f
end
for _,vertical in ipairs({false,true}) do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
 local host=frame(nil,300,100);local child=frame(host)
 local reads={};for _,key in ipairs({'IsShown','GetEffectiveScale','GetSize','GetPoint','GetNumPoints','GetWidth','GetHeight'}) do local fn=child[key];child[key]=function(self,...) reads[key]=(reads[key] or 0)+1;return fn(self,...) end end
 local l=(vertical and C.Column or C.Row)(host,{{frame=child,width=20,height=16}},{mode='flex'})
 l:Layout();for key in pairs(reads) do reads[key]=0 end;l:Layout()
 for _,key in ipairs({'IsShown','GetEffectiveScale','GetSize','GetPoint','GetNumPoints'}) do check(reads[key]==1,'fixed stable signature still reads native '..key) end
 check((reads.GetWidth or 0)==0 and (reads.GetHeight or 0)==0,'stable native size uses one paired dynamic read')
 child.w=33;child.h=27;l:Layout();check(child.w==20 and child.h==16,'external dimensions still repair on explicit fixed axes')
 child:ClearAllPoints();child:SetPoint('BOTTOMLEFT',host,'BOTTOMLEFT',0,0);l:Layout();check(child:GetPoint()=='TOPLEFT','external anchor identity still repairs')
 child:SetScale(2);l:Layout();check(child.w==10 and child.h==8,'scale changes still recompute both local dimensions')
 child:SetScale(1);child:Hide();l:Layout();check(#l.active==0 and not child._lycheeLayoutOwner,'hidden record exits the specialized signature')
 child:Show();l:Layout();check(#l.active==1 and child.w==20,'excluded records still observe show and rejoin')
 -- A width setter changes the other axis before its requested height is read.
 local width=child.SetWidth;child.SetWidth=function(self,value) width(self,value);self.h=77 end
 l:SetItems({{frame=child,width=40,height=16}});l:Layout();check(child.w==40 and child.h==16,'height observation is refreshed after a width setter side effect')
 child.SetWidth=width
 child.GetSize=function(self) reads.replaced=(reads.replaced or 0)+1;return self.w,self.h end
 l:Layout();check(reads.replaced==1,'paired capability does not cache the native method pointer')
 local injected=false;child.GetSize=function(self) if not injected then injected=true;self.h=29 end;return self.w,self.h end
 l:Layout();check(injected and child.h==16,'a replacement paired getter and its current observation are still executed')
 l:SetItems({{frame=child,width=40,height=16,manageWidth=false}});child.w=53;l:Layout()
 check(child.w==53,'unmanaged native width remains a current observation')
 child.w=59;l:Layout();check(child.w==59 and l.contentWidth==59,'unmanaged external axis changes remain visible')
 l:Release()
 -- Fallback regions without GetSize keep individual live reads.
 local fallback=frame(host);fallback.GetSize=false
 local layout=C.Row(host,{{frame=fallback,width=40,height=16}},{mode='flex'})
 local set=fallback.SetWidth;fallback.SetWidth=function(self,value) set(self,value);self.h=99 end
 layout:Layout();check(fallback.w==40 and fallback.h==16,'individual-size fallback refreshes setter effects')
 layout:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local host=frame(nil,300,100);local child=frame(host)
 local item={frame=child,width=40,height=20};local items={item};local l=C.Row(host,items,{mode='flex'});l:Layout()
 local generation=l.generation;l:SetItems(items);l:Layout();check(l.generation==generation,'unchanged sparse declarations keep the compiled inputs')
 item.ignored={value='business data'};l:SetItems(items);l:Layout();check(l.generation==generation and child.w==40,'ignored descriptor keys do not become input signatures')
 item.ignored=false;l:SetItems(items);l:Layout();check(l.generation==generation,'ignored key value changes preserve the same layout inputs')
 item.width=nil;child.w=23;l:SetItems(items);l:Layout();check(child.w==23,'removing an explicit sparse axis reads the latest native input')
 item.height=nil;child.h=17;l:SetItems(items);l:Layout();check(child.h==17,'removing the last explicit axis remains detectable')
 item.width=35;item.managePoints=false;child:ClearAllPoints();child:SetPoint('CENTER',host,'CENTER',1,2);l:SetItems(items);l:Layout()
 check(child.w==35 and child:GetPoint()=='CENTER','new sparse keys and explicit false are observed')
 item.managePoints=nil;l:SetItems(items);l:Layout();check(child:GetPoint()=='TOPLEFT','removing explicit false restores default point management')
 child:Hide();item.reserve=false;l:SetItems(items);l:Layout();check(#l.active==0,'false reserve stays a real declaration')
 item.reserve=true;l:SetItems(items);l:Layout();check(#l.active==1 and not child:IsShown(),'reserve updates preserve hidden participation')
 item.participate=false;l:SetItems(items);l:Layout();check(not l.records[child],'sparse participation false completely unregisters the item')
 item.participate=nil;child:Show();l:SetItems(items);l:Layout();check(l.records[child] and #l.active==1,'removed exclusion creates a current physical record')
 local defaults={width=55,height=21};item.width,item.height,item.reserve=nil,nil,nil;setmetatable(item,{__index=defaults})
 l:SetItems(items);l:Layout();check(child.w==55 and child.h==21,'adding descriptor inheritance leaves the sparse path')
 generation=l.generation;l:SetItems(items);l:Layout();check(l.generation==generation,'inherited fields still recognize identical inputs')
 defaults.width=65;l:SetItems(items);l:Layout();check(child.w==65,'dynamic inherited declaration edits remain live at SetItems')
 setmetatable(item,nil);child.w,child.h=26,18;l:SetItems(items);l:Layout();check(child.w==26 and child.h==18,'removing descriptor inheritance restores native omitted axes')
 l:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local host=frame(nil,100,40);local a,b=frame(host),frame(host,30,16)
 local notifications=0;local l=C.Row(host,{{frame=a,grow=1,height=16},{frame=b,grow=1,height=16}},{mode='flex',onLayout=function() notifications=notifications+1 end})
 local width=a.SetWidth;a.SetWidth=function(self,value) width(self,value);self.h=77;error('width failed after modifying both axes') end
 check(not pcall(l.Layout,l) and a.w==45 and a.h==77,'failed native setter can modify both axes before reporting failure')
 check(not l._notifyPending and notifications==0,'partial failed observations do not publish successful notification')
 a.SetWidth=width;l:Layout();check(a.w==45 and b.w==55 and a.h==16,'retry retains the intrinsic input basis and refreshes failed setter height')
 l:SetItems({{frame=a,width=40,height=16},{frame=b,width=30,height=16}})
 local entered=false;a.SetWidth=function(self,value) width(self,value);self.h=77;if not entered then entered=true;l:Layout() end end
 l:Layout();check(l.dirty and a.h==77 and notifications==1,'setter reentry leaves a later batch without committing stale height or notifying')
 a.SetWidth=width;l:Layout();check(not l.dirty and a.w==40 and a.h==16 and notifications==2,'next batch restores both requested axes after setter reentry')
 l:SetItems({{frame=a,width=60,height=16},{frame=b,width=30,height=16}})
 local successor;a.SetWidth=function(self,value) width(self,value);self.h=77;if not successor then successor=C.Row(host,{{frame=a,width=33,height=22}},{mode='flex'});successor:Layout() end end
 l:Layout();check(successor and a.w==33 and a.h==22 and a._lycheeLayoutFields.height==successor,'width setter takeover keeps the new owner height and geometry')
 a.SetWidth=width;l:Release();check(a._lycheeLayoutFields.width==successor,'old release does not clear the succeeding field owner');successor:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local host=frame(nil,300,100)
 local label=host:CreateFontString(nil,'OVERLAY');label:SetFont('font',14,'');label:SetWordWrap(true);label:SetText('text that wraps across several lines');label:SetWidth(40)
 label.GetSize=function(self) return self.w,self.h end
 local font=label.GetFont;local fonts=0;label.GetFont=function(self) fonts=fonts+1;return font(self) end
 local l=C.Row(host,{{frame=label,width=40,height='content'}},{mode='flex'});fonts=0;l:Layout()
 check(fonts==2,'immediate natural measurement reuses the just-read font signature; final wrapping read stays live')
 local height=label:GetHeight();label:SetText('x');l:Layout();check(label:GetHeight()<height,'direct text updates still invalidate the content signature')
 label:SetFont('font',20,'');l:Layout();check(label:GetHeight()==24,'direct font updates still recompute content height')
 local w,h=C.MeasureText(label);check(w>0 and h==24,'public text measurement retains its own live inputs')
 l:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C;local host=frame(nil,300,100)
 local label=host:CreateFontString(nil,'OVERLAY');label:SetFont('font',14,'');label:SetText('text')
 local original=C.MeasureText;local calls=0
 C.MeasureText=function() calls=calls+1;return 123,45 end
 local l=C.Row(host,{{frame=label,width='content',height=16}},{mode='flex'});l:Layout()
 check(calls==1 and label:GetWidth()==123,'content layout preserves current public measurement overrides')
 C.MeasureText=function(...) calls=calls+1;return original(...) end
 label:SetText('different text');l:Layout()
 check(calls==2 and label:GetWidth()~=123,'measurement wrappers receive later content changes and may call the default implementation')
 C.MeasureText=original;l:Release()
end
print('LycheeUI flex pass reuse: '..checks..' checks passed')
