-- Count protected-call entries without claiming a native CPU measurement.
-- lua tests/flex_protected_calls.lua [embedded|round4|projection-baseline] [static|condition]
local S=dofile('tests/stubs.lua');S.Install()
local prefix=arg and arg[1]=='embedded' and '../LycheeGroup/addon/LycheeGroup/Libs/LycheeUI/' or arg and arg[1]=='round4' and '../LycheeGroup/.lycheedev/responsive-layout/before-memory-LycheeUI/' or arg and arg[1]=='projection-baseline' and '../LycheeGroup/.lycheedev/responsive-layout/flex-style-projection-baseline/' or ''
local private={}
for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(prefix..file..'.lua'))('ProtectedCalls',private) end
local scenario=arg and (arg[2] or arg[1])
local ui=LycheeUI:CreateContext({reducedMotion=true});local C=ui.C
local parent=CreateFrame('Frame',nil,UIParent);parent:SetSize(720,640)
if scenario=='condition' then C.Container(parent,'protected-host') end
local items={}
for i=1,24 do local f=CreateFrame('Frame',nil,parent);f:SetSize(20,16);f.GetStringWidth=false;f.GetStringHeight=false;items[i]={frame=f,width=i==1 and 'fill' or 20,height=16}
 if scenario=='static' then C.Element(f,'counted',{classes={base={root={width=20,height=16}}}})
 elseif scenario=='condition' then C.Element(f,'counted',{classes={conditions={{container='protected-host',minWidth=200,base={root={width=20,height=16}}}}}}) end
end
local row=C.Row(parent,items,{mode='flex',height=640,gap=3});row:Layout()
local calls,projections,scalarReads=0,0,0
local project,scalar=C._ReadLayoutValues,C.LayoutValue
if project then C._ReadLayoutValues=function(...) projections=projections+1;return project(...) end end
C.LayoutValue=function(...) scalarReads=scalarReads+1;return scalar(...) end
debug.sethook(function() if debug.getinfo(2,'f').func==pcall then calls=calls+1 end end,'c')
for i=1,20 do parent:SetWidth(i%2==0 and 720 or 960);row:Layout() end
debug.sethook()
print('20 changed layouts / 24 records ('..tostring(scenario or 'plain')..'): protected calls='..calls..', projections='..projections..', scalar reads='..scalarReads)
if prefix=='' then
 local styled=scenario=='static' or scenario=='condition'
 local signals=scenario=='condition' and 480 or 0
 assert(calls==(styled and 520 or 40)+signals,'one protected projection per styled item plus two catches per layout and protected condition signals')
 assert(projections==(styled and 480 or 0) and scalarReads==0,'each styled full pass replaces repeated scalar reads with one projection')
end
projections,scalarReads=0,0
for _=1,20 do row:Layout() end
assert(projections==0 and scalarReads==0,'stable layouts perform no rule projection or scalar rule lookup')
row:Release()
