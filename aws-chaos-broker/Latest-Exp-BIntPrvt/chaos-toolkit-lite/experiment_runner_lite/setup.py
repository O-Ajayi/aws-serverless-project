from setuptools import setup, find_packages

setup(
    name="experiment_runner_lite",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "boto3>=1.26.0",
    ],
    python_requires=">=3.9",
)
