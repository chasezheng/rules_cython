# Cython Rules for Bazel

This repository allows Bazel to build Cython
libraries, which can be included in python applications as regular python modules.

The build rules require a python toolchain and a CC toolchain to be
preconfigured in the bazel project. See [rules_python](https://github.com/bazelbuild/rules_python/)
and [CC toolchain](https://bazel.build/tutorials/ccp-toolchain-config) for guides.

## Getting started

Initialize this repo in your bazel project:
```bzl
# MODULE.bazel

bazel_dep(name = "rules_cython", version = "0")

archive_override(
    module_name = "rules_cython",
    strip_prefix = "rules_cython-0.0.1",
    urls = ["https://github.com/chasezheng/rules_cython/archive/refs/tags/0.0.1.zip"],
)
```

Then declare your Cython build targets:
```BUILD.bazel
# BUILD.bazel

load("@rules_cython//:cython_library.bzl", "cython_library")

cython_library(
    name = "mylib",
    srcs = ["my.pxy", "my.pxd", "other.py"],
)
```
