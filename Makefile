.PHONY: help build clean check-versions bump-patch bump-minor bump-major publish-testpypi publish-pypi

help: ## 显示帮助信息
	@echo ""
	@echo "用法: make <target>"
	@echo ""
	@echo "构建:"
	@echo "  build              构建分发包 (sdist + wheel)"
	@echo "  clean              清理构建产物 (dist/, build/, *.egg-info)"
	@echo ""
	@echo "版本管理:"
	@echo "  bump-patch         补丁版本 +1  (0.0.1 → 0.0.2)"
	@echo "  bump-minor         次版本 +1    (0.0.1 → 0.1.0)"
	@echo "  bump-major         主版本 +1    (0.0.1 → 1.0.0)"
	@echo "  check-versions     查询 PyPI/TestPyPI 已发布版本"
	@echo ""
	@echo "发布:"
	@echo "  publish-testpypi   构建并发布到 TestPyPI (测试)"
	@echo "  publish-pypi       构建并发布到正式 PyPI"
	@echo ""

build:
	python3 -m build

clean:
	rm -rf dist/ build/ *.egg-info src/*.egg-info

check-versions:
	@bash scripts/check_versions.sh

bump-patch:
	@bash scripts/bump_version.sh patch

bump-minor:
	@bash scripts/bump_version.sh minor

bump-major:
	@bash scripts/bump_version.sh major

publish-testpypi:
	@bash scripts/publish_testpypi.sh

publish-pypi:
	@bash scripts/publish_pypi.sh
