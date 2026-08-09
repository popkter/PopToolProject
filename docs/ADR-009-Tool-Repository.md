# ADR-009：工具存储仓库接口

- 状态：已采用
- 日期：2026-07-24

## 背景

PopTools 当前以 JSON 文件保存用户自定义命令和内置工具覆盖。该方式适合单机、单用户、启动时整体加载和低频写入的使用方式。未来加入执行历史、版本管理、复杂筛选或数千级工具后，用户数据可能迁移到 SQLite。

## 决策

领域层定义 `ToolRepository` 协议，`ToolRegistry` 只依赖该协议。当前基础设施层提供 `JsonToolRepository`：

```text
ToolRegistry
    └── ToolRepository
            ├── JsonToolRepository     当前
            └── SqliteToolRepository   未来
```

应用设置继续由 `ConfigStore` 保存为 `config.json`。内置工具继续作为安装目录中的只读 JSON 资源。用户工具仓库只负责：

1. 列出自定义工具与内置覆盖；
2. 保存自定义工具或覆盖；
3. 删除覆盖以恢复内置版本；
4. 删除用户创建的本地命令，并在删除前备份。

## 兼容性

本次调整不改变 `%LOCALAPPDATA%\PopTools` 下的目录、文件名或 JSON 结构，因此现有用户数据无需迁移。未来 SQLite 适配器上线时，应提供一次性 JSON 导入，并在成功校验后保留原 JSON 备份。

## SQLite 启用条件

满足以下任一条件时重新评估迁移：

- 工具数量达到数千级并需要分页或组合查询；
- 引入执行历史、收藏、统计或工具版本表；
- 需要事务或多个进程并发写入；
- JSON 全量加载已经产生可测量的启动性能问题。


