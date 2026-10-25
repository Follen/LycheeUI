-- Run from LycheeUI: lua tests/menu_font_writes.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('MenuFontWrites',private) end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b) return math.abs(a-b)<.000001 end
local entries={};for index=1,14 do entries[index]={value=index,label='A sufficiently long menu choice label '..index} end
local function Open(ctx,anchor,items,options)
 ctx:OpenMenu(anchor,items,nil,options or {kind='select'})
 return ctx:GetMenu()
end
local function Instrument(measure)
 local state={writes=0,reads=0,requests={}}
 local setFont,getWidth=measure.SetFont,measure.GetStringWidth
 function measure:SetFont(path,size,flags)
  state.writes=state.writes+1;state.requests[#state.requests+1]={path,size,flags}
  if state.failing then return state.failureResult end
  if state.normalize then path,size,flags=state.normalize(path,size,flags) end
  return setFont(self,path,size,flags)
 end
 function measure:GetStringWidth() state.reads=state.reads+1;return getWidth(self) end
 function state:Reset() self.writes,self.reads,self.requests=0,0,{} end
 return state
end
local ctx=LycheeUI:CreateContext({reducedMotion=true})
local anchor=ctx.C.ChoiceTrigger(UIParent,100,function() end)
local menu=Open(ctx,anchor,entries);local width=menu:GetWidth();ctx:CloseMenu()
local state=Instrument(menu.measure);local nativeCount=#S.nodes
for round=1,100 do
 Open(ctx,anchor,entries)
 check(menu:GetWidth()==width,'unchanged natural menu width remains identical')
 ctx:CloseMenu()
end
check(state.writes==0,'repeated ordinary opens write no unchanged measurement fonts')
check(state.reads==1400,'every label is still measured on every natural-width open')
check(#S.nodes==nativeCount and menu.anchor==nil and menu.items==nil and menu.list.ids==nil,'repeated opens reuse the pool and release menu business references')

menu.measure:SetFont('external-font',12,'OUTLINE');state:Reset()
Open(ctx,anchor,entries);ctx:CloseMenu()
check(state.writes==1 and menu:GetWidth()==width,'external measurement font edits are corrected before measuring labels')

ctx:SetFont('changed-context-font',1.3);state:Reset()
Open(ctx,anchor,entries);local scaledWidth=menu:GetWidth();ctx:CloseMenu()
check(scaledWidth>width and state.writes==0,'context font refresh uses its updated actual font without redundant measurement writes')
local path,size,flags=menu.measure:GetFont()
check(path=='changed-context-font' and near(size,ctx:GetFontSize('menuFontSize')) and flags=='','context path and scale reach the menu measurement object')

state:Reset()
for round=1,10 do Open(ctx,anchor,entries,{kind='select',width=250});check(menu:GetWidth()==250,'explicit width retains its original sizing');ctx:CloseMenu() end
check(state.writes==0 and state.reads==0,'explicit menu width bypasses label font and width measurement')

-- Instance-dependent paths, sizes and flags must change between adjacent labels.
local varied=LycheeUI:CreateContext({reducedMotion=true,elementDefaults={trigger={slotKinds={root='box'}}},elements={['menu.row']={instances={['trigger/number:2']={base={label={font='instance-font',fontSize=20,flags='OUTLINE'}}}}}}})
local variedAnchor=varied.C.ChoiceTrigger(UIParent,100,function() end);varied.C.Element(variedAnchor,'trigger')
local mixed={{value=1,label='A moderately long first label'},{value=2,label='The second label uses a different font'},{value=3,label='A moderately long third label'}}
local variedMenu=Open(varied,variedAnchor,mixed);varied:CloseMenu();local variedState=Instrument(variedMenu.measure)
Open(varied,variedAnchor,mixed)
check(variedState.writes==2 and variedState.reads==3,'adjacent instance fonts change only when the requested tuple changes')
check(variedState.requests[1][1]=='instance-font' and variedState.requests[1][2]==20 and variedState.requests[1][3]=='OUTLINE','instance font path, size and flags remain effective')
check(variedState.requests[2][1]==varied.fontPath and variedState.requests[2][2]==varied:GetFontSize('menuFontSize') and variedState.requests[2][3]=='','later ordinary labels restore their own measurement font')
local expected=100
for index,entry in ipairs(mixed) do
 local fontSize=index==2 and 20 or varied:GetFontSize('menuFontSize');local textWidth=0
 for _ in entry.label:gmatch('.') do textWidth=textWidth+.55*fontSize end
 expected=math.max(expected,math.ceil(textWidth)+varied.Theme.menuSelectInset+varied.Theme.menuTextInset+varied.Theme.menuPadding*2)
end
check(variedMenu:GetWidth()==expected,'natural width includes each label measured with its own instance font')
varied:CloseMenu();varied:SetFont('new-varied-font',1.25);variedState:Reset()
Open(varied,variedAnchor,mixed);varied:CloseMenu()
check(variedState.writes==2 and variedState.requests[1][1]=='instance-font' and variedState.requests[1][2]==25 and variedState.requests[2][1]=='new-varied-font' and variedState.requests[2][2]==20,'font scale and context path changes retain explicit instance font ownership')

-- Native setters may normalize a successful font request. Remember only the
-- latest successful request and its actual readback, not a history of tuples.
state.normalize=function(font,fontSize,fontFlags) return font:lower(),math.floor(fontSize*2+.5)/2,fontFlags end
ctx:SetFont('Normalized-Font',1.019);state:Reset()
Open(ctx,anchor,entries);ctx:CloseMenu()
check(state.writes==1,'a fractional native request is applied once before its normalized readback is retained')
local normalizedWidth=menu:GetWidth();state:Reset()
for round=1,100 do Open(ctx,anchor,entries);check(menu:GetWidth()==normalizedWidth,'native normalized font widths remain stable');ctx:CloseMenu() end
check(state.writes==0 and state.reads==1400,'successful normalized fonts are reused while all labels are still measured')

menu.measure:SetFont('foreign-normalized-font',10,'THICKOUTLINE');state:Reset()
Open(ctx,anchor,entries);ctx:CloseMenu()
check(state.writes==1 and menu:GetWidth()==normalizedWidth,'external mutation invalidates the successful normalized tuple')

-- Failed font requests stay retryable, including nil-returning failures.
state.failing=true;state.failureResult=false
ctx:SetFont('Unavailable-Font');state:Reset()
Open(ctx,anchor,entries);ctx:CloseMenu()
check(state.writes==#entries,'false-returning native failure is retried for every requested label')
state.failureResult=nil;state:Reset()
Open(ctx,anchor,entries);ctx:CloseMenu()
check(state.writes==#entries,'nil-returning native failure is not permanently memoized')
state.failing=false;state:Reset()
Open(ctx,anchor,entries);ctx:CloseMenu()
check(state.writes==1,'a previously unavailable font is acquired when native setting recovers')
state:Reset();Open(ctx,anchor,entries);ctx:CloseMenu()
check(state.writes==0,'the recovered native font can settle normally')
ctx:Hide();varied:Hide()
check(ctx.Motion:Count()==0 and varied.Motion:Count()==0,'menu lifecycle leaves no motion tasks')
print('LycheeUI menu font writes: '..checks..' checks passed')
