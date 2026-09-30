# PGR Character Rendering

基于团结引擎（Tuanjie）/ Unity URP 的《战双帕弥什》角色渲染研究，当前内容为露西亚·誓焰【光耀颂赞】的角色表现整理与还原。自定义 Shader 覆盖 Face、Eyes、Hair、Clothes、Upper 等材质，并包含刘海阴影 Renderer Feature。角色资源与第三方转换工具的再分发权限需要单独核实，见「资源来源与许可」。

## 效果预览

![整体效果](Docs/Screenshots/overview.png)

![近景效果](Docs/Screenshots/portrait.png)

## 运行环境

- 团结引擎 **Tuanjie `1.6.7`**，其项目记录的 EditorVersion 为 `2022.3.61t8`（`ProjectSettings/ProjectVersion.txt`）。
- Universal Render Pipeline **`14.1.0`**（`Packages/manifest.json`），锁定依赖使用 `packages.tuanjie.cn`。
- 工程场景使用 `.scene` 与团结序列化格式；尚未验证直接用标准 Unity 2022.3 打开，也不应将版本号相近视为兼容验证。

## 当前内容

- 角色资源、场景与材质已整理到可直接运行的 Unity 工程中
- 自定义角色渲染 Shader，覆盖面部、眼睛、头发、服装与 upper 材质
- 针对 upper 区域做了对比度与间接光表现的调整，改善原本层次偏灰的问题
- 保留了工程运行所需的 URP 配置、依赖包与示例资源

## 目录结构

- `Assets/Scenes/SampleScene.scene`：示例场景，与 `EditorBuildSettings.asset` 中的路径一致
- `Assets/露西亚 誓焰 光耀颂赞/`：角色模型、贴图、材质、脚本与自定义 Shader
- `Assets/Settings/`：URP 相关资源与 Renderer 配置
- `Packages/`：Unity 包依赖
- `ProjectSettings/`：项目设置

## Shader 与渲染流程

| 入口 | 源码中的实现 |
| --- | --- |
| `Shaders/Face.shader` | 面部 Ramp、AO、Blush、Rim 与眉毛/面部变体 |
| `Shaders/Eyes.shader` | Iris Depth 驱动的 UV 视差、Limbus 暗边与高光；这是外观近似，并非物理折射求解 |
| `Shaders/Hair.shader`, `Hair2.shader` | Ramp 明暗、贴图控制的高光和描边；Hair 还提供 `BangsShadow` Pass |
| `Shaders/Clothes.shader`, `Body.shader`, `Upper.shader` | 分区域材质与光照控制；Upper 保留对比度、间接光与金属变体调节 |
| `Scripts/FaceDepth.cs`（`CelHairShadow`） | URP `ScriptableRendererFeature`：按 Layer/Queue 筛选面部和头发，写入 R8 `_HairSolidColor` 纹理 |

这些相对路径均位于 `Assets/露西亚 誓焰 光耀颂赞/`。Renderer Feature 的 Layer、队列、材质和 URP Renderer 配置需要一起检查；单个 Shader 文件不能证明完整场景已正确连通。平滑法线处理入口为 `Scripts/SimpleSmoothNormalBaker.cs`，结果写入 Vertex Color。

## 使用方式

1. 取得完整 checkout，使用与项目记录匹配的团结引擎 `1.6.7` / `2022.3.61t8` 打开工程目录。
2. 等待 Packages、模型与 Shader 导入。保留 `Packages/packages-lock.json`、`ProjectSettings/` 与资产 `.meta`；不要把 `.scene` 改名为 `.unity` 来代替格式迁移。
3. 打开 `Assets/Scenes/SampleScene.scene`。
4. 检查 `Assets/Settings/` 的 URP Renderer、`CelHairShadow` Feature 与角色 Layer 配置，再在 Scene / Game 视图查看效果。

仓库的 `.gitattributes` 有一条 iOS 库 LFS 规则；实际还存在其他未由该规则覆盖的大型插件库。未在本次整理中执行 LFS 历史迁移。若 checkout 提示 LFS 对象缺失，需要使用 Git LFS 获取真实对象后再判断依赖是否齐全。

## 说明

本仓库主要用于角色渲染研究、效果整理与工程归档。

2026 年 9 月仓库整理核对了版本记录、依赖、真实场景路径和 Shader/Renderer Feature 源码；环境中没有匹配的团结 Editor，因此未验证资源导入、Shader 编译或场景运行。预览图片保留原结果，不代表本次完成了新环境的运行回归。

## 资源来源与许可

- 角色模型、PMX/FBX、纹理与名称来自《战双帕弥什》相关角色内容，当前仓库未附上允许公开源资产再分发的权利证明。根目录 MIT 不能自动覆盖这些第三方资源。
- **PMX2FBX 存在明确再分发限制**：[仓库内原始说明](Assets/MMD4Mecanim/Editor/PMX2FBX/readme.txt) 的 Redistribution 段落要求事先取得作者许可，并明确要求不要上传到公开 GitHub 空间。该目录内的工具二进制及依赖目前仍在仓库中；本次保留原文件与声明，未把它们解释为 MIT。
- 原说明还要求遵守模型和动作的各自条款；Bullet、MeCab、Autodesk FBX 等组件也有独立声明，应逐项保留和检查。

后续需要确认角色资产与 PMX2FBX 的授权，或由仓库所有者决定是否改为私有、移除受限制资源/工具、只发布自主 Shader 与合法示例资源。此处记录风险，不更改 visibility、LICENSE 或删除资产。
