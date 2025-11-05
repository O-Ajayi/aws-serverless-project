from setuptools import setup, find_packages

# When setup.py is inside the package directory, find_packages() finds subpackages
# but we need to install them as experiment_bofa.*
# We'll use package_dir to tell setuptools the root is one level up
setup(
    name="experiment_bofa",
    version="0.1.0",
    package_dir={"experiment_bofa": "."},
    packages=["experiment_bofa"] + [f"experiment_bofa.{pkg}" for pkg in find_packages()],
    install_requires=[
        "boto3>=1.26.0",
    ],
    python_requires=">=3.9",
)
