-- Run from LycheeUI: lua tests/list_clear.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={};for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('ListClear',private) end
local ctx=LycheeUI:CreateContext({reducedMotion=true});local list=ctx.C.List(UIParent,200,400,40)
list:SetRowHeightResolver(function(_,_,height) return height end)
local observed=setmetatable({},{__mode='v'});local ids={};for i=1,100 do ids[i]={id=i};observed[i]=ids[i] end
list:SetItems(ids,function() end);list:RefreshGeometry();ids=nil;list:Clear();collectgarbage('collect')
assert(next(observed)==nil,'Clear releases the former table business keys from geometry scratch storage')
local selected=ctx.C.List(UIParent,200,400,40);ctx.C.Element(selected,'audit.list',{rowTemplate='menu.row'});selected.elementHeights=true
local keys={{id=1},{id=2}};selected:SetItems(keys,function() end);selected:RefreshGeometry();selected:Clear()
assert(not selected._elementHeightRecord or selected._elementHeightRecord.key==nil,'Clear releases the scratch measurement record business key')
list:SetItems({1,2,3},function() end);assert(list:GetContentHeight()==120 and list.rows[1].key==1,'cleared variable lists remain reusable')
local switched=ctx.C.List(UIParent,200,400,40);switched:SetRowHeightResolver(function(_,_,height) return height end)
local old=setmetatable({},{__mode='v'});local previous={};for i=1,100 do previous[i]={id=i};old[i]=previous[i] end
switched:SetItems(previous,function() end);switched:RefreshGeometry();previous=nil
assert(next(switched.geometryRows)==nil,'geometry measurement clears its table-key scratch map before returning')
switched:SetRowHeightResolver(nil);switched:SetItems({1,2,3},function() end);collectgarbage('collect')
assert(next(old)==nil,'switching back to fixed heights releases former variable-list business keys')
ctx:Hide();print('LycheeUI list Clear: 5 checks passed')
