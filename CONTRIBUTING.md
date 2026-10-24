# 贡献指南

欢迎通过 [Issues](https://github.com/lucifly/DrawCommitMosaic/issues) 反馈问题和建议。

## 开发环境

- Bash 3.2 或更新版本、Git、Make。
- [ShellCheck](https://github.com/koalaman/shellcheck) 和 [shfmt](https://github.com/mvdan/sh) 用于静态检查与格式检查。
- macOS 可运行 `brew install shellcheck shfmt`；Ubuntu/Debian 可通过软件包管理器安装同名工具。

## 检查

```bash
make format # 应用两空格缩进等 Shell 风格规则
make check  # ShellCheck、格式、语法与集成测试
```

也可分别运行 `make lint` 或 `make test`。测试使用临时目录和测试身份，结束后清理；不会改写开发仓库的历史，不需要 GitHub 登录或网络连接。

CI 配置在 `.github/workflows/ci.yml`：Linux 执行 lint，Linux 和 macOS 分别运行测试。CI 仅有仓库内容读取权限，不能推送生成的提交。

## 代码约定

- 兼容 macOS 自带 Bash 3.2；不要使用关联数组、`mapfile` 或依赖 GNU `date` 的日期转换。
- Shell 文件使用 LF、两空格缩进，运行 ShellCheck 时包含 style 级别，不通过忽略诊断规避检查。
- 引用路径与用户输入；使用参数和数组传递数据，不使用 `eval`。
- 保持默认预览、显式 `--apply`、整批日期预检和只创建空提交的行为。
- 不在脚本中加入自动暂存、amend、pull、push 或强制推送。
- 新增参数或改变默认行为时，同步更新使用说明、变更记录和集成测试。

## 提交变更

一个 Pull Request 聚焦一个问题，说明改动后的行为与实际验证结果。请对示例、截图和日志脱敏，不要提交真实邮箱、私人仓库地址或凭据。

贡献内容采用仓库的 [MIT License](LICENSE)。
