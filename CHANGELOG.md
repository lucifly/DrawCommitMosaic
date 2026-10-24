# 变更记录

## Unreleased

### 新增

- `scripts/draw-commits.sh`：单日期、多日期及文件输入，支持指定仓库、自定义提交消息、预览和本地执行。
- 独立的 18 个历史爱心日期示例，以及无网络的临时仓库集成测试。
- README 爱心效果截图，已移除 EXIF、文本和截图时间等附加元数据。
- ShellCheck、shfmt、Make 检查入口，Linux/macOS CI 配置和贡献模板。
- MIT 许可证、编辑器配置和完善的使用说明。

### 行为变化

- 默认只预览，使用 `--apply` 才创建本地空提交。
- 同时设置 author date 和 committer date，不再 amend 已有提交或写入占位文件。
- 不再自动执行 `git add .`、pull 或 push。
- 应用前检查完整日期批次、工作区状态、分支和 Git 身份配置。
- 保留 `drawHeart.sh` 与 `shellpullpush.sh` 作为兼容入口；旧入口也遵循新的默认预览行为。

这些改动尚未发布为版本标签或 GitHub Release。
