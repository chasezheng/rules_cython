load("//:_common.bzl", "get_py_module_name", "remove_file_name_extension")
load("//:_cython_compile.bzl", "cython_compile")
load("//:_cython_compile_env.bzl", "cython_compile_env")

# See cython documentation at
# https://cython.readthedocs.io/en/latest/src/userguide/source_files_and_compilation.html#compiler-directives
_DEFAULT_COMPILER_DIRECTIVE = {
    "binding": "True",
    "language_level": "3",
    "embedsignature": "True",
    "embedsignature.format": "python",
    "emit_code_comments": "True",
    "unraisable_tracebacks": "True",
    "c_string_type": "bytes",
    "c_string_encoding": "default",
    "profile": "False",
    "linetrace": "False",
}

def cython_library(
        name,
        cc_deps = [],
        py_deps = [],
        pyx_deps = [],
        srcs = [],
        compiler_directives = {},
        visibility = None,
        data = [],
        srcs_version = "PY3",
        **kwargs):
    """Compiles a group of .pyx / .pxd / .py files.

    - Compile pyx and pxd files into cpp files
    - Compile each cpp file into a shared object
    - Bundle the shared objects and py files into a py_library target

    Args:
        name: Name for the rule.
        cc_deps: C/C++ dependencies of the Cython (e.g. Numpy headers).
        py_deps: Pure Python dependencies of the final library.
        pyx_deps: Cython dependencies. These are needed for "cimport" in
            cython code.
        srcs: .py, .pyx, or .pxd files to either compile or pass through.
        **kwargs: Extra keyword arguments passed to the py_library.
    """
    if "deps" in kwargs:
        fail('Please use "cc_deps", "py_deps", or "pyx_deps", instead of "deps".')

    compiler_directives = _update_dict(
        base = _DEFAULT_COMPILER_DIRECTIVE,
        update = compiler_directives,
    )
    data = list(data)
    cc_deps = list(cc_deps) + [_get_cc_target_name(n) for n in pyx_deps]

    # First filter out files that should be run compiled vs. passed through.
    py_srcs = []
    pyx_srcs = []
    pxd_srcs = []
    for src in srcs:
        if src.endswith(".pyx") or (src.endswith(".py") and
                                    src[:-3] + ".pxd" in srcs):
            pyx_srcs.append(src)
        elif src.endswith(".py"):
            py_srcs.append(src)
        elif src.endswith("pyi"):
            data.append(src)
        else:
            pxd_srcs.append(src)
        if src.endswith("__init__.py"):
            pxd_srcs.append(src)

    if not pyx_srcs:
        fail("please add .pyx srcs. Empty ones could work.")

    cython_compile_env(
        name = _get_pxds_target_name(name).name,
        pxd_srcs = pxd_srcs,
        cython_deps = [_get_pxds_target_name(l) for l in pyx_deps],
        visibility = visibility,
    )

    shared_objects = []
    for filename in pyx_srcs:
        stem = remove_file_name_extension(filename)
        shared_object = stem + ".so"
        cython_compile(
            name = stem + ".compile",
            compiler_directives = compiler_directives,
            pyx = filename,
            compile_env = _get_pxds_target_name(name),
            visibility = ["//visibility:private"],
        )
        native.cc_binary(
            name = shared_object,
            srcs = [stem + ".compile"],
            deps = cc_deps + ["@rules_python//python/cc:current_py_cc_headers"],
            linkshared = 1,
            local_defines = ["CYTHON_TRACE_NOGIL=%s" % (1 if compiler_directives["profile"] == True else 0)],
            visibility = ["//visibility:private"],
        )
        shared_objects.append(shared_object)

    native.cc_library(
        name = _get_cc_target_name(name).name,
        deps = shared_objects + cc_deps,
        visibility = visibility,
    )

    # Now create a py_library with these shared objects as data.
    native.py_library(
        name = name,
        srcs = py_srcs,
        deps = py_deps + pyx_deps,
        srcs_version = srcs_version,
        data = list(data) + shared_objects,
        visibility = visibility,
        **kwargs
    )

def _update_dict(base, update):
    base = dict(base)
    base.update(update)
    return base

def _get_pxds_target_name(pyx_target):
    pyx_target = native.package_relative_label(pyx_target)
    out = pyx_target.relative(":%s.pxds" % pyx_target.name)
    return out

def _get_cc_target_name(pyx_target):
    pyx_target = native.package_relative_label(pyx_target)
    return pyx_target.relative(":%s.cc.deps" % pyx_target.name)
