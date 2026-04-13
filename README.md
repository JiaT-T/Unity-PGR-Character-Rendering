# PGR Character Rendering

基于 Unity URP 对《战双帕弥什》角色“露西亚 誓焰 光耀颂赞”的角色渲染练习项目。仓库内包含角色资源、场景、材质以及自定义 Shader，重点放在整体风格化角色渲染、面部/头发表现和服装材质层次的整理。

## 效果预览

![整体效果](Docs/Screenshots/overview.png)

![近景效果](Docs/Screenshots/portrait.png)

## 环境

- Unity `2022.3.61t8`
- Universal Render Pipeline `14.1.0`

## 当前内容

- 角色资源与示例场景已整理到工程中，可直接打开查看
- 自定义角色 Shader 包含面部、眼睛、头发、服装和 upper 材质
- 对 upper 材质的阴影与间接光做了调整，改善了原先对比度偏低的问题
- 工程内保留了 URP Renderer 配置、材质球和运行所需依赖

## 目录结构

- `Assets/Scenes/SampleScene.scene`：示例场景
- `Assets/露西亚 誓焰 光耀颂赞/`：角色模型、贴图、材质、脚本与自定义 Shader
- `Assets/Settings/`：URP 资源与 Renderer 配置
- `Packages/`：Unity 包依赖
- `ProjectSettings/`：项目设置

## 使用方式

1. 使用 Unity Hub 打开本项目
2. 选择 Unity `2022.3.61t8`
3. 打开 `Assets/Scenes/SampleScene.scene`
4. 直接运行，或在 Scene/Game 视图中查看角色渲染效果

## 说明

本仓库主要用于角色渲染研究与效果整理，当前提交以可直接打开和查看效果为目标。
