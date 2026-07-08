load("@com_google_protobuf//bazel/common:proto_common.bzl", "proto_common")
load("@com_google_protobuf//bazel/common:proto_info.bzl", "ProtoInfo")

def _buf_gen_impl(ctx):
    buf_toolchain = ctx.toolchains["//:buf_toolchain_type"]

    protoc_gen_go = ctx.executable.protoc_gen_go

    args = ctx.actions.args()
    args.add("generate")
    args.add(ctx.file.template, format = "--template=%s")

    inputs = [ctx.file.template]
    outputs = []
    for dep in ctx.attr.deps:
        outputs.extend(
            proto_common.declare_generated_files(
                actions = ctx.actions,
                proto_info = dep[ProtoInfo],
                extension = ".pb.go",
            ),
        )
        inputs.extend(dep[ProtoInfo].direct_sources)
        args.add_all(dep[ProtoInfo].direct_sources, format_each = "--path=%s")

    args.add(ctx.bin_dir.path, format = "--output=%s")

    # The `plugin: go` entry in buf.gen.yaml makes buf exec a local
    # `protoc-gen-go` found on PATH. Point PATH at the hermetic protoc-gen-go we
    # build from the Go module, so buf never fetches a remote plugin from the
    # Buf Schema Registry. Remote plugins are non-hermetic and get rate-limited
    # ("too many requests") on RBE where many actions share an egress IP.
    ctx.actions.run(
        executable = buf_toolchain.buf_info.binary,
        inputs = inputs,
        tools = [protoc_gen_go],
        env = {"PATH": protoc_gen_go.dirname},
        arguments = [args],
        outputs = outputs,
    )

    return DefaultInfo(files = depset(outputs))

buf_go_proto_library = rule(
    implementation = _buf_gen_impl,
    attrs = {
        "deps": attr.label_list(),
        "template": attr.label(mandatory = True, allow_single_file = True),
        "protoc_gen_go": attr.label(
            doc = "Local protoc-gen-go plugin binary buf invokes for `plugin: go`. " +
                  "Keeps code generation hermetic instead of pulling a remote BSR plugin.",
            default = "@org_golang_google_protobuf//cmd/protoc-gen-go",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = ["//:buf_toolchain_type"],
)
