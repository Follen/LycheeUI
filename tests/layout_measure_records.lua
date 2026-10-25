-- Run from LycheeUI: lua tests/layout_measure_records.lua
local S=dofile('tests/stubs.lua');S.Install()
local private={}
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(file..'.lua'))('LayoutMeasureRecords',private) end
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function count(values) local n=0;for _ in pairs(values) do n=n+1 end;return n end
local function point(frame) local a,b,c,x,y=frame:GetPoint();return {a,b,c,x,y} end
local function samePoint(frame,saved) local a,b,c,x,y=frame:GetPoint();return a==saved[1] and b==saved[2] and c==saved[3] and x==saved[4] and y==saved[5] end
for _,vertical in ipairs({false,true}) do
 local ctx=LycheeUI:CreateContext({reducedMotion=true})
 local factory=vertical and ctx.C.Column or ctx.C.Row
 local name=vertical and 'Column' or 'Row'
 local parent=CreateFrame('Frame',nil,UIParent);parent:SetSize(300,100)
 -- All native objects exist before the measurement scenarios; only public Lua
 -- descriptors are replaced. The test does not infer native Frame reclamation.
 local frames={}
 for index=1,1000 do local frame=CreateFrame('Frame',nil,parent);frame:SetSize(20,10);frame:SetPoint('CENTER',parent,'CENTER',3,4);frames[index]=frame end
 local observed=setmetatable({},{__mode='v'})
 local layout=factory(parent,{}, {width='content',height='content',gap=2})
 for batch=1,20 do
  local items={}
  for index=1,50 do local key=(batch-1)*50+index;local item={frame=frames[key]};items[index]=item;observed[key]=item end
  layout:SetItems(items)
  local width,height=layout:Measure()
  check(width==(vertical and 20 or 1098) and height==(vertical and 598 or 10),name..' measures complete current geometry')
  check(count(layout.records)==50 and #layout.active==50,name..' retains only current measurement records')
  for _,item in ipairs(items) do check(item.frame._lycheeLayoutOwner==nil and samePoint(item.frame,{'CENTER',parent,'CENTER',3,4}),name..' measurement preserves original native placement') end
 end
 collectgarbage('collect');check(count(observed)==50,name..' old measurement descriptors are collectible')
 local current=layout.items[1];local record=layout.records[current.frame]
 for _=1,10 do layout:Measure();check(layout.records[current.frame]==record,name..' stable measurement reuses its record') end
 local sameFrame=current.frame;current=nil
 layout:SetItems({{frame=sameFrame,width=25,height=12}});layout:Measure();collectgarbage('collect')
 check(count(observed)==0 and count(layout.records)==1 and layout.records[sameFrame]==record,name..' replacing a descriptor for the same frame drops the previous descriptor')
 layout:SetItems({});layout:Measure();collectgarbage('collect')
 check(count(layout.records)==0 and #layout.active==0,name..' empty measurement drops all unowned records')
 layout:Release()

 local first,second=frames[1],frames[2]
 layout=factory(parent,{{frame=first,width=20,height=10}}, {width=300,height=100,x=5,y=-7})
 layout:Layout();local saved=point(first);local ownedRecord=layout.records[first]
 layout:SetItems({{frame=second,width=30,height=15}});layout:Measure()
 check(count(layout.records)==2 and layout.records[first]==ownedRecord,name..' measurement preserves a previous placement record')
 check(first._lycheeLayoutOwner==layout and samePoint(first,saved),name..' measuring replacement leaves previous ownership and anchors intact')
 layout:Layout()
 check(count(layout.records)==1 and first._lycheeLayoutOwner==nil and second._lycheeLayoutOwner==layout,name..' final layout retires old placement records and owns current items')
 layout:Release();check(second._lycheeLayoutOwner==nil,name..' final layout still releases normally')

 layout=factory(parent,{{frame=first}}, {width=300,height=100})
 layout:Layout();saved=point(first)
 layout:SetItems({{frame=second}});layout:Measure();layout:Release()
 check(first._lycheeLayoutOwner==nil and second._lycheeLayoutOwner==nil and samePoint(first,saved),name..' releasing after measurement relinquishes only actual placement without native writes')

 layout=factory(parent,{{frame=first}}, {width=300,height=100})
 layout:Layout()
 local takeover=factory(parent,{{frame=first,width=25,height=12}}, {width=300,height=100,x=17,y=-19})
 takeover:Layout();saved=point(first)
 layout:SetItems({});layout:Measure()
 check(count(layout.records)==0 and first._lycheeLayoutOwner==takeover and samePoint(first,saved),name..' measurement drops records after another layout takes ownership')
 layout:Release();check(first._lycheeLayoutOwner==takeover and samePoint(first,saved),name..' old release preserves the newer owner')
 takeover:Release()
end
print('LycheeUI layout measurement records: '..checks..' checks passed')
