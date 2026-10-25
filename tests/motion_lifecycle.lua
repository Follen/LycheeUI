return function(S,library,check)
 local ctx=library:CreateContext()
 local M=ctx.Motion
 local key={}
 local stopped,runs=0,0
 local function cleanup()
  stopped=stopped+1
  check(not M:IsRunning(key),"completed task is detached before its cleanup")
 end
 M:Start(key,function() runs=runs+1;return runs==2 end,cleanup)
 check(M:IsRunning(key),"caller-owned keys identify active generic tasks")
 M:Tick(.01);check(stopped==0 and M:IsRunning(key),"unfinished task retains its cleanup")
 M:Tick(.01);check(stopped==1 and not M:IsRunning(key),"natural completion invokes cleanup once")
 M:Stop(key);M:StopAll();check(stopped==1,"repeated stop cannot repeat a completed cleanup")
 check(next(M.stops)==nil and not M.running and not M.driver:GetScript("OnUpdate"),"completion releases cleanup references and the idle driver")

 M:Start(key,function() return false end,cleanup)
 M:Stop(key);check(stopped==2,"explicit cancellation invokes cleanup once")
 local replaced,newStopped=0,0
 local replacement=function() return true end
 M:Start(key,function() return false end,function()
  replaced=replaced+1
  check(M.jobs[key]==replacement,"replacement is installed before the old cleanup runs")
 end)
 M:Start(key,replacement,function() newStopped=newStopped+1 end)
 check(replaced==1 and newStopped==0,"replacing a task releases only the previous run")
 M:Tick(.01);check(newStopped==1 and not M:IsRunning(key),"replacement keeps its own cleanup")

 local first,second=0,0
 M:Start(key,function() return true end,function()
  first=first+1
  M:Start(key,function() second=second+1;return true end)
 end)
 M:Tick(.01);check(first==1 and second==0 and M:IsRunning(key),"cleanup can restart its key for the next tick")
 M:Tick(.01);check(second==1 and not M:IsRunning(key),"the restarted task survives the previous completion")

 local batch,afterBatch=0,0
 M:Start("one",function() return false end,function()
  batch=batch+1
  check(not M:IsRunning("two"),"StopAll detaches all old tasks before invoking cleanup")
  M:StopAll()
  M:Start("next",function() afterBatch=afterBatch+1;return true end)
 end)
 M:Start("two",function() return false end,function() batch=batch+1 end)
 M:StopAll()
 check(batch==2 and M:IsRunning("next") and M:Count()==1,"StopAll reentry preserves the next task and invokes each old cleanup once")
 M:Tick(.01);check(afterBatch==1 and next(M.stops)==nil,"work restarted during StopAll runs normally")

 local failureCleanup=0
 M:Start("bad",function() return false end,function() failureCleanup=failureCleanup+1;error("cleanup failed") end)
 M:Start("good",function() return false end,function() failureCleanup=failureCleanup+1 end)
 local ok,message=pcall(M.StopAll,M)
 check(not ok and tostring(message):find("cleanup failed",1,true) and failureCleanup==2,"StopAll completes every cleanup before propagating an error")
 check(M:Count()==0 and next(M.stops)==nil and not M.driver:GetScript("OnUpdate"),"a cleanup error leaves no old tasks, callbacks or idle driver")

 local errors=0
 local function failCleanup() errors=errors+1;error("tick cleanup failed") end
 M:Start({},function() return true end,failCleanup)
 M:Start({},function() return true end,failCleanup)
 ok,message=pcall(M.Tick,M,.01)
 check(not ok and tostring(message):find("tick cleanup failed",1,true) and next(M.tickBuffer)==nil and not M.ticking,"a failing completion releases the whole tick snapshot before propagating")
 pcall(M.StopAll,M)
 check(errors==2 and M:Count()==0 and next(M.tickBuffer)==nil and next(M.stops)==nil,"shutdown after a tick error retains no cancelled key or job closure")
 M:Start(key,function() error("step failed") end,cleanup)
 ok,message=pcall(M.Tick,M,.01)
 check(not ok and tostring(message):find("step failed",1,true) and next(M.tickBuffer)==nil and not M.ticking,"step errors also release the reusable tick snapshot")
 M:Stop(key)

 local nestedRuns=0
 M:Start(key,function() return true end,function()
  M:Start("nested",function() nestedRuns=nestedRuns+1;return true end)
  M:Tick(.01)
 end)
 M:Tick(.01)
 check(nestedRuns==1 and M:Count()==0 and next(M.tickBuffer)==nil and not M.ticking,"an explicitly nested tick uses its own batch and leaves the reusable snapshot empty")

 local window=CreateFrame("Frame",nil,UIParent)
 window:SetPoint("CENTER",UIParent,"CENTER",0,0);ctx:SetWindow(window)
 local windowDone,customStopped=0,0
 M:SetPresence(0);M:Presence(true,function() windowDone=windowDone+1 end)
 M:Start("presence",function() return false end,function() customStopped=customStopped+1 end)
 check(M:Count()==2,"a caller key named presence coexists with the private window task")
 M:StopAll(true)
 check(customStopped==1 and not M:IsRunning("presence") and M:Count()==1,"selective stop does not mistake a caller key for the window task")
 M:Tick(1)
 check(windowDone==1 and M:Count()==0,"the retained window task still completes normally")
 M:SetPresence(0);M:Presence(true)
 M:Start("presence",function() return false end,function() customStopped=customStopped+1 end)
 M:StopPresence()
 check(M:IsRunning("presence") and M:Count()==1 and customStopped==1,"StopPresence cancels only the private window task")
 M:StopAll();check(customStopped==2,"generic cleanup is independent of window cancellation")

 local region=CreateFrame("Frame",nil,UIParent)
 region:SetSize(30,30)
 M:Busy(region,true)
 M:Start(key,function() return false end,cleanup)
 M:StopAll(true)
 check(stopped==4 and M:IsRunning(region) and not M:IsRunning(key),"selective stop clears generic tasks while retaining an explicitly persistent transition")
 ctx:Hide()
 check(M:Count()==0 and next(M.stops)==nil,"context shutdown releases all retained motion work")

 local schema=library:GetThemeSchema()
 for _,name in ipairs({"width","height","headerHeight","contentWidth","contentHeight","pageInset","mainInset","sidebarWidth","contentGap","navGap","railFontSize","logoSize","brandDuration","railRowHeight"}) do
  check(library.Theme[name]==nil and ctx.Theme[name]==nil and schema[name]==nil,"shared theme excludes product composition token "..name)
 end
 check(M.Brand==nil and M.StopBrand==nil and ctx.logo==nil and ctx.logoButton==nil,"shared contexts contain no product brand controller or regions")
end
