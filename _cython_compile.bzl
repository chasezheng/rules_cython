load("//:_common.bzl", "get_py_module_name", "make_label", "remove_file_name_extension")
load("//:_cython_compile_env.bzl", "CythonCompileInfo")

def _cython_compile_impl(ctx):
    compiler_directive_joined = ",".join([
        "%s=%s" % (k, v)
        for k, v in ctx.attr.compiler_directives.items()
    ])
    stem = remove_file_name_extension(ctx.file.pyx.basename)
    output_cpp = ctx.actions.declare_file(stem + ".cpp", sibling = ctx.file.pyx)
    output_header = ctx.actions.declare_file(stem + ".h", sibling = ctx.file.pyx)
    output_depfile = ctx.actions.declare_file(output_cpp.basename + ".dep", sibling = ctx.file.pyx)
    output_annotation = ctx.actions.declare_file(stem + ".html", sibling = ctx.file.pyx)

    args = ctx.actions.args()
    args.add_all([
        "--embed-positions",
        "--annotate",
        "--depfile",
        "--capi-reexport-cincludes",
        "--fast-fail",
        "--line-directives",
    ])
    if compiler_directive_joined:
        args.add("-X", compiler_directive_joined)
    args.add("-I.")
    args.add_all("-I", ctx.attr.compile_env[CythonCompileInfo].includes)
    args.add("--cplus", ctx.file.pyx)
    args.add("--module-name", get_py_module_name(ctx.label, ctx.file.pyx.basename))
    args.add("--output", output_cpp)
    ctx.actions.run(
        outputs = [
            output_cpp,
            output_depfile,
            output_annotation,
        ],
        executable = ctx.attr._compiler.files_to_run,
        env = {"PYTHONHASHSEED": "0"},
        arguments = [args],
        inputs = depset([ctx.file.pyx], transitive = [ctx.attr.compile_env[CythonCompileInfo].pxd_files]),
    )
    ctx.actions.run(
        outputs = [output_header],
        arguments = [output_header.path],
        executable = "touch",
    )
    return [
        DefaultInfo(files = depset([output_header, output_cpp])),
        OutputGroupInfo(debug_files = [output_annotation, output_depfile]),
    ]

cython_compile = rule(
    doc = "Compile the pyx file into C++ source file.",
    implementation = _cython_compile_impl,
    attrs = {
        "compiler_directives": attr.string_dict(
            default = {},
        ),
        "pyx": attr.label(
            mandatory = True,
            allow_single_file = True,
            providers = ["file"],
        ),
        "compile_env": attr.label(
            mandatory = True,
            providers = [CythonCompileInfo],
        ),
        "_compiler": attr.label(default = "@cython//:compiler"),
    },
)
