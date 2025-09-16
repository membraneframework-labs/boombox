from setuptools import Extension, setup

# This setup.py is used to declare the dummy C extension, which forces
# the build process to create a platform-specific wheel.
# All other package metadata should be kept in pyproject.toml.
setup(
    ext_modules=[
        Extension("guard", ["src/boombox/guard.c"]),
    ],
)
