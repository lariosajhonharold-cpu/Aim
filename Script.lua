-- SELF-CONTAINED ALTERNATIVE — no hosting needed
-- wrap the entire script in a pcall for clean error handling

local ok, err = pcall(function()

-- ╔══════════════════════════════════════════╗
-- ║  PASTE THE FULL SCRIPT HERE — START      ║
-- ╚══════════════════════════════════════════╝

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Camera            = workspace.CurrentCamera

local lp     = Players.LocalPlayer
local lpChar = lp.Character or lp.CharacterAdded:Wait()

local CFG = {
    AimAssist    = true,
    ESP          = true,
    AimFOV       = 140,
    AimSmooth    = 0.22,
    AimBone      = "Head",
    PanelImage   = "rbxassetid://10824339341",
    ESP_BoxColor = Color3.fromRGB(180, 80, 255),
    ESP_NameColor= Color3.fromRGB(220, 160, 255),
}

local function isEnemy(char)
    if not char then return false end
    local p = Players:GetPlayerFromCharacter(char)
    if not p or p == lp then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function getBone(char)
    return char:FindFirstChild(CFG.AimBone)
        or char:FindFirstChild("HumanoidRootPart")
end

local function W2S(pos)
    local s, vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), vis
end

local function vCenter()
    local v = Camera.ViewportSize
    return Vector2.new(v.X * 0.5, v.Y * 0.5)
end

local espRoot = Instance.new("Folder")
espRoot.Name   = "_esp"
espRoot.Parent = game:GetService("CoreGui")
local espMap = {}

local function buildESP(player)
    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 72, 0, 100)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Enabled     = false

    local box = Instance.new("Frame", bb)
    box.Size = UDim2.new(1,0,1,0)
    box.BackgroundColor3 = CFG.ESP_BoxColor
    box.BackgroundTransparency = 0.55
    box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,5)
    local bs = Instance.new("UIStroke", box)
    bs.Color = CFG.ESP_BoxColor; bs.Thickness = 1.6

    local nl = Instance.new("TextLabel", bb)
    nl.Size  = UDim2.new(1,0,0,18)
    nl.Position = UDim2.new(0,0,-0.22,0)
    nl.BackgroundTransparency = 1
    nl.Text  = player.Name
    nl.TextColor3 = CFG.ESP_NameColor
    nl.Font  = Enum.Font.GothamBold
    nl.TextSize = 12
    nl.TextStrokeTransparency = 0.3

    local hbg = Instance.new("Frame", bb)
    hbg.Size = UDim2.new(0,5,1,0)
    hbg.Position = UDim2.new(-0.13,0,0,0)
    hbg.BackgroundColor3 = Color3.fromRGB(25,0,45)
    hbg.BackgroundTransparency = 0.2
    hbg.BorderSizePixel = 0
    Instance.new("UICorner", hbg).CornerRadius = UDim.new(0,3)

    local hf = Instance.new("Frame", hbg)
    hf.Size = UDim2.new(1,0,1,0)
    hf.AnchorPoint = Vector2.new(0,1)
    hf.Position = UDim2.new(0,0,1,0)
    hf.BackgroundColor3 = Color3.fromRGB(160,50,255)
    hf.BorderSizePixel = 0
    Instance.new("UICorner", hf).CornerRadius = UDim.new(0,3)

    espMap[player] = { gui = bb, fill = hf }

    local function attachChar(char)
        task.wait(0.4)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then bb.Adornee = hrp end
    end
    player.CharacterAdded:Connect(attachChar)
    if player.Character then attachChar(player.Character) end
    bb.Parent = espRoot
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= lp then buildESP(p) end
end
Players.PlayerAdded:Connect(function(p) buildESP(p) end)
Players.PlayerRemoving:Connect(function(p)
    if espMap[p] then espMap[p].gui:Destroy(); espMap[p] = nil end
end)

local fovSG = Instance.new("ScreenGui")
fovSG.Name = "_fov"; fovSG.ResetOnSpawn = false
fovSG.Parent = game:GetService("CoreGui")

local ring = Instance.new("Frame", fovSG)
ring.BackgroundTransparency = 1
ring.BorderSizePixel = 0
local rs = Instance.new("UIStroke", ring)
rs.Color = Color3.fromRGB(170,60,255); rs.Thickness = 1.2
Instance.new("UICorner", ring).CornerRadius = UDim.new(1,0)

local aimHeld    = false
local aimZoneSG  = Instance.new("ScreenGui")
aimZoneSG.Name   = "_aimzone"; aimZoneSG.ResetOnSpawn = false
aimZoneSG.Parent = game:GetService("CoreGui")

local aimZone = Instance.new("TextButton", aimZoneSG)
aimZone.Size = UDim2.new(0.4, 0, 0.6, 0)
aimZone.Position = UDim2.new(0.6, 0, 0.2, 0)
aimZone.BackgroundTransparency = 1
aimZone.Text = ""
aimZone.ZIndex = 1
aimZone.TouchStarted:Connect(function() aimHeld = true end)
aimZone.TouchEnded:Connect(function() aimHeld = false end)

RunService.RenderStepped:Connect(function()
    lpChar = lp.Character
    local cv  = Camera.ViewportSize
    local ctr = vCenter()
    local r   = CFG.AimFOV

    ring.Size     = UDim2.new(0, r*2, 0, r*2)
    ring.Position = UDim2.new(0, ctr.X - r, 0, ctr.Y - r)

    local closest = CFG.AimFOV
    local target  = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p == lp then continue end
        local char = p.Character
        if not isEnemy(char) then continue end
        local bone = getBone(char)
        if not bone then continue end
        local s2d, vis = W2S(bone.Position)
        if not vis then continue end
        local d = (s2d - ctr).Magnitude
        if d < closest then closest = d; target = bone end

        if CFG.ESP and espMap[p] then
            espMap[p].gui.Enabled = true
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local pct = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
                espMap[p].fill.Size = UDim2.new(1, 0, pct, 0)
            end
        elseif espMap[p] then
            espMap[p].gui.Enabled = false
        end
    end

    if CFG.AimAssist and aimHeld and target then
        local s2d, vis = W2S(target.Position)
        if vis then
            local delta  = s2d - ctr
            local move   = delta * CFG.AimSmooth
            local dist   = (Camera.CFrame.Position - target.Position).Magnitude
            local unitsPerPx = (2 * math.tan(
                math.rad(Camera.FieldOfView * 0.5)) * dist) / cv.Y
            local offset = Vector3.new(
                -move.X * unitsPerPx, move.Y * unitsPerPx, 0)
            Camera.CFrame = Camera.CFrame * CFrame.new(offset)
        end
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "ollie_ui"; sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = game:GetService("CoreGui")

local toggleBtn = Instance.new("TextButton", sg)
toggleBtn.Size             = UDim2.new(0, 52, 0, 52)
toggleBtn.Position         = UDim2.new(0, 14, 0, 48)
toggleBtn.BackgroundColor3 = Color3.fromRGB(90, 0, 170)
toggleBtn.Text             = "⚡"
toggleBtn.TextSize         = 22
toggleBtn.TextColor3       = Color3.fromRGB(230, 180, 255)
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.BorderSizePixel  = 0
toggleBtn.ZIndex           = 20
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
local ts2 = Instance.new("UIStroke", toggleBtn)
ts2.Color = Color3.fromRGB(180, 80, 255); ts2.Thickness = 1.5

local cv0    = Camera.ViewportSize
local panelW = math.min(cv0.X - 28, 310)
local panelH = 420

local win = Instance.new("Frame", sg)
win.Name             = "Panel"
win.Size             = UDim2.new(0, panelW, 0, panelH)
win.Position         = UDim2.new(0, 14, 0, 110)
win.BackgroundColor3 = Color3.fromRGB(10, 0, 22)
win.BackgroundTransparency = 0.06
win.BorderSizePixel  = 0
win.Visible          = false
win.ZIndex           = 10
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 16)
local ws = Instance.new("UIStroke", win)
ws.Color = Color3.fromRGB(140, 40, 220); ws.Thickness = 1.8

local bgImg = Instance.new("ImageLabel", win)
bgImg.Size               = UDim2.new(1,0,1,0)
bgImg.Image              = CFG.PanelImage
bgImg.ImageTransparency  = 0.45
bgImg.BackgroundTransparency = 1
bgImg.ScaleType          = Enum.ScaleType.Crop
bgImg.ZIndex             = 11
Instance.new("UICorner", bgImg).CornerRadius = UDim.new(0, 16)

local veil = Instance.new("Frame", win)
veil.Size = UDim2.new(1,0,1,0)
veil.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
veil.BackgroundTransparency = 0.35
veil.BorderSizePixel = 0
veil.ZIndex = 12
Instance.new("UICorner", veil).CornerRadius = UDim.new(0, 16)
local vg = Instance.new("UIGradient", veil)
vg.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(100, 0, 180)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(15,  0,  35)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(60,  0, 110)),
}
vg.Rotation = 140
vg.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0.55),
    NumberSequenceKeypoint.new(1, 0.2),
}

local hdr = Instance.new("Frame", win)
hdr.Size = UDim2.new(1,0,0,50)
hdr.BackgroundColor3 = Color3.fromRGB(80, 0, 155)
hdr.BackgroundTransparency = 0.25
hdr.BorderSizePixel = 0
hdr.ZIndex = 13
Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 16)

local hdrLbl = Instance.new("TextLabel", hdr)
hdrLbl.Text = "⚡ ollie mod"
hdrLbl.Size = UDim2.new(1,-16,1,0)
hdrLbl.Position = UDim2.new(0,14,0,0)
hdrLbl.BackgroundTransparency = 1
hdrLbl.TextColor3 = Color3.fromRGB(225, 165, 255)
hdrLbl.Font = Enum.Font.GothamBold
hdrLbl.TextSize = 17
hdrLbl.TextXAlignment = Enum.TextXAlignment.Left
hdrLbl.ZIndex = 14

local sub = Instance.new("TextLabel", win)
sub.Text = "absolute ollie  •  built by olivia"
sub.Size = UDim2.new(1,-20,0,14)
sub.Position = UDim2.new(0,12,0,55)
sub.BackgroundTransparency = 1
sub.TextColor3 = Color3.fromRGB(130, 70, 195)
sub.Font = Enum.Font.Gotham
sub.TextSize = 11
sub.ZIndex = 13

do
    local dragging = false
    local dragStart, startPos
    win.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = i.Position
            startPos  = win.Position
        end
    end)
    win.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.Touch then
            local delta = i.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale,
                math.clamp(startPos.X.Offset + delta.X, 0, cv0.X - panelW),
                startPos.Y.Scale,
                math.clamp(startPos.Y.Offset + delta.Y, 50, cv0.Y - panelH)
            )
        end
    end)
    win.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local panelOpen = false
toggleBtn.Activated:Connect(function()
    panelOpen = not panelOpen
    win.Visible = panelOpen
    TweenService:Create(toggleBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = panelOpen
            and Color3.fromRGB(140, 0, 230)
            or  Color3.fromRGB(90,  0, 170)
    }):Play()
end)

local rowY = 76
local function makeRow(label, key)
    local row = Instance.new("Frame", win)
    row.Size = UDim2.new(1,-24,0,54)
    row.Position = UDim2.new(0,12,0,rowY)
    row.BackgroundColor3 = Color3.fromRGB(30, 0, 58)
    row.BackgroundTransparency = 0.18
    row.BorderSizePixel = 0
    row.ZIndex = 13
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)
    local rs2 = Instance.new("UIStroke", row)
    rs2.Color = Color3.fromRGB(110, 35, 190); rs2.Thickness = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Text = label
    lbl.Size = UDim2.new(0.68,0,1,0)
    lbl.Position = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(210, 145, 255)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 15
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 14

    local pill = Instance.new("Frame", row)
    pill.Size = UDim2.new(0,52,0,28)
    pill.Position = UDim2.new(1,-62,0.5,-14)
    pill.BorderSizePixel = 0
    pill.ZIndex = 14
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame", pill)
    knob.Size = UDim2.new(0,22,0,22)
    knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.BorderSizePixel = 0
    knob.ZIndex = 15
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local function refresh()
        local on = CFG[key]
        TweenService:Create(pill, TweenInfo.new(0.16), {
            BackgroundColor3 = on
                and Color3.fromRGB(155, 55, 255)
                or  Color3.fromRGB(45,   0,  75)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.16), {
            Position = UDim2.new(on and 0.74 or 0.26, 0, 0.5, 0),
            BackgroundColor3 = on
                and Color3.fromRGB(235, 185, 255)
                or  Color3.fromRGB(110,  55, 155)
        }):Play()
    end
    refresh()

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""; btn.ZIndex = 16
    btn.Activated:Connect(function()
        CFG[key] = not CFG[key]; refresh()
        TweenService:Create(row, TweenInfo.new(0.08), {
            BackgroundColor3 = Color3.fromRGB(65, 0, 115)
        }):Play()
        task.delay(0.14, function()
            TweenService:Create(row, TweenInfo.new(0.12), {
                BackgroundColor3 = Color3.fromRGB(30, 0, 58)
            }):Play()
        end)
    end)
    rowY = rowY + 62
end

makeRow("🎯  Aim Assist", "AimAssist")
makeRow("👁️  Enemy ESP",  "ESP")

local fovLbl = Instance.new("TextLabel", win)
fovLbl.Text = "Aim FOV  •  " .. CFG.AimFOV
fovLbl.Size = UDim2.new(1,-24,0,16)
fovLbl.Position = UDim2.new(0,14,0,rowY + 6)
fovLbl.BackgroundTransparency = 1
fovLbl.TextColor3 = Color3.fromRGB(170,100,235)
fovLbl.Font = Enum.Font.GothamSemibold
fovLbl.TextSize = 13
fovLbl.TextXAlignment = Enum.TextXAlignment.Left
fovLbl.ZIndex = 13

local track = Instance.new("Frame", win)
track.Size = UDim2.new(1,-28,0,10)
track.Position = UDim2.new(0,14,0,rowY + 28)
track.BackgroundColor3 = Color3.fromRGB(40, 0, 78)
track.BorderSizePixel = 0; track.ZIndex = 13
Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)

local tfill = Instance.new("Frame", track)
tfill.Size = UDim2.new(CFG.AimFOV/300,0,1,0)
tfill.BackgroundColor3 = Color3.fromRGB(150,50,255)
tfill.BorderSizePixel = 0; tfill.ZIndex = 14
Instance.new("UICorner", tfill).CornerRadius = UDim.new(1,0)

local thandle = Instance.new("TextButton", track)
thandle.Size = UDim2.new(0,32,0,32)
thandle.AnchorPoint = Vector2.new(0.5,0.5)
thandle.Position = UDim2.new(CFG.AimFOV/300,0,0.5,0)
thandle.BackgroundColor3 = Color3.fromRGB(190,90,255)
thandle.Text = ""; thandle.BorderSizePixel = 0; thandle.ZIndex = 15
Instance.new("UICorner", thandle).CornerRadius = UDim.new(1,0)
local ths = Instance.new("UIStroke", thandle)
ths.Color = Color3.fromRGB(230,170,255); ths.Thickness = 1.5

local slideDragging = false
thandle.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then slideDragging = true end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then slideDragging = false end
end)
UserInputService.TouchMoved:Connect(function(touch)
    if not slideDragging then return end
    local abs = track.AbsolutePosition
    local sz  = track.AbsoluteSize
    local pct = math.clamp((touch.Position.X - abs.X) / sz.X, 0, 1)
    CFG.AimFOV = math.floor(pct * 300)
    tfill.Size = UDim2.new(pct, 0, 1, 0)
    thandle.Position = UDim2.new(pct, 0, 0.5, 0)
    fovLbl.Text = "Aim FOV  •  " .. CFG.AimFOV
    ring.Size = UDim2.new(0, CFG.AimFOV*2, 0, CFG.AimFOV*2)
end)

local rowYs = rowY + 72
local sLbl = Instance.new("TextLabel", win)
sLbl.Text = "Aim Smooth  •  " .. string.format("%.2f", CFG.AimSmooth)
sLbl.Size = UDim2.new(1,-24,0,16)
sLbl.Position = UDim2.new(0,14,0,rowYs)
sLbl.BackgroundTransparency = 1
sLbl.TextColor3 = Color3.fromRGB(170,100,235)
sLbl.Font = Enum.Font.GothamSemibold
sLbl.TextSize = 13
sLbl.TextXAlignment = Enum.TextXAlignment.Left
sLbl.ZIndex = 13

local sTrack = Instance.new("Frame", win)
sTrack.Size = UDim2.new(1,-28,0,10)
sTrack.Position = UDim2.new(0,14,0,rowYs + 22)
sTrack.BackgroundColor3 = Color3.fromRGB(40,0,78)
sTrack.BorderSizePixel = 0; sTrack.ZIndex = 13
Instance.new("UICorner", sTrack).CornerRadius = UDim.new(1,0)

local sFill = Instance.new("Frame", sTrack)
sFill.Size = UDim2.new(CFG.AimSmooth,0,1,0)
sFill.BackgroundColor3 = Color3.fromRGB(150,50,255)
sFill.BorderSizePixel = 0; sFill.ZIndex = 14
Instance.new("UICorner", sFill).CornerRadius = UDim.new(1,0)

local sHandle = Instance.new("TextButton", sTrack)
sHandle.Size = UDim2.new(0,32,0,32)
sHandle.AnchorPoint = Vector2.new(0.5,0.5)
sHandle.Position = UDim2.new(CFG.AimSmooth,0,0.5,0)
sHandle.BackgroundColor3 = Color3.fromRGB(190,90,255)
sHandle.Text = ""; sHandle.BorderSizePixel = 0; sHandle.ZIndex = 15
Instance.new("UICorner", sHandle).CornerRadius = UDim.new(1,0)
local shs = Instance.new("UIStroke", sHandle)
shs.Color = Color3.fromRGB(230,170,255); shs.Thickness = 1.5

local sSliding = false
sHandle.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then sSliding = true end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then sSliding = false end
end)
UserInputService.TouchMoved:Connect(function(touch)
    if not sSliding then return end
    local abs = sTrack.AbsolutePosition
    local sz  = sTrack.AbsoluteSize
    local pct = math.clamp((touch.Position.X - abs.X) / sz.X, 0, 1)
    CFG.AimSmooth = math.floor(pct * 100) / 100
    sFill.Size = UDim2.new(pct,0,1,0)
    sHandle.Position = UDim2.new(pct,0,0.5,0)
    sLbl.Text = "Aim Smooth  •  " .. string.format("%.2f", CFG.AimSmooth)
end)

local hint = Instance.new("TextLabel", win)
hint.Text = "hold right side of screen to aim"
hint.Size = UDim2.new(1,-20,0,14)
hint.Position = UDim2.new(0,10,1,-22)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(95,45,150)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.ZIndex = 13

-- ╔══════════════════════════════════════════╗
-- ║  PASTE THE FULL SCRIPT HERE — END        ║
-- ╚══════════════════════════════════════════╝

end)

if not ok then
    warn("[ollie_mod] error: " .. tostring(err))
end
