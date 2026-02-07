"""PyPI publishing test package."""

__version__ = "0.0.1"


def hello(name: str = "World") -> str:
    """Return a greeting."""
    return f"Hello, {name}!"


def add(a: int, b: int) -> int:
    """Add two numbers."""
    return a + b


__all__ = ["hello", "add"]
