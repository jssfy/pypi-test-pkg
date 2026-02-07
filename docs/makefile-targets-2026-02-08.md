# Makefile Targets 工作原理

## 核心结论

本项目 Makefile 定义了 7 个 target，覆盖 PyPI 包发布的完整生命周期：

- **构建/清理**：`build`、`clean` — 基础构建操作
- **版本管理**：`bump-patch`、`bump-minor`、`bump-major` — 语义化版本号递增
- **版本查询**：`check-versions` — 查询已发布版本
- **发布**：`publish-testpypi`、`publish-pypi` — 分别发布到测试和正式 PyPI

典型工作流：`bump-patch` → `publish-testpypi`（验证）→ `publish-pypi`（正式发布）

---

## Target 详解

### 1. `make build`

**作用**：构建 Python 分发包（sdist + wheel）。

```makefile
build:
	python3 -m build
```

- 调用 `python3 -m build`，读取 `pyproject.toml` 中的 `[build-system]` 配置
- 本项目使用 `hatchling` 作为构建后端
- 输出文件存放在 `dist/` 目录下，生成 `.tar.gz`（sdist）和 `.whl`（wheel）两种格式

### 2. `make clean`

**作用**：清理所有构建产物。

```makefile
clean:
	rm -rf dist/ build/ *.egg-info src/*.egg-info
```

- 删除 `dist/` — 分发包输出目录
- 删除 `build/` — 构建中间文件
- 删除 `*.egg-info` 和 `src/*.egg-info` — 包元数据缓存

### 3. `make check-versions`

**作用**：查询包在 PyPI / TestPyPI 上已发布的所有版本。

```makefile
check-versions:
	@bash scripts/check_versions.sh
```

**脚本工作流**（`scripts/check_versions.sh`）：

1. **读取包名**：优先使用命令行参数，否则从 `pyproject.toml` 的 `name` 字段提取
2. **支持指定仓库**：第二个参数可选 `pypi`、`testpypi` 或 `both`（默认 `both`）
3. **查询 API**：
   - PyPI：`https://pypi.org/pypi/{包名}/json`
   - TestPyPI：`https://test.pypi.org/pypi/{包名}/json`
4. **解析并输出**：用 Python 解析 JSON 响应，按版本号排序输出版本列表及发布时间

### 4. `make bump-patch` / `make bump-minor` / `make bump-major`

**作用**：按语义化版本规则递增 `pyproject.toml` 中的版本号。

```makefile
bump-patch:
	@bash scripts/bump_version.sh patch
bump-minor:
	@bash scripts/bump_version.sh minor
bump-major:
	@bash scripts/bump_version.sh major
```

**脚本工作流**（`scripts/bump_version.sh`）：

1. **定位项目根目录**：通过脚本自身路径的父目录定位，确保从任意位置调用都正确
2. **读取当前版本**：从 `pyproject.toml` 中 `grep` 提取 `version = "x.y.z"` 的值
3. **拆分版本号**：用 `IFS='.'` 将版本号拆为 `MAJOR.MINOR.PATCH` 三部分
4. **递增逻辑**：
   - `patch`：`PATCH += 1`（例 `0.0.1` → `0.0.2`）
   - `minor`：`MINOR += 1, PATCH = 0`（例 `0.0.1` → `0.1.0`）
   - `major`：`MAJOR += 1, MINOR = 0, PATCH = 0`（例 `0.0.1` → `1.0.0`）
5. **原地替换**：用 `sed -i ''` 直接修改 `pyproject.toml` 中的版本字符串

> 注意：`sed -i ''` 是 macOS（BSD sed）语法，Linux 上需改为 `sed -i`。

### 5. `make publish-testpypi`

**作用**：构建并发布包到 TestPyPI（测试仓库）。

```makefile
publish-testpypi:
	@bash scripts/publish_testpypi.sh
```

**脚本工作流**（`scripts/publish_testpypi.sh`），共 8 个步骤：

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | `rm -rf dist/ build/ *.egg-info` | 清理旧构建产物 |
| 2 | 读取 `pyproject.toml` 中的 `version` | 获取当前版本号 |
| 3 | `curl` 查询 TestPyPI API | 检查该版本是否已发布（HTTP 200 = 已存在则报错退出） |
| 4 | `python3 -m build` | 构建 sdist 和 wheel |
| 5 | `python3 -m twine check dist/*` | 校验分发包元数据是否合规 |
| 6 | `ls -lh dist/` | 展示生成的文件 |
| 7 | `read -p` 交互确认 | 用户确认是否上传（y/n） |
| 8 | `python3 -m twine upload --repository testpypi dist/*` | 上传到 TestPyPI |

上传成功后输出 TestPyPI 包页面链接和测试安装命令。

### 6. `make publish-pypi`

**作用**：构建并发布包到正式 PyPI。

```makefile
publish-pypi:
	@bash scripts/publish_pypi.sh
```

**脚本工作流**（`scripts/publish_pypi.sh`）：

与 `publish-testpypi` 流程基本一致，关键区别：

1. **版本检查的 API 地址不同**：使用 `https://pypi.org/pypi/{包名}/{版本}/json`
2. **双重确认**：上传前要求用户**确认两次**（因为正式 PyPI 上传后无法删除/覆盖）
3. **上传命令不同**：`python3 -m twine upload dist/*`（默认上传到正式 PyPI）

---

## Target 依赖关系

所有 target 声明为 `.PHONY`（伪目标），没有文件依赖，每次调用都会执行。

Target 之间无 Makefile 层面的依赖，但存在**逻辑执行顺序**：

```
bump-{patch,minor,major}     # 1. 先升版本号
        ↓
publish-testpypi              # 2. 发布到 TestPyPI 验证
        ↓
publish-pypi                  # 3. 验证通过后发布到正式 PyPI
```

`check-versions` 可在任意时刻调用，用于确认已发布的版本。

## 认证方式

`publish-testpypi` 和 `publish-pypi` 都通过 `twine` 上传，认证信息：
- **Username**：`__token__`
- **Password**：对应平台的 API token

可通过交互式输入，或提前配置 `~/.pypirc` 文件避免每次输入。
