from setuptools import setup

setup(
    name="odoo16-deps",
    version="1.0",
    install_requires=[
        line.strip()
        for line in open("requirements.txt")
        if line.strip() and not line.startswith("#")
    ],
    python_requires=">=3.6",
)
