return function(library,S,check)
 local ctx=library:CreateContext({reducedMotion=true});local C=ctx.C
 -- Client 12.1.5.70575 at effective scale 0.71111112833023 returned
 -- 1.0000075101852 for both nominal one-pixel border dimensions.
 for _,case in ipairs({{.75,true},{1,true},{1.0000075101852,true},{1.0001,true},{1.0101,false},{2,false}}) do
  for _,multiline in ipairs({false,true}) do
   local home=CreateFrame('Frame',nil,UIParent)
   local container=multiline and CreateFrame('ScrollFrame',nil,home) or nil
   local box=CreateFrame('EditBox',nil,container or home);box:SetSize(180,24);box:SetText('engine text');box.secureText=true
   container=container or box;container:SetSize(180,multiline and 170 or 30)
   local border=CreateFrame('Frame',nil,container);border:SetAllPoints(container);border:SetAlpha(.7)
   for index=1,4 do
    local strip=border:CreateTexture(nil,'OVERLAY');strip:SetTexture(130871)
    strip:SetSize(index<=2 and 180 or case[1],index<=2 and case[1] or container:GetHeight()-2)
   end
   local cursor=box:CreateTexture(nil,'OVERLAY');cursor:SetSize(2,17)
   local selection=box:CreateTexture(nil,'OVERLAY');selection:SetSize(30,17)
   local button=CreateFrame('Button',nil,container);button:SetSize(16,16)
   local field=C.Field(UIParent,200,multiline and 190 or 44)
   local lease=C.NativeInput(field,box,{container=container})
   local label=(multiline and 'description' or 'title')..' thickness '..case[1]
   check(border:IsShown()==not case[2],label..': border visibility follows the thin decoration contract')
   check(border:GetAlpha()==(case[2] and 0 or .7),label..': only thin decoration opacity is borrowed')
   lease:RefreshStyle()
   check(border:IsShown()==not case[2],label..': focus/style refresh preserves the result')
   check(cursor:IsShown() and selection:IsShown() and button:IsShown(),label..': cursor, selection and functional controls are preserved')
   lease:Release()
   check(border:IsShown() and border:GetAlpha()==.7,label..': release restores original decoration')
   check(container:GetParent()==home and box:GetText()=='engine text',label..': release preserves native identity and text')
  end
 end
end
