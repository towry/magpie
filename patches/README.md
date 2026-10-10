# Magpie Patch Set

此目录仅存部署所需、相对 `main` 施加之私有补丁。

`deploy` 是孤儿分支：不含 magpie 源码。同步上游时只快进 `main`，再在这份 series 上 rebase 补丁，避免把私有改动和上游提交揉在一起产生大量 conflict。

## Files

- `series`: patch 施行顺序
- 当前 series 为空。加入补丁后在此列出文件名与用途。

## Rules

- 勿纳仅供本地 agent 使用之文档、提示或工作流说明
- 每枚 patch 只做一事，便于冲突定位与回滚
- 未写入 `series` 的 `.patch` 文件不会被施加

## Regenerate

在源码分支完成改动后，可用 `git diff -- <paths...> > patches/<name>.patch` 重生补丁，并更新 `series`。
