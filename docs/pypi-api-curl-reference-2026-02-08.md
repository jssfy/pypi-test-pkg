# PyPI API 请求参考（curl 示例）

## 核心结论

项目中共使用 3 类 HTTP 请求，均为 PyPI/TestPyPI 的公开 API：

1. **查询包所有版本** — JSON API（GET）
2. **检查特定版本是否存在** — JSON API（GET，仅判断 HTTP 状态码）
3. **上传分发包** — Upload API（POST，由 twine 封装）

---

## 1. 查询包的所有版本信息

**用途**：获取包的完整元数据和所有已发布版本列表。

**项目使用位置**：`scripts/check_versions.sh:31`

### PyPI

```bash
curl -s "https://pypi.org/pypi/{包名}/json"

# 示例
curl -s "https://pypi.org/pypi/pypi-test-pkg-jssfy/json"
```

### TestPyPI

```bash
curl -s "https://test.pypi.org/pypi/{包名}/json"

# 示例
curl -s "https://test.pypi.org/pypi/pypi-test-pkg-jssfy/json"
```

### 响应说明

- **200**：返回 JSON，包含 `info`（包元数据）、`releases`（所有版本及文件列表）、`urls`（最新版本文件）、`vulnerabilities`（漏洞信息）
- **404**：包不存在

### 提取版本列表示例

```bash
curl -s "https://pypi.org/pypi/pypi-test-pkg-jssfy/json" | \
  python3 -c "import sys,json; [print(v) for v in sorted(json.load(sys.stdin).get('releases',{}).keys())]"
```

---

## 2. 检查特定版本是否已发布

**用途**：发布前检测目标版本号是否已被占用，防止重复上传。

**项目使用位置**：
- `scripts/publish_pypi.sh:38`
- `scripts/publish_testpypi.sh:38`

### PyPI

```bash
curl -s -o /dev/null -w "%{http_code}" "https://pypi.org/pypi/{包名}/{版本}/json"

# 示例
curl -s -o /dev/null -w "%{http_code}" "https://pypi.org/pypi/pypi-test-pkg-jssfy/0.1.0/json"
```

### TestPyPI

```bash
curl -s -o /dev/null -w "%{http_code}" "https://test.pypi.org/pypi/{包名}/{版本}/json"

# 示例
curl -s -o /dev/null -w "%{http_code}" "https://test.pypi.org/pypi/pypi-test-pkg-jssfy/0.1.0/json"
```

### curl 参数说明

| 参数 | 作用 |
|------|------|
| `-s` | 静默模式，不输出进度条 |
| `-o /dev/null` | 丢弃响应体 |
| `-w "%{http_code}"` | 仅输出 HTTP 状态码 |

### 状态码判断

| 状态码 | 含义 | 项目中的处理 |
|--------|------|-------------|
| `200` | 该版本已存在 | 报错退出，阻止重复上传 |
| `404` | 该版本不存在 | 继续发布流程 |

---

## 3. 上传分发包（twine）

**用途**：将构建好的 `.whl` 和 `.tar.gz` 上传到 PyPI/TestPyPI。

**项目使用位置**：
- `scripts/publish_pypi.sh:96`
- `scripts/publish_testpypi.sh:80`

项目通过 `twine` 封装上传，底层是 HTTP POST 请求：

### twine 命令

```bash
# 上传到 TestPyPI
python3 -m twine upload --repository testpypi dist/*

# 上传到正式 PyPI
python3 -m twine upload dist/*
```

### 等效 curl（供参考）

```bash
# 上传到 TestPyPI
curl -F ":action=file_upload" \
     -F "protocol_version=1" \
     -F "content=@dist/pypi_test_pkg_jssfy-0.1.0-py3-none-any.whl" \
     -H "Authorization: Basic $(echo -n '__token__:{YOUR_TOKEN}' | base64)" \
     https://test.pypi.org/legacy/

# 上传到正式 PyPI
curl -F ":action=file_upload" \
     -F "protocol_version=1" \
     -F "content=@dist/pypi_test_pkg_jssfy-0.1.0-py3-none-any.whl" \
     -H "Authorization: Basic $(echo -n '__token__:{YOUR_TOKEN}' | base64)" \
     https://upload.pypi.org/legacy/
```

> 实际使用中推荐 twine 而非裸 curl，因为 twine 会自动处理元数据字段、哈希校验、多文件上传等细节。

### Upload API 端点

| 平台 | 上传端点 |
|------|---------|
| PyPI | `https://upload.pypi.org/legacy/` |
| TestPyPI | `https://test.pypi.org/legacy/` |

### 认证方式

- **Username**：`__token__`
- **Password**：对应平台的 API token

---

## API 端点汇总

| 用途 | HTTP 方法 | PyPI 端点 | TestPyPI 端点 |
|------|----------|-----------|--------------|
| 查询包信息 | GET | `https://pypi.org/pypi/{包名}/json` | `https://test.pypi.org/pypi/{包名}/json` |
| 查询特定版本 | GET | `https://pypi.org/pypi/{包名}/{版本}/json` | `https://test.pypi.org/pypi/{包名}/{版本}/json` |
| 上传分发包 | POST | `https://upload.pypi.org/legacy/` | `https://test.pypi.org/legacy/` |

---

## 官方文档链接

- [PyPI JSON API](https://docs.pypi.org/api/json/) — 查询包信息和版本的 JSON API 文档
- [PyPI Upload API](https://docs.pypi.org/api/upload/) — 上传分发包的 API 文档
- [PyPI API 总览](https://docs.pypi.org/api/) — 所有 API 的入口页面
- [Twine 文档](https://twine.readthedocs.io/) — 上传工具 twine 的官方文档
- [Warehouse 文档](https://warehouse.pypa.io/) — PyPI 底层平台 Warehouse 的开发文档
