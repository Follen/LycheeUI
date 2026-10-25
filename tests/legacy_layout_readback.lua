-- Native-like float readback regression for the unchanged legacy solver.
local S=dofile('tests/stubs.lua');S.Install()
local private={}
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('LegacyReadback',private) end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function single(value)
 if value==0 then return 0 end
 local sign=value<0 and -1 or 1;local m,e=math.frexp(math.abs(value));return sign*math.ldexp(math.floor(m*16777216+.5)/16777216,e)
end
local scale=.71111112833023071
local function read(value,origin,effective) effective=effective or scale;return single((single(origin+value*effective)-single(origin))/effective) end
for _,vertical in ipairs({false,true}) do
 local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
 local host=CreateFrame('Frame',nil,UIParent);host:SetSize(300,100);host:SetScale(scale);local sizes,points=0,0
 local function frame()
  local f=CreateFrame('Frame',nil,host);f:SetSize(20,16);f.GetStringWidth=false;f.GetStringHeight=false
  local size,point,getPoint=f.SetSize,f.SetPoint,f.GetPoint
  f.GetWidth=function(self) local effective=self:GetEffectiveScale();return read(self.w,500+(self._x or 0)*effective,effective) end
  f.GetHeight=function(self) local effective=self:GetEffectiveScale();return read(self.h,700+(self._y or 0)*effective,effective) end
  f.GetSize=function(self) return self:GetWidth(),self:GetHeight() end
  f.SetSize=function(self,w,h) sizes=sizes+1;return size(self,w,h) end
  f.SetPoint=function(self,a,b,c,x,y) points=points+1;self._x,self._y=x,y;return point(self,a,b,c,x,y) end
  f.GetPoint=function(self) local a,b,c,x,y=getPoint(self);if not a then return end;local effective=self:GetEffectiveScale();return a,b,c,read(x,1000,effective),read(y,700,effective) end
  return f
 end
 local a,b=frame(),frame();local items={{frame=a,width=20,height=16},{frame=b,width=20,height=16}}
 local layout=(vertical and C.Column or C.Row)(host,items,{width=300,height=100,gap=3})
 layout:Layout();sizes,points=0,0
 local successor=(vertical and C.Column or C.Row)(host,items,{width=300,height=100,gap=3,x=7});successor:Layout()
 check(sizes==0,'new legacy controller reuses the physical region last successful size pair instead of repeating first-warmup SetSize')
 layout:Layout();check(sizes==0,'returning legacy ownership keeps the same physical size while recomputing placement');successor:Release();sizes,points=0,0
 for _=1,10 do layout:Layout() end
 check(sizes==0 and points==0,'legacy native readback is stable without repeated size or point writes: vertical='..tostring(vertical)..' size='..sizes..' point='..points)
 sizes,points=0,0;layout:SetItems(items);layout:Layout()
 check(sizes==0 and points==0,'legacy SetItems still reads inputs but skips unchanged successful native requests')
 a.w=99;sizes=0
 local external=(vertical and C.Column or C.Row)(host,items,{width=300,height=100,gap=3,x=11});external:Layout()
 check(a.w==20 and sizes>0,'a new legacy owner rejects stale inherited readback after external native size mutation')
 external:Release();layout:Layout()
 items[1].width=40;layout:Layout();check(a.w==40,'legacy mutable descriptor edits still compute and submit new sizes')
 a.w=70;layout:Layout();check(a.w==40,'legacy explicit fixed axis repairs external native size changes')
 items[1].width=nil;a.w=55;layout:Layout();check(math.abs(layout.contentWidth-(vertical and 55 or 78))<.01,'legacy omitted axis reads current external native size')
 a:ClearAllPoints();a:SetPoint('BOTTOMLEFT',host,'BOTTOMLEFT',9,4);points=0;layout:Layout()
 check(points>0 and a:GetPoint()=='TOPLEFT','legacy placement still repairs externally replaced native anchors')
 local reads=0;local fixed=C.FixedValue;C.FixedValue=function(...) reads=reads+1;return fixed(...) end
 layout:SetItems(items);layout:Layout();check(reads==0,'plain legacy full pass avoids searching a nonexistent fixed-rule registry')
 C.FixedValue=fixed;layout:Release()
 local failure=(vertical and C.Column or C.Row)(host,{{frame=a,width=40,height=16}},{width=300,height=100})
 failure:Layout();a:SetScale(1.25);failure:Layout()
 check(a.w==40 and failure.records[a].committedW==40,'legacy scale changes retain the old local-unit sizing semantics')
 sizes,points=0,0;failure:Layout();check(sizes==0 and points==0,'legacy caches settle on the new effective-scale native observations')
 local committed=failure.records[a].committedW;local native=failure.records[a].nativeReadW;local setter=a.SetSize
 a.SetSize=function(self,w,h) setter(self,w,h);error('native SetSize failed after writing') end
 failure:SetItems({{frame=a,width=60,height=16}})
 check(not pcall(failure.Layout,failure) and failure.records[a].committedW==committed and failure.records[a].nativeReadW==native,'failed legacy SetSize cannot promote a request/readback pair')
 a.SetSize=setter;failure:Layout();check(a.w==60 and failure.records[a].nativeReadW==a:GetWidth(),'legacy native size failure remains retryable')
 local edited={frame=a,width=60,height=16};failure:SetItems({edited});failure:Layout()
 edited.width=60+.000000000001
 a.SetSize=function(self,w,h) setter(self,w,h);error('in-place request fails inside the same native float bucket') end
 check(not pcall(failure.Layout,failure) and not failure.cached,'failed in-place input change invalidates the old stable cache even when native readback is unchanged')
 a.SetSize=setter;failure:Layout();check(failure.records[a].committedW==edited.width,'in-place input failure retries the new request rather than accepting the old successful native pair')
 local wantedX=failure.records[a].committedX;local point=a.SetPoint
 a.SetPoint=function(self,...) point(self,...);error('native SetPoint failed after writing') end
 failure:SetOptions({x=11})
 check(not pcall(failure.Layout,failure) and failure.records[a].committedX==wantedX,'failed legacy point write preserves the prior successful point pair')
 a.SetPoint=point;failure:Layout();check(failure.records[a].committedX==11,'legacy native point failure remains retryable')
 failure:Release()
 local label=C.Text(host,'Natural legacy label',14);label:SetSize(20,16)
 local stateHost=CreateFrame('Frame',nil,host)
 local style=C.Style(stateHost,{slots={root=stateHost,text=label},states={hover={text={width='content'}}}})
 local symbolic=(vertical and C.Column or C.Row)(host,{{frame=label,width=20,height=16}},{width=300,height=100})
 symbolic:Layout();local natural=C.MeasureTextWidth(label);style:SetState('hover',true)
 check(label:GetWidth()==natural and not symbolic.cached,'legacy symbolic state rule invalidates cached geometry and reflows synchronously')
 label:SetText('A longer natural legacy label');symbolic:Layout();check(label:GetWidth()>natural,'legacy content measurement still observes direct native text changes')
 style:SetState('hover',false);check(label:GetWidth()==20 and symbolic.cached,'leaving a symbolic rule restores ordinary fixed native geometry')
 symbolic:Release();style:Release()
 local content=C.Text(host,'A long native content label',14);content:SetSize(20,16);local widthWrites,heights=0,0
 local width,measureHeight=content.SetWidth,content.GetStringHeight
 content.GetWidth=function(self) return read(self.w,500,self:GetEffectiveScale()) end
 content.GetHeight=function(self) return read(self.h,700,self:GetEffectiveScale()) end
 content.GetSize=function(self) return self:GetWidth(),self:GetHeight() end
 content.SetWidth=function(self,value) widthWrites=widthWrites+1;return width(self,value) end
 content.GetStringHeight=function(self) heights=heights+1;return measureHeight(self) end
 local contentLayout=(vertical and C.Column or C.Row)(host,{{frame=content,width='content',height='content'}},{width=300,height=100})
 contentLayout:Layout();widthWrites,heights=0,0
 for _=1,10 do contentLayout:Layout() end
 check(widthWrites==0 and heights>=10,'legacy content keeps real height measurement while skipping unchanged quantized measurement-width writes')
 local oldNatural=C.MeasureTextWidth(content);content:SetText('A much longer native content label than the original');contentLayout:Layout()
 check(widthWrites>0 and C.MeasureTextWidth(content)>oldNatural,'legacy changed content still assigns its new measurement width')
 contentLayout:Release()
 local recycled=frame();local observed=setmetatable({},{__mode='v'});local retained
 do
  local business={key='old business identity'};local descriptor={frame=recycled,width=20,height=16,business=business}
  local oldItems={descriptor};local oldOptions={width=300,height=100,padding={left=0}}
  local old=(vertical and C.Column or C.Row)(host,oldItems,oldOptions);old:Layout()
  observed[1],observed[2],observed[3],observed[4],observed[5]=old,oldItems,descriptor,business,oldOptions
  retained=(vertical and C.Column or C.Row)(host,{{frame=recycled,width=20,height=16}},{width=300,height=100});retained:Layout();old:Release()
 end
 collectgarbage('collect')
 check(next(observed)==nil and recycled._lycheeLayoutOwner==retained,'readback reuse retains no previous controller, descriptor, options, or business identity while the physical frame survives')
 check(type(retained.records[recycled].committedW)=='number' and type(retained.records[recycled].nativeReadW)=='number','cross-owner readback state contains numeric geometry only')
 retained:Release()
end
do
 local ui=LycheeUI:CreateContext({reducedMotion=true,elementDefaults={probe={slotKinds={root='box'}}},elements={probe={
  base={root={width=20}},states={hover={root={width=40}}},variants={wide={base={root={width=60}}}},conditions={{container='dynamic-rule',minWidth=500,base={root={width=70}}}},
 }}})
 local C=ui.C;local host=CreateFrame('Frame',nil,UIParent);host:SetSize(400,100);C.Container(host,'dynamic-rule')
 local child=CreateFrame('Frame',nil,host);child:SetSize(10,16);C.Element(child,'probe')
 local layout=C.Row(host,{{frame=child,height=16}},{width=300,height=100});layout:Layout()
 child.styleController:SetVariant('wide');check(child:GetWidth()==60,'legacy registered Element variant is reread synchronously')
 C.SetElementState(child,'hover',true);check(child:GetWidth()==40,'legacy registered Element state keeps its normal priority')
 C.SetElementState(child,'hover',false);host:SetWidth(600);ui:FlushLayouts();check(child:GetWidth()==70,'legacy registered Element condition updates the computed geometry')
 host:SetWidth(400);ui:FlushLayouts();check(child:GetWidth()==60,'legacy condition exit restores the active variant')
 layout:Release();C.ReleaseElement(child);C.ReleaseContainer(host)
end
print('LycheeUI legacy native readback: '..checks..' checks passed')
