-- Public recipe results remain independent while internal schema reads share
-- only the documented immutable default directory.
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Fresh()
 local S=dofile('tests/stubs.lua');S.Install();_G.LycheeUI=nil
 local private={}
 for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do
  assert(loadfile(file..'.lua'))('RecipeCatalog',private)
 end
 return LycheeUI,S
end
do
 local L,S=Fresh();local nativeBefore=#S.nodes
 local schema=L:GetStyleSchema();local field=schema['button.base.root.height']
 Check(field.default=='buttonHeight' and field.slotKind=='roundedBox','default schema keeps recipe metadata')
 Check(#S.nodes==nativeBefore,'schema builds no native controls')
 field.default=999;field.types[1]='changed'
 local second=L:GetStyleSchema()['button.base.root.height']
 Check(second.default=='buttonHeight' and second.types[1]=='number','public schema metadata is independent')
 Check(L:ValidateRecipes({button={base={root={height=37}}}}),'declared override validates')
 Check(not L:ValidateRecipes({button={base={root={height=-1}}}}),'invalid geometry remains rejected')
 Check(not L:ValidateRecipes({button={base={root={unknown=1}}}}),'unknown leaf remains rejected')
 local a,b=L:CreateContext(),L:CreateContext()
 Check(a.recipes~=b.recipes and a.recipes~=L.ComponentRecipes,'contexts keep their own resolved recipe directories')
 a.recipes.button.base.root.height=91
 Check(b.recipes.button.base.root.height=='buttonHeight' and L.ComponentRecipes.button.base.root.height=='buttonHeight','context mutation cannot alter another context or builtin catalog')
 local one,two=L.ResolveRecipes(),L.ResolveRecipes()
 one.button.base.root.height=83
 Check(two.button.base.root.height=='buttonHeight' and L.ComponentRecipes.button.base.root.height=='buttonHeight','public pure composition keeps independent results')
 local defaults={button={base={root={height=27}}},badge={slotKinds={root='box'},base={root={width=14}}}}
 local configured=L:CreateContext({recipeDefaults=defaults,recipes={button={base={root={height=33}}}}})
 Check(configured.recipes.button.base.root.height==33 and configured.recipes.badge.base.root.width==14,'product defaults and override precedence remain intact')
 Check(defaults.button.base.root.height==27,'resolution leaves product defaults intact')
 Check(L:GetStyleSchema(defaults)['button.base.root.height'].default==27,'product schema remains separate from builtin schema')
 Check(not L:ValidateRecipes({button={base={root={height=33}}}},{button={base={root={height=-1}}}}),'valid override cannot hide invalid defaults')
 Check(L:ValidateRecipes({},{}),'an explicit empty product directory remains valid')
 local invalidTheme=L.ResolveTheme({});invalidTheme.buttonHeight=-1
 Check(not L:ValidateRecipes({},nil,invalidTheme),'cached default schema still validates current resolved tokens')
 Check(not L:ValidateRecipes({},nil,{}),'cached default schema still rejects missing theme tokens')
 Check(not L:ValidateRecipes({},nil,L.ResolveTheme({fontSizeDelta=-999})),'cached default schema still validates font deltas')
 a:Hide();b:Hide();configured:Hide()
end
do
 local L=Fresh();local resolve=L.ResolveRecipes;local calls=0
 L.ResolveRecipes=function(defaults,overrides)
  calls=calls+1;local result=resolve(defaults,overrides)
  if defaults==nil then result.button.base.root.height=39 end
  return result
 end
 Check(L:GetStyleSchema()['button.base.root.height'].default==39 and calls==1,'cold schema honors a replaced public resolver')
 Check(L:ValidateRecipes({}) and calls==1,'the existing catalog still reuses a successful schema')
 local ctx=L:CreateContext()
 Check(ctx.recipes.button.base.root.height==39 and calls==2,'Context resolution keeps the public resolver call')
 Check(L.ComponentRecipes.button.base.root.height=='buttonHeight','custom resolver does not mutate builtin recipes')
 ctx:Hide()
end
print('Recipe catalog isolation: '..checks..' checks passed')
