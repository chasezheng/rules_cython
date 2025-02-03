load("//:_common.bzl", "get_py_module_name", "make_label", "remove_file_name_extension")

_ENABLE_PROFILING = False

_DEFAULT_COMPILER_DIRECTIVE = {
    "binding": True,
    "language_level": 3,
    "embedsignature": True,
    "embedsignature.format": "python",
    "emit_code_comments": True,
    "unraisable_tracebacks": True,
    "c_string_type": "bytes",
    "c_string_encoding": "default",
    "profile": _ENABLE_PROFILING,
    "linetrace": _ENABLE_PROFILING,
}

def update_dict(base, update):
    base = dict(base)
    base.update(update)
    return base

def _get_pxds_target_name(pyx_target):
    pyx_target = make_label(pyx_target)
    return pyx_target.relative(":%s.pxds.file-group" % pyx_target.name)

def _get_cc_target_name(pyx_target):
    pyx_target = make_label(pyx_target)
    return pyx_target.relative(":%s.cc.deps" % pyx_target.name)

def cython_library(
        name,
        cc_deps = [],
        py_deps = [],
        pyx_deps = [],
        srcs = [],
        compiler_directive = {},
        visibility = None,
        data = [],
        srcs_version = "PY3",
        **kwargs):
    """Compiles a group of .pyx / .pxd / .py files.

    First runs Cython to create .cpp files for each input .pyx or .py + .pxd
    pair. Then builds a shared object for each, passing "deps" to each cc_binary
    rule (includes Python headers by default). Finally, creates a py_library rule
    with the shared objects and any pure Python "srcs", with py_deps as its
    dependencies; the shared objects can be imported like normal Python files.

    Args:
        name: Name for the rule.
        cc_deps: C/C++ dependencies of the Cython (e.g. Numpy headers).
        py_deps: Pure Python dependencies of the final library.
        srcs: .py, .pyx, or .pxd files to either compile or pass through.
        **kwargs: Extra keyword arguments passed to the py_library.
    """
    if "deps" in kwargs:
        fail('Please use "cc_deps", "py_deps", or "pyx_deps", instead of "deps".')

    compiler_directive = update_dict(
        base = _DEFAULT_COMPILER_DIRECTIVE,
        update = compiler_directive,
    )
    compiler_directive_joined = ",".join([
        "%s=%s" % (k, v)
        for k, v in compiler_directive.items()
        if v != None
    ])
    data = list(data)
    pxd_deps = [_get_pxds_target_name(l) for l in pyx_deps]
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

    native.filegroup(
        name = _get_pxds_target_name(name).name,
        srcs = pxd_srcs + pxd_deps,
        visibility = visibility,
    )

    if not pyx_srcs:
        fail("please add .pyx srcs. Empty ones could work.")

    shared_objects = []
    for filename in pyx_srcs:
        stem = remove_file_name_extension(filename)
        cpp_file = stem + ".cpp"
        header_file = stem + ".h"
        dep_file = cpp_file + ".dep"
        cython_annotation = stem + ".html"
        cmd = """
set -o errexit -o pipefail -o noclobber -o nounset

# make sure __init__.pxd exists for every *.pxd file
find -L . \
    -type d \\( -path ./bazel-out \\) -prune \
    -o -name '*.pxd' \
    -execdir touch __init__.pxd \\; \

trap 'echo Error with $(execpath :{filename})' ERR

if [[ -d $(GENDIR)/external ]]; then
    readarray -t gen_external_dirs < <(ls -d $(GENDIR)/external/*)
else
    gen_external_dirs=( )
fi

if [[ -d ./external ]]; then
    readarray -t external_dirs < <(ls -d external/*)
else
    external_dirs=( )
fi

set +u

PYTHONHASHSEED=0 \
$(location @cython//:cython_compile) \
    -X {compiler_directive_joined} \
    -I. -I$(GENDIR) $${{external_dirs[@]/#/-I}} $${{gen_external_dirs[@]/#/-I}} \
    --embed-positions \
    --annotate \
    --depfile \
    --capi-reexport-cincludes \
    --fast-fail \
    --line-directives \
    --cplus $(execpath :{filename}) \
    --module-name '{module_name}' \
    --output-file $(execpath :{cpp_file})
touch $(execpath :{header_file})
""".format(
            compiler_directive_joined = compiler_directive_joined,
            cpp_file = cpp_file,
            header_file = header_file,
            filename = filename,
            pxd_name = _get_pxds_target_name(name),
            module_name = get_py_module_name(make_label(name), filename),
        )
        native.genrule(
            name = filename + ".gen_cpp",
            srcs = [filename, _get_pxds_target_name(name)],
            outs = [cpp_file, header_file, cython_annotation, dep_file],
            cmd = cmd,
            tools = ["@cython//:cython_compile"],
            visibility = ["//visibility:private"],
        )
        shared_object_name = stem + ".so"
        native.cc_binary(
            name = shared_object_name,
            srcs = [cpp_file, header_file],
            deps = cc_deps + ["@rules_python//python/cc:current_py_cc_headers"],
            linkshared = 1,
            local_defines = ["CYTHON_TRACE_NOGIL=%s" % (1 if _ENABLE_PROFILING else 0)],
            visibility = ["//visibility:private"],
        )
        shared_objects.append(shared_object_name)

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
