-- Run from LycheeUI: lua tests/fixed_writes.lua
-- Check observable native work and appearance, including out-of-band edits.
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('FixedWrites',private) end
local Library=private.LycheeUI;local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b) return math.abs(a-b)<.000001 end
local function counts(nodes,names)
 local out={};for _,node in ipairs(nodes) do for _,name in ipairs(names) do local original=node[name];node[name]=function(self,...) out[name]=(out[name] or 0)+1;return original(self,...) end end end
 return out
end
local function total(out) local n=0;for _,v in pairs(out) do n=n+v end;return n end
local function reset(out) for k in pairs(out) do out[k]=nil end end
local ctx=Library:CreateContext({reducedMotion=true,elementDefaults={row={template=true,slotKinds={root='box',label='text',icon='texture'}}},elements={row={base={label={fontSize=18,lineHeight=24},icon={texture=134400,points={{'LEFT','$root','LEFT',12,0}}}}}}})
local C=ctx.C;local list=C.List(UIParent,200,400,40,nil,nil,{initializeRow=function(row) row.icon=C.Icon(row,16) end})
C.Element(list,'audit.list',{rowTemplate='row'});local ids={};for i=1,300 do ids[i]=i end
list:SetItems(ids,function(row,key) ctx:SetText(row.title,key) end)
local out=counts(S.nodes,{'SetFont','SetSpacing','SetHeight','SetJustifyV','SetTexture','SetTexCoord','SetPoint','ClearAllPoints'})
for i=1,120 do list:Refresh(true) end
check(total(out)==0,'unchanged list positions resubmit neither font, art nor anchors')
local row=list.rows[1];row.title:SetFont('foreign',27,'OUTLINE');row.title:SetSpacing(9);row.title:SetHeight(29);row.title:SetJustifyV('TOP');row.icon:SetTexture(7);row.icon:SetTexCoord(.2,.8,.3,.7);row.icon:ClearAllPoints();row.icon:SetPoint('RIGHT',row,'RIGHT',4,5)
list:Refresh(true)
check(row.title:GetFont()==ctx.fontPath and select(2,row.title:GetFont())==18 and row.title:GetHeight()==24 and row.title:GetJustifyV()=='MIDDLE','external native font and line-box edits are corrected')
check(row.icon:GetTexture()==134400 and select(1,row.icon:GetTexCoord())==.2 and select(1,row.icon:GetPoint())=='LEFT','native image and anchor edits are observed; unspecified crop becomes the new business baseline')
reset(out);list:Refresh(true);check(total(out)==0,'corrected appearance becomes idle immediately')
-- Readback may differ from the submitted values. Cache actual values, and still
-- read the target each time so a subsequent external edit is never masked.
local host=CreateFrame('Frame',nil,UIParent);host:SetSize(100,40)
local nativeAlpha=host.SetAlpha;function host:SetAlpha(v) nativeAlpha(self,math.floor(v*255+.5)/255) end
local controller=C.Style(host,{style={root={alpha=.3333,width=123.456}}});local normalized=counts({host},{'SetAlpha','SetWidth'})
controller:Apply(true);check(total(normalized)==0,'normalized alpha readback is stable')
host:SetAlpha(.8);host:SetWidth(44);reset(normalized);controller:Apply(true)
check(normalized.SetAlpha==1 and normalized.SetWidth==1 and near(host:GetWidth(),123.456),'external scalar edits are corrected despite unchanged requested parameters')
reset(normalized);controller:Apply(true);check(total(normalized)==0,'corrected scalar fields stop writing')
host:SetAlpha(86/255);reset(normalized);controller:Apply(true)
check(normalized.SetAlpha==1 and near(host:GetAlpha(),85/255),'an external adjacent alpha byte is corrected')
-- Constraints can change a dimension even when its own request stays fixed.
local bounded=CreateFrame('Frame',nil,UIParent);bounded:SetSize(10,40)
local limits=C.Style(bounded,{style={root={width=100,minWidth=120}},states={hover={root={minWidth=150}}}})
limits:SetState('hover',true);check(bounded:GetWidth()==150,'constraint changes reapply the dependent dimension')
limits:SetState('hover',false);check(bounded:GetWidth()==120,'leaving a constraint state restores the configured minimum')
local boundedWrites=counts({bounded},{'SetWidth'});limits:Apply(true);check(total(boundedWrites)==0,'constrained dimensions stabilize after state exit')
-- Unrelated property changes cannot restart an in-flight opacity transition.
local animated=Library:CreateContext();local moving=CreateFrame('Frame',nil,UIParent);moving:SetSize(100,40)
local fade=animated.C.Style(moving,{style={root={width=100}},states={hover={root={alpha=.2}},focus={root={width=120}}},duration=.2})
fade:SetState('hover',true);animated.Motion:Tick(.05);local alpha=moving:GetAlpha();local job=animated.Motion.jobs[moving]
fade:SetState('focus',true)
check(near(moving:GetAlpha(),alpha) and animated.Motion.jobs[moving]==job,'unrelated state changes preserve the current animation and its job')
animated.Motion:Tick(.15);check(near(moving:GetAlpha(),.2),'unchanged opacity still completes at the original time')
fade:SetState('hover',false);animated.Motion:Tick(.2);check(near(moving:GetAlpha(),1),'the animation endpoint never replaces its business baseline')
-- Atlas, texture, crop, explicit clearing and external rebinding stay atomic.
local art=C.Icon(UIParent,20);art:SetTexture(10);art:SetTexCoord(.1,.9,.2,.8)
local artStyle=C.Style(art,{states={hover={root={atlas='AuditAtlas'}},focus={root={texture=false,atlas=false}},checked={root={texture=20,texCoord={.3,.7,.4,.6}}}}})
artStyle:SetState('hover',true);check(art:GetAtlas()=='AuditAtlas','atlas state applies')
local artWrites=counts({art},{'SetTexture','SetAtlas','SetTexCoord'});artStyle:Apply(true);check(total(artWrites)==0,'stable atlas state performs no art transaction')
artStyle:SetState('hover',false);check(art:GetTexture()==10 and select(1,art:GetTexCoord())==.1,'leaving atlas restores texture plus crop')
artStyle:SetState('focus',true);check(art:GetTexture()==nil and art:GetAtlas()==nil,'explicit clearing removes both texture and atlas')
artStyle:SetState('focus',false);artStyle:SetState('checked',true);check(art:GetTexture()==20 and select(1,art:GetTexCoord())==.3,'texture plus UV state applies')
art:SetAtlas('ForeignAtlas');art:SetTexCoord(.25,.75,.25,.75);artStyle:Apply(true);check(art:GetTexture()==20,'external atlas edits are corrected while the rule remains active')
artStyle:SetState('checked',false);check(art:GetAtlas()=='ForeignAtlas' and select(1,art:GetTexCoord())==.25,'state exit restores the latest external atlas and UV baseline')
local corners=C.Icon(UIParent,20);local crop={.1,.2,.3,.4,.5,.6,.7,.8};local cornerStyle=C.Style(corners,{style={root={texCoord=crop}}})
local cropWrites=counts({corners},{'SetTexture','SetTexCoord'});cornerStyle:Apply(true)
check(total(cropWrites)==0 and select(8,corners:GetTexCoord())==.8,'eight-coordinate crops retain their native layout without rewriting')
-- A direct child rule continues to win over a parent's slot rule.
local parent=CreateFrame('Frame',nil,UIParent);local child=C.Text(parent,'child',14)
local parentStyle=C.Style(parent,{slots={label=child},style={label={fontSize=18,alpha=.6}}})
local childStyle=C.Style(child,{style={root={fontSize=24}}})
parentStyle:Apply(true);check(select(2,child:GetFont())==24 and near(child:GetAlpha(),.6),'overlapping controllers retain direct-child priority and unrelated parent properties')
childStyle:Release();check(select(2,child:GetFont())==18,'releasing the winner reapplies the remaining controller')
parentStyle:Apply(true);local childWrites=counts({child},{'SetFont','SetAlpha'});parentStyle:Apply(true);check(total(childWrites)==0,'the remaining controller becomes idle after ownership changes')
for _,part in ipairs({{spacing=9},{justifyV='TOP'}}) do
 local splitParent=CreateFrame('Frame',nil,UIParent);local splitLabel=C.Text(splitParent,'split',14)
 local splitFont=C.Style(splitParent,{slots={label=splitLabel},style={label={fontSize=18}}});local splitChild=C.Style(splitLabel,{style={root=part}})
 splitFont:Apply(true);splitChild:Apply(true)
 local splitWrites=counts({splitLabel},{'SetFont','SetSpacing','SetJustifyV'})
 for i=1,120 do splitFont:Apply(true);splitChild:Apply(true) end
 check(total(splitWrites)==0 and select(2,splitLabel:GetFont())==18 and (not part.spacing or splitLabel:GetSpacing()==part.spacing) and (not part.justifyV or splitLabel:GetJustifyV()==part.justifyV),'independent child text properties do not keep a font-only parent dirty')
end
for _,field in ipairs({{'spacing',9,11},{'justifyV','TOP','BOTTOM'},{'height',37,43}}) do
 local owner=Library:CreateContext({reducedMotion=true});local K=owner.C
 local frame=CreateFrame('Frame',nil,UIParent);local text=K.Text(frame,'derived fields',14)
 local fontRule=K.Style(frame,{slots={label=text},style={label={fontSize=18,lineHeight=24,singleLine=true}},states={hover={label={fontSize=22,lineHeight=30}}}})
 local explicit=K.Style(text,{style={root={[field[1]]=field[2]}},states={hover={root={[field[1]]=field[3]}}}})
 fontRule:Apply(true);explicit:Apply(true)
 local work=counts({text},{'SetFont','SetSpacing','SetHeight','SetJustifyV'})
 for i=1,120 do fontRule:Apply(true);explicit:Apply(true) end
 check(total(work)==0,'explicit child font derivatives remain idle across 120 parent/child applications')
 local function value() return field[1]=='spacing' and text:GetSpacing() or field[1]=='height' and text:GetHeight() or text:GetJustifyV() end
 fontRule:SetState('hover',true)
 check(select(2,text:GetFont())==22 and value()==field[2],'a parent font/line change preserves the child explicit field immediately')
 explicit:SetState('hover',true);reset(work);fontRule:Apply(true)
 check(total(work)==0 and value()==field[3],'a changed child state does not dirty unrelated parent font metrics')
 owner:SetFont(nil,1.2)
 check(near(select(2,text:GetFont()),26.4) and value()==field[3],'context font refresh also preserves explicit child derivatives')
 fontRule:SetState('hover',false);check(near(select(2,text:GetFont()),21.6) and value()==field[3],'leaving parent hover keeps the child active field')
 explicit:Release()
 local expected=field[1]=='spacing' and 24*1.2-18*1.2*1.2 or field[1]=='height' and 24*1.2 or 'MIDDLE'
 check(type(expected)=='number' and near(value(),expected) or value()==expected,'releasing the explicit child restores the current parent derivative')
 reset(work);for i=1,120 do fontRule:Apply(true) end
 check(total(work)==0,'released derivative ownership becomes idle after reapplication')
 fontRule:Release();check(near(select(2,text:GetFont()),14*1.2),'releasing the parent restores the original font baseline')
 owner:Hide()
end
do
 local frame=CreateFrame('Frame',nil,UIParent);local text=C.Text(frame,'same record',14)
 local same=C.Style(text,{style={root={fontSize=18,lineHeight=24,singleLine=true,spacing=9,height=37,justifyV='TOP'}},states={hover={root={fontSize=22,lineHeight=30}}}})
 same:SetState('hover',true)
 check(select(2,text:GetFont())==22 and text:GetSpacing()==9 and text:GetHeight()==37 and text:GetJustifyV()=='TOP','one record preserves its own unchanged explicit derivatives during a font state change')
 same:SetState('hover',false);local work=counts({text},{'SetFont','SetSpacing','SetHeight','SetJustifyV'})
 for i=1,120 do same:Apply(true) end
 check(total(work)==0 and text:GetSpacing()==9 and text:GetHeight()==37 and text:GetJustifyV()=='TOP','same-record derivative ownership is stable after state exit')
end
do
 local frame=CreateFrame('Frame',nil,UIParent);frame.label=C.Text(frame,'root font alias',14)
 local font=C.Style(frame,{style={root={fontSize=18,lineHeight=24,singleLine=true,height=40}}})
 local child=C.Style(frame.label,{style={root={spacing=9}}});font:Apply(true);child:Apply(true)
 local work=counts({frame.label},{'SetFont','SetSpacing','SetHeight'})
 for i=1,120 do font:Apply(true);child:Apply(true) end
 check(total(work)==0 and frame:GetHeight()==40 and frame.label:GetHeight()==24 and frame.label:GetSpacing()==9,'font aliases preserve the native text child without confusing its line box with the host height')
end
for _,axis in ipairs({'Width','Height'}) do for _,kind in ipairs({'min','max'}) do
 local parent=CreateFrame('Frame',nil,UIParent);local target=CreateFrame('Frame',nil,parent);target:SetSize(80,80)
 local property=axis=='Width' and 'width' or 'height';local bound=kind..axis
 local base,hover=kind=='min' and 150 or 50,kind=='min' and 180 or 40
 local limits=C.Style(parent,{slots={child=target},style={child={[bound]=base}},states={hover={child={[bound]=hover}}}})
 local fixed=C.Style(target,{style={root={[property]=100}}})
 local function value() return axis=='Width' and target:GetWidth() or target:GetHeight() end
 check(value()==base,'independent dimension rules respect the current foreign constraint')
 limits:SetState('hover',true);fixed:Apply(true);check(value()==hover,'foreign constraint states invalidate cached dimensions')
 limits:SetState('hover',false);fixed:Apply(true);check(value()==base,'leaving a foreign constraint state recomputes the target')
 -- Exercise both explicit application orders after the same state settles.
 for i=1,3 do fixed:Apply(true);limits:Apply(true);limits:Apply(true);fixed:Apply(true) end
 local work=counts({target},{'SetWidth','SetHeight'})
 for i=1,120 do fixed:Apply(true);limits:Apply(true) end
 check(total(work)==0 and value()==base,'foreign constraints stabilize with reversed application order')
 limits:Release();check(value()==100,'releasing min/max ownership immediately recomputes a fixed dimension')
 reset(work);for i=1,120 do fixed:Apply(true) end
 check(total(work)==0 and value()==100,'released foreign constraints do not leave cached clamping behind')
 fixed:Release()
end end
do
 local target=CreateFrame('Frame',nil,UIParent);target:SetSize(100,100)
 local onlyMin=C.Style(target,{style={root={minWidth=50,minHeight=60}}})
 target:SetSize(10,20);onlyMin:Apply(true)
 check(target:GetWidth()==50 and target:GetHeight()==60,'constraint-only records repair external sizes outside the active bounds')
end
do
 local owner=Library:CreateContext({reducedMotion=true});local target=owner.C.Text(UIParent,'pending geometry',14);target:SetWidth(80)
 owner.C.Box(target,{minWidth=150});local fixed=owner.C.Style(target,{style={root={width=100,fontSize=18}}})
 owner.C.Box(target,{minWidth=0});owner:SetFont(nil,1.1);fixed:Apply(true)
 check(target:GetWidth()==100,'font-only refresh cannot consume a pending dimension-constraint invalidation')
 owner:Hide()
end
local artwork=C.Icon(UIParent,20);artwork:SetTexture(10)
local artParent=CreateFrame('Frame',nil,UIParent);local parentArt=C.Style(artParent,{slots={icon=artwork},style={icon={texture=20}}})
local childArt=C.Style(artwork,{style={root={texture=30}}});parentArt:Apply(true)
check(artwork:GetTexture()==30,'a parent art observer cannot write over the direct child winner')
childArt:Release();check(artwork:GetTexture()==20,'releasing the art winner reveals the parent rule')
parentArt:Release();check(artwork:GetTexture()==10,'a losing art controller never adopts another controller as its business baseline')
-- Font readback normalization and ordinary business setters use real target
-- state rather than the requested font arguments alone.
local font=C.Text(UIParent,'fractional',14);local setFont=font.SetFont
function font:SetFont(path,size,flags) return setFont(self,path,math.floor(size*64+.5)/64,flags) end
local fractional=C.Style(font,{style={root={fontSize=18.3,lineHeight=24.2}}})
local fontWrites=counts({font},{'SetFont','SetSpacing'});fractional:Apply(true)
check(total(fontWrites)==0,'fractional font readback is stable after native normalization')
local tint=C.Text(UIParent,'tint',14);local setColor=tint.SetTextColor
function tint:SetTextColor(r,g,b,a) setColor(self,math.floor(r*255+.5)/255,math.floor(g*255+.5)/255,math.floor(b*255+.5)/255,math.floor((a or 1)*255+.5)/255) end
local tintStyle=C.Style(tint,{style={root={color={.12,.34,.56,.78}}}});local tintWrites=counts({tint},{'SetTextColor'})
tintStyle:Apply(true);check(total(tintWrites)==0,'native-normalized text color is stable')
tint:SetTextColor(32/255,.34,.56,.78);reset(tintWrites);tintStyle:Apply(true)
check(tintWrites.SetTextColor==1 and near(select(1,tint:GetTextColor()),31/255),'an external adjacent color byte is corrected')
local business=C.Text(UIParent,'business',14);local businessStyle=C.Style(business,{states={hover={root={fontSize=20}}}})
businessStyle:SetState('hover',true);C.SetFont(business,17);businessStyle:Apply(true);businessStyle:SetState('hover',false)
check(select(2,business:GetFont())==17,'font state exit restores a changed component business baseline')
-- An explicit immediate apply lands the endpoint and removes the old job.
fade:SetState('hover',true);animated.Motion:Tick(.05);fade:Apply(true)
check(near(moving:GetAlpha(),.2) and not animated.Motion.jobs[moving],'Apply(true) settles a running opacity transition')
animated.Motion:Tick(.05);check(near(moving:GetAlpha(),.2),'a settled opacity cannot resume on the next driver tick')
fade:Release();check(near(moving:GetAlpha(),1),'release after immediate settling restores the original business alpha')
local cancel=CreateFrame('Frame',nil,UIParent);local cancelStyle=animated.C.Style(cancel,{states={hover={root={alpha=.2}}},duration=.2})
cancelStyle:SetState('hover',true);animated.Motion:Tick(.05);cancelStyle:Release()
check(near(cancel:GetAlpha(),1) and not animated.Motion.jobs[cancel],'release during opacity motion cancels the job and restores its baseline')
local surface=animated.C.Panel(UIParent,'panel',8);local colorStyle=animated.C.Style(surface,{states={hover={root={color='good'}}},duration=.2})
local originalColor=surface.color;colorStyle:SetState('hover',true);animated.Motion:Tick(.05);local colorJob=animated.Motion.jobs[surface];colorStyle:Apply(false)
check(animated.Motion.jobs[surface]==colorJob,'an unchanged animated color retains its current job')
colorStyle:Apply(true);check(surface.color==animated.Theme.good and not animated.Motion.jobs[surface],'Apply(true) settles color as well as opacity')
colorStyle:Release();check(surface.color==originalColor,'release after a color transition restores its business color')
local changing=animated.C.Panel(UIParent,'panel',8);local changingColor=animated.C.Style(changing,{states={hover={root={color='good'}}},duration=.2});local changingBase=changing.color
changingColor:SetState('hover',true);animated.Motion:Tick(.05);changingColor:Release()
check(changing.color==changingBase and not animated.Motion.jobs[changing],'release during color motion cancels the job and restores its baseline')
local leaseContext=Library:CreateContext({elementDefaults={borrowed={slotKinds={root='box'}}},elements={borrowed={states={hover={root={alpha=.2}}}}}})
local borrowed=CreateFrame('Frame',nil,UIParent);local owned=true;local owner={IsOwned=function() return owned end}
leaseContext.C.Element(borrowed,'borrowed',{owner=owner});leaseContext.C.SetElementState(borrowed,'hover',true);leaseContext.Motion:Tick(.03)
owned=false;borrowed:SetAlpha(.73);leaseContext.C.ReleaseElement(borrowed);leaseContext.Motion:Tick(1)
check(near(borrowed:GetAlpha(),.73) and not leaseContext.Motion.jobs[borrowed],'a lost owner cancels its old visual job without writing the new host')
leaseContext:Hide()
ctx:Hide();animated:Hide();print('LycheeUI unchanged fixed writes: '..checks..' checks passed')

