from setuptools import setup, find_packages

setup(
    name="neuroforge",
    version="1.0.0",
    description="The Official Software SDK for Project GODFATHER (Asynchronous Analog Neuromorphic AI)",
    author="JARVIS Corp",
    packages=find_packages(where="sdk"),
    package_dir={"": "sdk"},
    install_requires=[
        "numpy>=1.21.0",
        "torch>=1.9.0", # Optional but recommended
    ],
    entry_points={
        "console_scripts": [
            "neuroforge=neuroforge.cli:main",
        ],
    },
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Science/Research",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
        "Programming Language :: Python :: 3",
    ],
)
