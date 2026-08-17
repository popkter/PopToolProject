# ADR-010：引入应用组合根

## 状态

已接受

## 背景

此前 `poptools.main` 同时负责 Qt 启动、单实例处理、资源初始化、配置加载、运行器创建和 ViewModel 连接。虽然代码已经按 `domain / infrastructure / runners / viewmodels` 分组，但应用对象图仍由桌面入口直接拼装，导致：

- 启动流程难以复用和单独测试；
- ViewModel 的构造依赖细节散落在入口中；
- 未来增加第二个前端或替换基础设施时容易复制装配代码。

## 决策

采用轻量 Clean Architecture / Ports-and-Adapters，不进行一次性的大规模目录迁移：

1. 新增 `poptools.application.bootstrap` 作为组合根。
2. `build_components()` 集中创建配置、仓库、工具注册表、执行协调器、Android 服务和 ViewModel。
3. `ApplicationComponents` 显式持有长生命周期对象，明确对象所有权和启动后的依赖图。
4. `poptools.main` 只保留进程入口、Qt 生命周期、单实例/托盘/窗口绑定和 QML 加载。
5. 保留现有 `viewmodels`、`runners` 和 `infrastructure` 导入路径，避免破坏现有测试与扩展。

## 目标依赖方向

```text
domain（模型、规则、协议）
        ↑
application（组合根、应用服务）
        ↑
presentation（ViewModel、QML）

infrastructure（文件、QProcess、Android、Windows）
        └── 由 application 组合根注入
```

这里的“组合根”是唯一允许了解所有具体实现的位置。领域层不依赖 Qt、文件系统或 Windows；基础设施层实现运行所需的具体能力；界面层只使用已装配的控制器。

## 取舍

本次不把每个现有类强行拆成接口，也不新增空泛的 `Service` 层。项目当前规模下，过度抽象会增加维护成本；当某个外部能力出现第二个实现或需要跨前端复用时，再把对应边界下沉为领域协议。

## 验证方式

- 现有单元测试继续通过；
- `poptools.main` 与 `python -m poptools` 启动路径不变；
- worker 参数 `--worker` 和 `--worker-code` 保持兼容；
- 应用行为、用户数据目录和打包资源路径不变。
