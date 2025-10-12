local function _AC_relPath(inst, root)
    local t = {}
    local cur = inst
    while cur and cur ~= root do
        table.insert(t, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(t, "/")
end

local function _AC_indexAnimators(model)
    local idx = {}
    for _,d in ipairs(model:GetDescendants()) do
        if d:IsA("Animator") then
            local rig = d.Parent
            if rig then
                idx[_AC_relPath(rig, model)] = d
            end
        end
    end
    return idx
end

local function _AC_ensureAnimator(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        local an = hum:FindFirstChildOfClass("Animator")
        if not an then an = Instance.new("Animator", hum) end
        return an
    end
    local ac = model:FindFirstChildOfClass("AnimationController")
    if not ac then ac = Instance.new("AnimationController", model) end
    local an = ac:FindFirstChildOfClass("Animator")
    if not an then an = Instance.new("Animator", ac) end
    return an
end

local function _AC_copyTrack(srcTrack, dstAnimator)
    local srcAnim = srcTrack.Animation
    if not srcAnim then return end
    local a = Instance.new("Animation")
    a.AnimationId = srcAnim.AnimationId
    local t = dstAnimator:LoadAnimation(a)
    t.Priority = srcTrack.Priority
    t.Looped   = srcTrack.Looped
    t:Play(0, 1, srcTrack.Speed)
    pcall(function() t.TimePosition = srcTrack.TimePosition end)
    return t
end

local function _AC_findByPath(root, path)
    local node = root
    for seg in string.gmatch(path, "[^/]+") do
        node = node and node:FindFirstChild(seg) or nil
        if not node then break end
    end
    return node
end

function DexCloneAnimations(realModel, fakeModel)
    if not (realModel and fakeModel) then return end

    local rIdx = {}
    for _,d in ipairs(realModel:GetDescendants()) do
        if d:IsA("Animator") then
            local rig = d.Parent
            if rig then
                local path = _AC_relPath(rig, realModel)
                if path ~= "" then rIdx[path] = d end
            end
        end
    end

    for path, rAn in pairs(rIdx) do
        local fakeRig = _AC_findByPath(fakeModel, path)
        local fAn = nil
        if fakeRig then
            fAn = fakeRig:FindFirstChildOfClass("Animator")
            if not fAn then
                local hum = fakeRig:FindFirstChildOfClass("Humanoid")
                local ac  = fakeRig:FindFirstChildOfClass("AnimationController")
                if hum then
                    fAn = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
                elseif ac then
                    fAn = ac:FindFirstChildOfClass("Animator") or Instance.new("Animator", ac)
                else
                    local newAc = Instance.new("AnimationController", fakeRig)
                    fAn = Instance.new("Animator", newAc)
                end
            end
        else
            fAn = _AC_ensureAnimator(fakeModel)
        end

        for _,rt in ipairs(rAn:GetPlayingAnimationTracks()) do
            local srcAnim = rt.Animation
            if srcAnim then
                local a = Instance.new("Animation")
                a.AnimationId = srcAnim.AnimationId
                local t = fAn:LoadAnimation(a)
                t.Priority = rt.Priority
                t.Looped   = rt.Looped
                t:Play(0, 1, rt.Speed)
                pcall(function() t.TimePosition = rt.TimePosition end)
            end
        end
    end
end

local PREFIX_FAKE  = "[FAKE]"
local PLOTS_NAME   = "Plots"

local function _PC_getPlotsContainer()
    local ws = game:GetService("Workspace")
    if ws:FindFirstChild(PLOTS_NAME) then return ws:FindFirstChild(PLOTS_NAME) end
    local q = {ws}
    local i = 1
    while i <= #q do
        local node = q[i]; i += 1
        if node.Name == PLOTS_NAME then return node end
        for _,ch in ipairs(node:GetChildren()) do
            if ch:IsA("Folder") or ch:IsA("Model") then table.insert(q, ch) end
        end
    end
    return nil
end

local function _PC_forceArchivable(root)
    pcall(function() root.Archivable = true end)
    for _,d in ipairs(root:GetDescendants()) do
        pcall(function() d.Archivable = true end)
    end
end

local function _PC_cloneOnePlot(realPlot)
    local cont = _PC_getPlotsContainer(); if not cont then return end
    if not (realPlot and realPlot:IsA("Model")) then return end
    if realPlot.Name:sub(1, #PREFIX_FAKE) == PREFIX_FAKE then return end

    local old = cont:FindFirstChild(PREFIX_FAKE .. realPlot.Name)
    if old then pcall(function() old:Destroy() end) end

    _PC_forceArchivable(realPlot)
    local fake; pcall(function()
        fake = realPlot:Clone()
        fake.Name  = PREFIX_FAKE .. realPlot.Name
        fake.Parent = cont
    end)
    if not fake then return end

    if type(DexCloneAnimations) == "function" then
        pcall(function() DexCloneAnimations(realPlot, fake) end)
    end
end

local function _PC_cloneAllOnce()
    local cont = _PC_getPlotsContainer(); if not cont then return end
    for _,m in ipairs(cont:GetChildren()) do
        if m:IsA("Model") and m.Name:sub(1, #PREFIX_FAKE) ~= PREFIX_FAKE then
            _PC_cloneOnePlot(m)
        end
    end
end

local function _PC_attachWatcher()
    local cont = _PC_getPlotsContainer(); if not cont then return end
    cont.ChildAdded:Connect(function(ch)
        if ch and ch:IsA("Model") and ch.Name:sub(1, #PREFIX_FAKE) ~= PREFIX_FAKE then
            task.defer(function()
                _PC_cloneOnePlot(ch)
            end)
        end
    end)
end

_G.StartClonePlots = function()
    _PC_cloneAllOnce()
    _PC_attachWatcher()
end

_G.StartClonePlots()
