"""Bzlmod module extension that materialises the buf toolchain repos."""

load("//:repositories.bzl", "PLATFORMS", "buf_repositories", "toolchains_repo")

def _buf_impl(module_ctx):
    # Only the root module is allowed to choose the buf version. This matches
    # the WORKSPACE-era `buf_register_toolchains` macro behaviour.
    version = None
    for mod in module_ctx.modules:
        for tc in mod.tags.toolchain:
            if not mod.is_root:
                fail("only the root module may set buf.toolchain(version = ...)")
            version = tc.version

    if version == None:
        fail("buf.toolchain(version = ...) must be called by the root module")

    for platform in PLATFORMS.keys():
        buf_repositories(
            name = "buf_{platform}".format(platform = platform),
            platform = platform,
            buf_version = version,
        )

    toolchains_repo(
        name = "buf_toolchains",
        toolchain_type = "@bufbuild//:buf_toolchain_type",
        # {platform} is filled in inside toolchains_repo for each platform.
        toolchain = "@buf_{platform}//:buf_toolchain",
    )

buf = module_extension(
    implementation = _buf_impl,
    tag_classes = {
        "toolchain": tag_class(attrs = {
            "version": attr.string(mandatory = True),
        }),
    },
)
