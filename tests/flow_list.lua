-- Run from LycheeUI: lua tests/flow_list.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={}
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('FlowList',private) end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b) return math.abs(a-b)<.00001 end
local ctx=LycheeUI:CreateContext({reducedMotion=true});local C=ctx.C
local parent=CreateFrame('Frame',nil,UIParent);parent:SetSize(500,500)
local function drain(list,limit)
 local flow=list.flowText;local frames=0
 while flow and flow.dirty and not flow.released do
  frames=frames+1;assert(frames<(limit or 2000),'flow rebuild did not settle')
  local before=flow.steps;local measured=flow.measurements
  local ok,message=ctx:FlushLayouts();assert(ok,message)
  check(flow.steps-before<=1,'shared scheduler runs at most one list step per flush')
  check(flow.measurements-measured<=flow.options.batchSize and flow.lastBatch<=flow.options.batchSize,'one step bounds both measurement and index cleanup work')
 end
 return frames
end
local ids,data={},{}
for i=1,1000 do ids[i]='item-'..i;data[ids[i]]=string.rep('x',i%5==0 and 100 or 12) end
local notified=0
local list=C.List(parent,180,100,20,nil,nil,{onGeometryChanged=function() notified=notified+1 end})
list:SetRowInitializer(function(row) row.custom=row.custom or row:CreateTexture(nil,'OVERLAY') end)
local physical=#list.rows;local native=#S.nodes
local resolve=function(key) return data[key] end
list:SetRowTextResolver(resolve,{batchSize=32,paddingTop=0,paddingBottom=0,minHeight=20})
list:SetItems(ids)
native=#S.nodes
local flow=list.flowText
check(flow.dirty and flow.measurements==0 and not list.geometryOffsets,'opt-in does not synchronously scan all business data')
local frames=drain(list)
check(frames>=math.ceil(#ids/32) and flow.measurements==#ids,'full data geometry is measured through bounded batches')
check(#list.rows==physical and #S.nodes==native+1,'bounded native pool: rows='..#list.rows..'/'..physical..' nodes='..#S.nodes..'/'..native)
check(notified==1 and list:GetContentHeight()>#ids*20,'complete text geometry publishes one final height notification')
check(flow.maxBatch<=32 and flow.indexWork>=#ids,'index-work counters include complete data rather than visible rows only')
check(not ctx.layoutScheduler.driver:GetScript('OnUpdate'),'shared driver sleeps when the flow queue completes')
local measured=flow.measurements;local nodes=#S.nodes
for _=1,100 do list:Refresh(true);list:GetContentHeight();ctx:FlushLayouts() end
check(flow.measurements==measured and #S.nodes==nodes and not flow.dirty,'unchanged refresh performs no text measurement or native allocation')

-- Preserve the visible business key and the pixel position inside that item.
local anchor=400;list:SetPixelOffset(list.geometryOffsets[anchor]+7,false)
check(list.rows[1].key==ids[anchor],'scroll lookup and pooled identity use the variable prefix')
local anchorKey=list.rows[1].key
list:SetWidth(125);drain(list)
local current=list.offset+1
check(list.rows[1].key==anchorKey and near(list.pixelOffset-list.geometryOffsets[current],7),'width rebuild preserves first key and within-item pixel offset')
check(list.rows[1].title:GetWidth()==125-ctx.Theme.listTextReserve,'visible title uses the same final measurement width')
local oldHeight=list:GetContentHeight();measured=flow.measurements
ctx:SetFont(nil,1.25);drain(list)
check(flow.measurements-measured==#ids and list:GetContentHeight()>oldHeight,'font version invalidates all required text geometry in bounded batches')
check(list.rows[1].key==anchorKey,'font rebuild retains visible business anchor')
list:InvalidateTextGeometry();ctx:FlushLayouts();local pausedCursor=flow.cursor
list:Hide();list:Show();check(flow.cursor==pausedCursor,'hide/show preserves already computed batch progress when metrics are unchanged');drain(list)
measured=flow.measurements;list:SetViewport(110);ctx:FlushLayouts()
check(flow.measurements==measured and not flow.dirty,'viewport height alone reuses measured text and prefix geometry')
list:SetViewport(100)
local reordered={'new-front'};data['new-front']='inserted before the existing anchor'
for i=1,#ids do reordered[i+1]=ids[i] end
list:SetItems(reordered);drain(list)
check(list.rows[1].key==anchorKey and near(list.pixelOffset-list.geometryOffsets[list.offset+1],7),'item insertion preserves the same visible key rather than the old numeric index')
local anchorIndex=list.offset+1;local oldBody=list.geometryOffsets[anchorIndex+1]-list.geometryOffsets[anchorIndex]-list.geometryGap
list:SetPixelOffset(list.geometryOffsets[anchorIndex]+oldBody-2,false);list:SetWidth(500);drain(list)
local newBody=list.geometryOffsets[list.offset+2]-list.geometryOffsets[list.offset+1]-list.geometryGap
check(list.rows[1].key==anchorKey and list.pixelOffset-list.geometryOffsets[list.offset+1]<newBody,'a shrinking anchor clamps its within-item offset before the next business key')
list:SetWidth(125);drain(list)

-- Replacement during measurement cancels the obsolete generation.
list:InvalidateTextGeometry();ctx:FlushLayouts();local oldGeneration=flow.generation
local replacement={'last-a','last-b','last-c'};data['last-a']='new';data['last-b']='new longer text';data['last-c']='new'
list:SetItems(replacement);check(flow.generation>oldGeneration,'SetItems invalidates an in-flight index generation')
ctx:FlushLayouts();list:SetItems({'last-c'});drain(list)
local staleTail=false;for index in pairs(list.geometryOffsets) do if type(index)=='number' and index>2 then staleTail=true end end
check(not staleTail and #list.geometryIndices==1,'cancelling a partial buffer trim still clears every stale numeric tail in bounded batches')
list:SetItems(replacement)
drain(list);check(#list.geometryOffsets==4 and #list.geometryIndices==3 and list.rows[1].key:find('^last%-'),'obsolete build cannot publish removed ids or stale buffer tails')

-- Hidden lists retain dirty work and resume through the same scheduler.
list:Hide();list:InvalidateTextGeometry('hidden content');local before=flow.measurements
for _=1,5 do ctx:FlushLayouts() end
check(flow.dirty and flow.measurements==before and not ctx.layoutScheduler.driver:GetScript('OnUpdate'),'hidden work pauses without a permanent update handler')
list:Show();drain(list);check(not flow.dirty and flow.measurements-before==#replacement,'show resumes the retained dirty generation')

-- Native rows retain their physical record while business identity changes.
local row=list.rows[1];local record=row._flowText;row.pressedKey=row.key;row._inside=true
list:SetItems({'last-c','last-b','last-a'});drain(list)
check(list.rows[1]==row and row._flowText==record and row.pressCancelled and not row._inside,'physical row flow record survives rebind while press and hover identity are cleared')

-- Empty lists and Clear drop data and pending work without measuring text.
list:SetItems({});drain(list)
check(list:GetContentHeight()==0 and #list.geometryIndices==0,'empty flow has zero indexed height and no visible rows')
list:SetItems(ids);ctx:FlushLayouts();list:Clear()
check(not flow.dirty and not flow.sourceIds and not flow.anchorKey and not list.geometryOffsets,'Clear cancels pending input and drops geometry references')
check(not ctx.layoutScheduler.driver:GetScript('OnUpdate'),'Clear removes pending flow work from the shared driver')

-- A resolver failure releases the attempted physical binding and retries later.
local fail=true
list:SetRowTextResolver(function(key) if fail then error('flow resolver failure') end;return data[key] end,{batchSize=16,paddingTop=0,paddingBottom=0})
flow=list.flowText
local ok=pcall(list.SetItems,list,{'last-a'})
check(not ok and not list.refreshing and list.rows[1].key==nil and not list.rows[1]:IsShown(),'failed visible binding leaves no refreshing latch or stale row identity')
fail=false;list:InvalidateTextGeometry('retry');drain(list)
check(list.rows[1].key=='last-a' and not flow.lastError,'explicit retry restores a successful visible binding')
local probe=list._flowProbe;local nativeAfter=#S.nodes
list:SetRowTextResolver(resolve,{batchSize=16,paddingTop=0,paddingBottom=0});drain(list)
check(list._flowProbe==probe and #S.nodes==nativeAfter,'resolver replacement reuses the physical measurement probe')
local failIndex=true
local lateResolver=function(key,index) if failIndex and index==50 then error('offscreen measurement failure') end;return data[key] end
list:SetRowTextResolver(lateResolver,{batchSize=16,paddingTop=0,paddingBottom=0});list:SetItems(ids)
local failed=false
for _=1,10 do local success=ctx:FlushLayouts();if not success then failed=true;break end end
check(failed and flow.dirty and flow.lastError and not ctx.layoutScheduler.driver:GetScript('OnUpdate'),'offscreen resolver failure keeps dirty state and stops the shared work task')
failIndex=false;list:InvalidateTextGeometry('offscreen retry');drain(list)
check(not flow.lastError and #list.geometryOffsets==#ids+1,'explicit retry clears the failure only after successful index submission')
local retainedResolver=flow.resolve
check(not pcall(list.SetRowTextResolver,list,resolve,{batchSize=0}) and flow.resolve==retainedResolver and not flow.dirty,'invalid batch configuration fails before replacing successful work input')
local rebound=false;local staleCalls=0
list:SetRowTextResolver(function(key,index)
 if key=='item-50' and not rebound then rebound=true;list:SetItems({'last-a','last-c'})
 elseif rebound and key=='item-51' then staleCalls=staleCalls+1 end
 return data[key]
end,{batchSize=16,paddingTop=0,paddingBottom=0})
list:SetItems(ids);drain(list)
check(rebound and staleCalls==0 and #list.geometryOffsets==3,'SetItems inside a measurement callback cancels that generation before the next old resolver call')
probe=list._flowProbe
list:SetRowTextResolver(nil)
check(not list.flowText and not list.geometryOffsets and list.rows[1]:GetHeight()==list.bodyHeight and list:GetContentHeight()==40,'disabling text flow restores physical fixed-row geometry and arithmetic indexing')
list:SetRowTextResolver(resolve,{batchSize=16,paddingTop=0,paddingBottom=0});flow=list.flowText;drain(list)
check(list._flowProbe==probe,'disabling and re-enabling flow reuses its retained native probe')

local released=flow;list:Release();check(released.released and not released.host and not released.resolve and not released.probe and not released._layoutContext,'release disconnects work input, native probe and scheduler dependencies')
check(not ctx.layoutScheduler.driver:GetScript('OnUpdate'),'released list leaves no scheduler task')
local stopping=C.List(parent,180,100,20);local stopped=false;local afterStop=0
stopping:SetRowTextResolver(function(key,index)
 if index==50 then stopped=true;stopping:Release() elseif stopped then afterStop=afterStop+1 end
 return data[key]
end,{batchSize=16,paddingTop=0,paddingBottom=0})
stopping:SetItems(ids);local stoppingFlow=stopping.flowText
for _=1,10 do if stopping.released then break end;ctx:FlushLayouts() end
check(stopping.released and stoppingFlow.released and afterStop==0 and not stoppingFlow.sourceIds,'Release inside measurement stops all later resolver calls and clears pending input')

-- The original arithmetic and data-only variable-height paths stay opt-out.
local fixed=C.List(parent,180,100,20);local beforeText=0;for _,node in ipairs(S.nodes) do if node._objectType=='FontString' then beforeText=beforeText+1 end end
fixed:SetItems(ids,function(row,key) ctx:SetText(row.title,key) end)
local afterText=0;for _,node in ipairs(S.nodes) do if node._objectType=='FontString' then afterText=afterText+1 end end
check(not fixed.flowText and not fixed.geometryOffsets and afterText==beforeText,'fixed rows allocate no text work record, index or probe')
fixed:SetRowHeightResolver(function(_,index) return index%2==0 and 30 or 20 end)
check(not fixed.flowText and fixed:GetContentHeight()==25000,'existing data height resolver keeps its complete numeric geometry path')
do
 local limited=C.List(parent,180,100,20)
 limited:SetRowTextResolver(function() return 'bounded text' end,{batchSize=128,timeBudgetMs=1})
 local entries={};for index=1,10 do entries[index]=index end;limited:SetItems(entries)
 local oldClock=debugprofilestop;local elapsed=0;debugprofilestop=function() elapsed=elapsed+1;return elapsed end
 ctx:FlushLayouts();check(limited.flowText.measurements==1 and limited.flowText.dirty,'time budget stops a batch before the larger item-count limit')
 debugprofilestop=oldClock;drain(limited)
 check(limited.flowText.measurements==10 and not ctx.layoutScheduler.driver:GetScript('OnUpdate'),'time-bounded work resumes and reaches all items')
 local active=limited.flowText.resolve
 check(not pcall(limited.SetRowTextResolver,limited,resolve,{timeBudgetMs=0}) and limited.flowText.resolve==active,'invalid time budget preserves the active configuration')
 limited:Release()
end
print('LycheeUI flow list: '..checks..' checks passed')
