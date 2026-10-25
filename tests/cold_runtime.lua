local S=dofile("tests/stubs.lua");S.Install()
local p={};for _,file in ipairs({"Core","Theme","Motion","Styles","Components","Layouts","Elements","Native","Menu"}) do assert(loadfile(file..".lua"))("Smoke",p) end
local ctx=LycheeUI:CreateContext({reducedMotion=true});local C=ctx.C
local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(500,400)
local text=C.Text(parent,"label","label");local button=C.Button(parent,"button",100);button:Fire("OnEnter");button:Fire("OnLeave")
C.IconButton(parent,"plus",32);C.Field(parent,100,40);C.Edit(parent,100,40);C.Check(parent,"check");C.Checkbox(parent);C.Navigation(parent,"Navigation",180)
local list=C.List(parent,200,100,40);list:SetItems({1,2,3},function(row,key) ctx:SetText(row.title,key) end)
C.Box(parent,{width=500,height=400});C.Segmented(parent,200,{{value=1,label="One"},{value=2,label="Two"}})
ctx:OpenMenu(button,{{label="Choice",value=1}});ctx:SetFont("new-font",1.3);ctx:CloseMenu();ctx:Hide()
assert(not ctx.SetTheme and not C.ApplyStyle and not ctx.GetElement and not C.Utility)
print("construction smoke passed")
