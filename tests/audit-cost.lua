local S=dofile('tests/stubs.lua');S.Install()
local p={};for _,f in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(f..'.lua'))('Audit',p) end
local c=LycheeUI:CreateContext({reducedMotion=true});local C=c.C
collectgarbage('collect');local before=collectgarbage('count')
local buttons={};for i=1,100 do buttons[i]=C.Button(UIParent,'Button',100) end
collectgarbage('collect');local after=collectgarbage('count')
local tables,seen=0,{}
local function count(t) if type(t)~='table' or seen[t] then return end;seen[t]=true;tables=tables+1;for k,v in pairs(t) do if k~='host' and k~='slots' and k~='target' and k~='color' then count(v) end end end
count(buttons[1]._lycheeStyleController)
print('100buttons_KiB='..(after-before)..' controllerTables_first='..tables..' hasOverrides='..tostring(buttons[1]._lycheeStyleController.hasOverrides))
local n=0;for _ in pairs(buttons[1]._lycheeStyleController.records) do n=n+1 end;print('default_slot_records='..n)
