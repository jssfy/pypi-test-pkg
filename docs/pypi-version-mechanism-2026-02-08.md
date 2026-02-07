# PyPI 包版本号决定机制分析

## 核心结论

PyPI/TestPyPI 上注册的版本号由 **dist 包内部的元数据文件** 决定，而非 dist 文件名。

- **wheel**（`.whl`）：读取内部 `METADATA` 文件的 `Version` 字段
- **sdist**（`.tar.gz`）：读取内部 `PKG-INFO` 文件的 `Version` 字段
- 文件名中的版本号只是构建工具根据同一来源生成的副产物，PyPI 不以文件名为准

---

## 分析过程

### 1. 构建分发包

执行 `python3 -m build`，构建后端（本项目为 hatchling）从 `pyproject.toml` 读取版本号，生成两个文件：

```
dist/
├── pypi_test_pkg_jssfy-0.1.0.tar.gz          # sdist
└── pypi_test_pkg_jssfy-0.1.0-py3-none-any.whl # wheel
```

### 2. 查看 wheel 内部元数据

```bash
unzip -p dist/*.whl '*/METADATA' | head -5
```

输出：

```
Metadata-Version: 2.4
Name: pypi-test-pkg-jssfy
Version: 0.1.0                  ← PyPI 读取此字段
Summary: A test package for PyPI publishing workflow testing
Author-email: Example Author <309228933@qq.com>
```

元数据文件路径：`{包名}-{版本}.dist-info/METADATA`

### 3. 查看 sdist 内部元数据

```bash
tar -xzf dist/*.tar.gz -O --include='*/PKG-INFO' | head -5
```

输出：

```
Metadata-Version: 2.4
Name: pypi-test-pkg-jssfy
Version: 0.1.0                  ← PyPI 读取此字段
Summary: A test package for PyPI publishing workflow testing
Author-email: Example Author <309228933@qq.com>
```

元数据文件路径：`{包名}-{版本}/PKG-INFO`

### 4. 验证结论

两处元数据文件中的 `Version` 字段一致，且与 `pyproject.toml` 中的 `version` 值一致。

---

## 版本源头链路

```
pyproject.toml
│  version = "0.1.0"
│
├─→ python3 -m build (hatchling)
│
├─→ wheel (.whl)
│     └─ {pkg}.dist-info/METADATA
│          Version: 0.1.0          ← PyPI 以此为准
│
└─→ sdist (.tar.gz)
      └─ {pkg}-{ver}/PKG-INFO
           Version: 0.1.0          ← PyPI 以此为准
```

## 元数据与文件名不一致时的行为

| 场景 | PyPI 行为 |
|------|----------|
| 文件名版本 = 元数据版本（正常情况） | 正常注册 |
| 手动修改文件名但未改元数据 | 按元数据中的 `Version` 注册 |
| 元数据中版本已存在于 PyPI | 拒绝上传（HTTP 400） |

## 要点总结

1. **唯一权威来源**：`pyproject.toml` 中的 `version` 字段
2. **构建工具职责**：将 `pyproject.toml` 的版本写入 `METADATA` / `PKG-INFO` 并体现在文件名中
3. **PyPI 判定依据**：包内部元数据文件的 `Version` 字段，不依赖文件名
4. **本项目版本管理**：通过 `make bump-{patch,minor,major}` 修改 `pyproject.toml`，构建时自动同步到包元数据
