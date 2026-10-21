# Magpie Patch Set

此目录仅存部署所需、相对 `main` 施加之私有补丁。

`deploy` 是孤儿分支：不含 magpie 源码。同步上游时只快进 `main`，再在这份 series 上 rebase 补丁，避免把私有改动和上游提交揉在一起产生大量 conflict。

## Files

- `series`: patch 施行顺序
- `0001-claude-code-api-key-optin.patch`: custom Anthropic API-key provider 可设 `claudeCode: true`，走 genuine Claude Code 子进程（不伪造订阅 Account，失败不回退 HTTP/OAuth）

## Rules

- 勿纳仅供本地 agent 使用之文档、提示或工作流说明
- 每枚 patch 只做一事，便于冲突定位与回滚
- 未写入 `series` 的 `.patch` 文件不会被施加

## Regenerate

在源码分支完成改动后，可用 `git diff -- <paths...> > patches/<name>.patch` 重生补丁，并更新 `series`。

## 自动构建与发布

推送到 `deploy` 且修改 `patches/`、`scripts/` 或 `release-linux.yml` 时，
`Release Linux CLI` 会自动校验补丁、构建 Linux amd64/arm64 并公开发布。
也可以手动运行同一个 workflow，不需要填写版本号：

```bash
gh workflow run release-linux.yml --repo towry/magpie --ref deploy
```

每次运行固定源码和补丁两个 commit，Release tag 为
`fork-<source 前 12 位>-patch-<deploy 前 12 位>`，tag 指向 deploy commit。
发布包含两个二进制、`SHA256SUMS`、`VERSION` 和 `BUILDINFO`。
这类 fork Release 不会改动 GitHub 的 Latest 标记。

发布前验证本地 checksum 和 GitHub 上传资产的 digest。
同版本重跑会核对已有产物，完全一致则不做改动；不一致则失败，绝不覆盖。
上传中断留下的 draft 可以补齐，只有全部资产验证通过后才公开。
补丁冲突或构建失败不会发布新版本。

同步 `main` 本身不会触发这条 `deploy` workflow；同步后可执行上面的手动命令。
此流程只发布安装包，不会更新 dots 或重启服务器。
