from pypi_test_pkg import add, hello


def test_hello():
    assert hello() == "Hello, World!"
    assert hello("PyPI") == "Hello, PyPI!"


def test_add():
    assert add(1, 2) == 3
    assert add(-1, 1) == 0
