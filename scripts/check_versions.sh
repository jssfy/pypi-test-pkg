#!/bin/bash

# 查询包在 PyPI / TestPyPI 上已发布的所有版本

set -e

# 默认从 pyproject.toml 读取包名，也可通过参数指定
PACKAGE_NAME="${1:-}"
REGISTRY="${2:-both}"  # pypi | testpypi | both

if [ -z "$PACKAGE_NAME" ]; then
    if [ -f pyproject.toml ]; then
        PACKAGE_NAME=$(grep "name = " pyproject.toml | head -1 | cut -d'"' -f2)
    fi
fi

if [ -z "$PACKAGE_NAME" ]; then
    echo "用法: $0 <包名> [pypi|testpypi|both]"
    echo "  或在项目根目录下直接运行（自动从 pyproject.toml 读取包名）"
    exit 1
fi

echo "查询包名: $PACKAGE_NAME"
echo ""

query_versions() {
    local registry_name="$1"
    local api_url="$2"

    echo "=== $registry_name ==="
    RESPONSE=$(curl -s "$api_url")

    if echo "$RESPONSE" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
        VERSIONS=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
releases = data.get('releases', {})
# 按版本排序输出
for v in sorted(releases.keys()):
    files = releases[v]
    if files:
        upload_time = files[0].get('upload_time', 'N/A')
        print(f'  {v:20s}  (发布时间: {upload_time})')
    else:
        print(f'  {v:20s}  (无文件)')
if not releases:
    print('  (无已发布版本)')
")
        echo "$VERSIONS"
    else
        echo "  未找到该包，或请求失败。"
    fi
    echo ""
}

if [ "$REGISTRY" = "pypi" ] || [ "$REGISTRY" = "both" ]; then
    query_versions "PyPI" "https://pypi.org/pypi/$PACKAGE_NAME/json"
fi

if [ "$REGISTRY" = "testpypi" ] || [ "$REGISTRY" = "both" ]; then
    query_versions "TestPyPI" "https://test.pypi.org/pypi/$PACKAGE_NAME/json"
fi
