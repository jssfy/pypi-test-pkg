# PyPI / TestPyPI 版本回退机制调研

## 核心结论

1. **允许在高版本发布后继续上传低版本** — 无顺序限制
2. **"latest" 按 PEP 440 版本号排序，非上传时间** — 后上传的低版本不会变成 latest
3. **`pip install` 默认安装版本号最高的版本**，与上传顺序无关
4. **删除最新版本后，pip 会自动回退到次新版本**
5. **已删除的版本号不可复用** — 重新上传会收到 `400 Bad Request`
6. **Yank（软删除）优于 Delete（硬删除）** — Yank 可逆且不浪费版本号

---

## 实际验证

### 测试场景

在 TestPyPI 上对 `pypi-test-pkg-jssfy` 进行以下操作：

| 操作顺序 | 上传版本 | 上传时间 |
|----------|---------|---------|
| 第 1 次 | `0.1.0` | 2026-02-07T17:43:44 |
| 第 2 次 | `0.0.1` | 2026-02-07T18:03:48 |

### 验证结果

**1. JSON API 返回的 latest 版本**

```bash
curl -s "https://test.pypi.org/pypi/pypi-test-pkg-jssfy/json" | python3 -c "
import sys,json; print(json.load(sys.stdin)['info']['version'])"
```

```
0.1.0    ← latest 仍然是 0.1.0，未被后上传的 0.0.1 覆盖
```

**2. pip 默认安装的版本**

```bash
pip install --dry-run -i https://test.pypi.org/simple/ pypi-test-pkg-jssfy
```

```
Would install pypi-test-pkg-jssfy-0.1.0    ← pip 选择版本号最高的
```

**3. Simple Index 中两个版本并存**

```
pypi_test_pkg_jssfy-0.0.1-py3-none-any.whl
pypi_test_pkg_jssfy-0.0.1.tar.gz
pypi_test_pkg_jssfy-0.1.0-py3-none-any.whl
pypi_test_pkg_jssfy-0.1.0.tar.gz
```

---

## 关键规则

### 1. 上传限制

| 规则 | 说明 |
|------|------|
| 版本号不可重复 | 同一版本号只能上传一次，即使删除后也无法重新上传 |
| 低版本可在高版本之后上传 | 无版本顺序限制，`0.0.1` 可以在 `0.1.0` 之后发布 |
| 文件名不可重复 | 同一 `(包名, 版本号, 分发类型)` 组合只能有一个文件 |

### 2. "latest" 版本的判定

PyPI 按 [PEP 440](https://peps.python.org/pep-0440/) 的版本排序规则判定 latest，**不是按上传时间**：

```
latest = max(所有已发布版本, key=PEP440排序)
```

排序规则：
```
1.0.0.dev1 < 1.0.0a1 < 1.0.0b1 < 1.0.0rc1 < 1.0.0 < 1.0.0.post1 < 1.0.1
```

### 3. pip 安装行为

**官方原文**（[pip install 文档](https://pip.pypa.io/en/stable/cli/pip_install/)）：

> "the latest version that satisfies the given constraints will be installed"

即 pip 默认安装满足约束条件的最新稳定版本，不指定约束时就是版本号最高的稳定版。

| 命令 | 安装版本 |
|------|---------|
| `pip install 包名` | 最高稳定版本（PEP 440 排序） |
| `pip install 包名==0.0.1` | 指定的 0.0.1 |
| `pip install '包名<0.1.0'` | 满足约束的最高版本 |

---

## 删除版本后的行为

### 问题 1：删除最新版后，pip 安装哪个版本？

**结论：自动回退到次新版本。**

**实际验证**：在 TestPyPI 网页上删除 `0.1.0` 后，对比删除前后的 pip 行为：

```bash
# 删除前
pip install --dry-run -i https://test.pypi.org/simple/ pypi-test-pkg-jssfy
# → Would install pypi-test-pkg-jssfy-0.1.0

# 删除后（需 --no-cache-dir 绕过本地缓存）
pip install --dry-run --no-cache-dir -i https://test.pypi.org/simple/ pypi-test-pkg-jssfy
# → Would install pypi-test-pkg-jssfy-0.0.1    ← 自动回退到次新版本
```

同时验证版本特定 API 已失效：

```bash
curl -s -o /dev/null -w "%{http_code}" "https://test.pypi.org/pypi/pypi-test-pkg-jssfy/0.1.0/json"
# → 404    ← 删除已生效
```

**原理**：pip 从 Simple Index 获取所有可用版本，按 PEP 440 排序后选最高的。删除 `0.1.0` 后，Index 中只剩 `0.0.1`，pip 自然选择它。

**注意：CDN 缓存延迟**。删除操作在服务端立即生效（版本特定 API 返回 404），但 JSON API 和 Simple Index 存在 CDN 缓存，短时间内可能仍返回旧数据。pip 加 `--no-cache-dir` 可绕过本地缓存，但 CDN 侧缓存需等待自动过期。

### 问题 2：已删除的版本号能否复用？

**结论：不能。** 已使用过的文件名永久保留，即使删除后也无法重新上传。

实际验证（尝试重新上传已存在的 `0.0.1`）：

```bash
python3 -m twine upload --repository testpypi dist/*
```

```
ERROR    HTTPError: 400 Bad Request from https://test.pypi.org/legacy/
         Bad Request
```

**官方原文**（[PyPI Help](https://pypi.org/help/)）：

> "PyPI does not allow for a filename to be reused, even once a project has been deleted and recreated."
>
> "Deletion of a project, release or file on PyPI is permanent and irreversable, without exception."

这意味着：
- 删除 `0.1.0` 后，该版本号**永远**无法再使用
- 必须使用新的版本号（如 `0.1.1`）重新发布

---

## 删除 vs Yank 对比

| 特性 | Delete（删除） | Yank（撤回） |
|------|---------------|-------------|
| 可逆性 | 不可逆 | **可逆**（可取消 yank） |
| 版本号复用 | 不可复用 | 不涉及（版本仍存在） |
| `pip install 包名` | 跳过，安装次新版 | 跳过，安装次新版 |
| `pip install 包名==x.y.z` | **失败**（版本不存在） | **成功**（仍可安装） |
| 锁文件 `==x.y.z` | **破坏**下游项目 | **不破坏**下游项目 |
| 适用场景 | 安全事件、法律合规 | 有 bug 的版本、误发布 |

**官方推荐**（[PyPI Yanking 文档](https://docs.pypi.org/project-management/yanking/)）：

> "A yanked release is a release that is always ignored by an installer, unless it is the only release that matches a version specifier (using either `==` or `===`)."

---

## 版本回退的正确做法

如果需要让用户默认安装旧版本（例如 `0.1.0` 有问题，想回退到 `0.0.1`），有以下方式：

### 方式 1：发布修复版本（推荐）

发布更高版本号的修复版（如 `0.1.1` 或 `0.2.0`），让 latest 自然前进。

### 方式 2：Yank 有问题的版本

```bash
# 通过 PyPI 网页界面或 API yank 指定版本
# yank 后，pip install 不会默认选中该版本，但 pip install 包名==0.1.0 仍可安装
```

Yank 不同于删除：
- **Yank**：从默认安装候选中移除，但指定版本号仍可安装
- **Delete**：永久删除，且该版本号永远无法再使用

### 方式 3：删除有问题的版本（不推荐）

通过 PyPI 网页删除 `0.1.0`，此操作**不可逆**，且该版本号永远无法重新上传。

---

## 参考链接

- [PyPI Help — 文件名复用与删除策略](https://pypi.org/help/) — 官方原文："PyPI does not allow for a filename to be reused"
- [PyPI Yanking 文档](https://docs.pypi.org/project-management/yanking/) — Yank 机制官方说明
- [PEP 440 — Version Identification and Dependency Specification](https://peps.python.org/pep-0440/) — 版本排序规则
- [Python Packaging User Guide — Versioning](https://packaging.python.org/en/latest/discussions/versioning/)
- [pypa/packaging-problems#74 — 已删除文件不可重新上传的讨论](https://github.com/pypa/packaging-problems/issues/74)
- [pypa/packaging-problems#75 — PyPI 旧版本上传策略讨论](https://github.com/pypa/packaging-problems/issues/75)
- [What to do when you botch a release on PyPI](https://snarky.ca/what-to-do-when-you-botch-a-release-on-pypi/) — Brett Cannon 的最佳实践建议
