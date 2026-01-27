from pathlib import Path
import sys
import subprocess

try:
    from setuptools import setup, find_packages
except ModuleNotFoundError:
    subprocess.check_call([sys.executable, "-m", "ensurepip", "--upgrade"])
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "setuptools", "wheel"])
    from setuptools import setup, find_packages


def read_version(package_name: str) -> str:
    package_init = Path(__file__).parent / package_name / "__init__.py"
    if not package_init.exists():
        return "0.0.0"
    for line in package_init.read_text(encoding="utf-8").splitlines():
        if line.startswith("__version__"):
            return line.split("=")[1].strip().strip('"').strip("'")
    return "0.0.0"


def read_long_description() -> str:
    candidate = Path(__file__).parent / "experiment_bofa" / "README.md"
    if candidate.exists():
        return candidate.read_text(encoding="utf-8")
    return ""


setup(
    name="experimentvr",
    version=read_version("experiment_bofa"),
    description="Code for the Vertical Relevance Resiliency Framework",
    long_description=read_long_description(),
    long_description_content_type="text/markdown",
    author="Vertical Relevance",
    url="https://github.com/VerticalRelevance/Experiment-Broker-Module",
    packages=find_packages(exclude=("lambda*",)),
    include_package_data=True,
    install_requires=[
        "boto3",
        "chaostoolkit",
        "chaostoolkit-aws",
        "chaostoolkit-kubernetes",
    ],
    python_requires=">=3.9",
)
