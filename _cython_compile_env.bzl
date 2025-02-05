def _cython_compile_env_impl(ctx):
    includes = depset(
        [f.root.path for f in ctx.files.pxd_srcs],
        transitive = [dep[CythonCompileInfo].includes for dep in ctx.attr.cython_deps],
    )
    pxd_files = depset(
        ctx.files.pxd_srcs,
        transitive = [dep[CythonCompileInfo].pxd_files for dep in ctx.attr.cython_deps],
    )
    if len(ctx.files.pxd_srcs) > 0 and all([f.basename != "__init__.pxd" for f in ctx.files.pxd_srcs]):
        init_pxd = ctx.actions.declare_file("__init__.pxd", sibling = ctx.files.pxd_srcs[0])
        ctx.actions.run(
            executable = "touch",
            arguments = [init_pxd.path],
            outputs = [init_pxd],
        )
        pxd_files = depset([init_pxd] + ctx.files.pxd_srcs, transitive = [pxd_files])

    return CythonCompileInfo(
        pxd_files = pxd_files,
        includes = includes,
    )

CythonCompileInfo = provider(
    fields = ["pxd_files", "includes"],
)

cython_compile_env = rule(
    doc = "Collect pxd files and cython dependencies that are reused for multiple cython compilation.",
    implementation = _cython_compile_env_impl,
    attrs = {
        "pxd_srcs": attr.label_list(
            allow_files = True,
            providers = ["files"],
        ),
        "cython_deps": attr.label_list(
            allow_files = True,
            providers = [CythonCompileInfo],
        ),
    },
)
