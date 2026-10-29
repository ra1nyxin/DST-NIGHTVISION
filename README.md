**NightVision** 是一个《饥荒：联机版》（Don't Starve Together）的**客户端模组**（`client_only_mod = true`）。它让你在任意时刻通过一个热键切换“夜视”视觉效果，方便在黑暗中观察环境。它**只改变画面亮度/颜色**，**不提供任何黑暗保护**（仍然会受到查理的攻击、仍会损失理智）。

## 功能概览
- **一键夜视**：按下可配置的热键（默认 `N`），立即在客户端开启/关闭夜视效果。
- **黑暗警报**：开启夜视且处于黑暗中时，在角色身上周期性显示一个红色缩放的圆圈提示，提醒你“黑暗正在攻击你”。
- **纯客户端**：服务器无需安装该模组；每个玩家可独立使用。

---

## 文件结构

```
NightVision/
├── modinfo.lua        # 模组元数据、配置项定义
└── modmain.lua        # 主逻辑：热键注册、夜视切换、黑暗警报
```

> `Assets` 里引用的 `anim/winona_battery_placement.zip` 是**游戏本体**资源（薇诺娜发电机放置动画），并非模组自带文件，无需放到模组目录里。

## 安装与使用
1. 将 `NightVision` 文件夹放入：`Don't Starve Together/mods/NightVision/`
2. 启动游戏，在“模组”界面启用该模组。
3. 进入世界后，按热键（默认 `N`）切换夜视。

### 可配置项（`configuration_options`）
| 配置名 | 含义 | 默认 |
|---|---|---|
| `FREENIGHTVISION_TOGGLEKEY` | 切换夜视的按键（A~Z） | `N` |
| `FREENIGHTVISION_GRUEALERT` | 是否开启黑暗警报 | `true`（On） |

---

## 技术原理：夜视效果是如何实现的

### 1. 客户端夜视字段 `forcenightvision`
在 DST 的客户端组件 `playervision` 中有一个布尔字段 `forcenightvision`。当它为 `true` 时，`playervision:HasNightVision()` 会返回 `true`，客户端渲染就会应用“夜视”的画面效果（更亮的画面 + 夜视滤镜色调），并且不会叠加黑暗遮罩。

模组正是通过翻转这个字段来实现夜视的：

```lua
local hasnightvision = _G.ThePlayer.components.playervision:HasNightVision()
_G.ThePlayer.components.playervision.forcenightvision = not hasnightvision
```

- 这**只在客户端视觉上生效**：服务器仍然认为你处于黑暗中，所以理智下降、查理攻击、世界暗化判定都不受影响。
- 换句话说：**能看见 ≠ 安全**。

### 2. 推送事件以刷新画面
切换字段后，还需要通知其他客户端系统刷新状态：

```lua
_G.ThePlayer:PushEvent("nightvision", not hasnightvision)   -- 通知夜视状态变化
_G.ThePlayer:PushEvent("ccoverrides", nil)                 -- 刷新色彩校正覆盖层
_G.ThePlayer:PushEvent("ccphasefn", nil)                   -- 刷新相位色彩函数
```

- `nightvision`：标准玩家事件，通知监听者（视觉相关组件等）夜视状态已改变。
- `ccoverrides` / `ccphasefn`：用于强制客户端的色彩校正/相位系统重新计算屏幕色彩，避免切换夜视后出现**黑暗遮罩残留**或颜色未及时更新。
- 这些事件都推送到本地玩家 `ThePlayer` 上，属于**客户端侧**的事件。

### 3. 只在 HUD 界面响应热键
```lua
local screen = _G.TheFrontEnd:GetActiveScreen() and _G.TheFrontEnd:GetActiveScreen().name or ""
if screen:find("HUD") == nil then return end
```
如果当前激活的界面不是 HUD（例如主菜单、暂停菜单、聊天输入框等），则不响应热键，避免误触。

### 4. 热键注册
```lua
local ToggleNightvisionKey = GetModConfigData("FREENIGHTVISION_TOGGLEKEY"):lower():byte()
_G.TheInput:AddKeyUpHandler(ToggleNightvisionKey, function() ... end)
```
- `GetModConfigData` 读取配置的字母（如 `"N"`）。
- `:lower()` 转小写，`:byte()` 取第一个字符的 ASCII 码（`"n"` → `110`）。
- `AddKeyUpHandler` 在该按键**松开**时触发回调。

### 5. 黑暗警报 `SpawnGrueAlert`
在 `AddPlayerPostInit` 中为本地玩家启动一个每 0.25 秒执行一次的周期任务：

```lua
if inst.LightWatcher and inst.LightWatcher:GetTimeInDark() > 0.001 then
    if inst.components.playervision and inst.components.playervision.forcenightvision then
        SpawnGrueAlert(inst)
    end
end
```

- `LightWatcher:GetTimeInDark()`：玩家处于黑暗中的时长；`> 0.001` 即视为“处于黑暗中”。
- `forcenightvision == true`：说明当前夜视已开启。
- 满足条件时调用 `SpawnGrueAlert` 生成一个警告特效。

`SpawnGrueAlert` 的实现要点：
- 使用 `_G.CreateEntity()` 创建**非网络实体**（`Non-networked entity`），只在本机显示，不同步。
- 设置 `persists = false`，不会被存档保存；`SetCanSleep(false)` 保证其持续更新。
- 添加标签：`CLASSIFIED`（复制/特殊处理）、`NOCLICK`（不可点击）、`placer`（放置物类型渲染）。
- 动画：`SetBank` / `SetBuild` 为 `winona_battery_placement`，播放 `idle`；即借用薇诺娜发电机放置动画作为“光圈/警示图形”。
- `SetLightOverride(1)`：不受游戏光照影响，始终以完整亮度显示。
- `SetOrientation(OnGround)`：贴地渲染；`LAYER_BACKGROUND` + `SetSortOrder(1)`：位于背景层。
- `SetScale(0, 0)` 初始为 0；随后用 `DoTaskInTime` 让它在约 9 帧内放大到 1，再在约 9 帧内缩回 0，形成“脉冲”效果。
- `SetAddColour(1, 0, 0, 0)`：为动画叠加红色调。
- 0.5 秒后 `inst:Remove()` 自动销毁。
- 通过 `inst.entity:SetParent(parent.entity)` 挂到玩家身上，跟随玩家。

### 6. 延迟初始化
```lua
AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(0.25, function()
        ...
    end)
end)
```
在玩家实体初始化后延迟 0.25 秒再访问 `LightWatcher`，以确保该字段已经创建完成。

---

**NightVision** is a **client-side mod** (`client_only_mod = true`) for *Don't Starve Together*. It lets you toggle a "night vision" visual effect at any time via a hotkey, making it easier to observe your surroundings in the dark. It **only changes screen brightness/color** and provides **no protection from darkness** (you can still be attacked by Charlie and still lose sanity).

## Features
- **One-key night vision**: Press the configurable hotkey (default `N`) to toggle night vision on/off on the client.
- **Darkness alert**: While night vision is on and you are in darkness, a red pulsing circle is periodically displayed on your character to warn you that darkness is attacking.
- **Client-only**: The server does not need this mod; each player can use it independently.

---

## File Structure

```
NightVision/
├── modinfo.lua        # Mod metadata and configuration options
└── modmain.lua        # Main logic: hotkey, night vision toggle, darkness alert
```

> The `anim/winona_battery_placement.zip` referenced in `Assets` is a **game-native** resource (Winona battery placement animation), not a mod file. It does not need to be placed in the mod folder.

## Installation & Usage
1. Place the `NightVision` folder into: `Don't Starve Together/mods/NightVision/`
2. Launch the game and enable the mod from the Mods screen.
3. In-game, press the hotkey (default `N`) to toggle night vision.

### Configuration Options
| Name | Description | Default |
|---|---|---|
| `FREENIGHTVISION_TOGGLEKEY` | Key to toggle night vision (A–Z) | `N` |
| `FREENIGHTVISION_GRUEALERT` | Enable the darkness alert | `true` (On) |

---

## Technical Details: How the Night Vision Effect Works

### 1. The client-side `forcenightvision` field
The client component `playervision` has a boolean field `forcenightvision`. When set to `true`, `playervision:HasNightVision()` returns `true`, and the client renderer applies the "night vision" screen effect (brighter screen + night-vision color tint) and does not apply the darkness overlay.

The mod toggles this field:

```lua
local hasnightvision = _G.ThePlayer.components.playervision:HasNightVision()
_G.ThePlayer.components.playervision.forcenightvision = not hasnightvision
```

- This **only affects the client's visuals**: the server still considers you to be in darkness, so sanity drain, Charlie's attacks, and world-level darkness logic are unaffected.
- In other words: **seeing is not the same as being safe**.

### 2. Pushing events to refresh the screen
After toggling the field, other client systems need to be notified:

```lua
_G.ThePlayer:PushEvent("nightvision", not hasnightvision)   -- Notify night vision change
_G.ThePlayer:PushEvent("ccoverrides", nil)                 -- Refresh color-correction overrides
_G.ThePlayer:PushEvent("ccphasefn", nil)                   -- Refresh color phase function
```

- `nightvision`: standard player event notifying listeners that the night vision state has changed.
- `ccoverrides` / `ccphasefn`: forces the client's color-correction/phase systems to recompute the screen colors, avoiding a **lingering darkness overlay** or stale colors after toggling.
- These events are pushed on the local `ThePlayer` and are **client-side**.

### 3. Respond only within the HUD
```lua
local screen = _G.TheFrontEnd:GetActiveScreen() and _G.TheFrontEnd:GetActiveScreen().name or ""
if screen:find("HUD") == nil then return end
```
If the currently active screen is not the HUD (e.g., main menu, pause menu, chat box), the hotkey is ignored to avoid accidental triggers.

### 4. Hotkey registration
```lua
local ToggleNightvisionKey = GetModConfigData("FREENIGHTVISION_TOGGLEKEY"):lower():byte()
_G.TheInput:AddKeyUpHandler(ToggleNightvisionKey, function() ... end)
```
- `GetModConfigData` reads the configured letter (e.g., `"N"`).
- `:lower()` lowercases it, `:byte()` gets the first byte (ASCII code) (`"n"` → `110`).
- `AddKeyUpHandler` fires the callback when the key is **released**.

### 5. Darkness alert `SpawnGrueAlert`
Inside `AddPlayerPostInit`, a periodic task runs every 0.25 seconds for the local player:

```lua
if inst.LightWatcher and inst.LightWatcher:GetTimeInDark() > 0.001 then
    if inst.components.playervision and inst.components.playervision.forcenightvision then
        SpawnGrueAlert(inst)
    end
end
```

- `LightWatcher:GetTimeInDark()`: how long the player has been in darkness; `> 0.001` means "in darkness".
- `forcenightvision == true`: night vision is currently on.
- When both conditions hold, `SpawnGrueAlert` spawns a warning effect.

Implementation notes for `SpawnGrueAlert`:
- Creates a **non-networked entity** via `_G.CreateEntity()` — local-only, not synced.
- `persists = false` (not saved); `SetCanSleep(false)` (keeps updating).
- Tags: `CLASSIFIED` (special handling), `NOCLICK` (not clickable), `placer` (placer-style rendering).
- Animation: `SetBank` / `SetBuild` set to `winona_battery_placement`, plays `idle`; i.e., borrows Winona's battery placement animation as a "ring/warning" graphic.
- `SetLightOverride(1)`: renders at full brightness regardless of world lighting.
- `SetOrientation(OnGround)`: rendered on the ground; `LAYER_BACKGROUND` + `SetSortOrder(1)`: on the background layer.
- Starts at `SetScale(0, 0)`; then uses `DoTaskInTime` to scale it up to 1 over ~9 frames, then back down to 0 over ~9 frames, producing a "pulse".
- `SetAddColour(1, 0, 0, 0)`: applies a red tint to the animation.
- `inst:Remove()` after 0.5 s.
- Attached to the player via `inst.entity:SetParent(parent.entity)`, so it follows the player.

### 6. Delayed initialization
```lua
AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(0.25, function()
        ...
    end)
end)
```
The `LightWatcher` field is accessed 0.25 s after the player entity is initialized to ensure it already exists.
