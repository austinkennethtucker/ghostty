//! GhosttyFrameData generates compressed files and zig modules which contain (and expose) the
//! animation frames for use in `ghostty +boo` and `ghostty +trident`
const GhosttyFrameData = @This();

const std = @import("std");
const DistResource = @import("GhosttyDist.zig").Resource;

/// The output path for the compressed framedata zig file (ghost/boo)
output: std.Build.LazyPath,
/// The output path for the compressed trident framedata zig file
trident_output: std.Build.LazyPath,

pub fn init(b: *std.Build) !GhosttyFrameData {
    const dist = distResources(b);

    // Generate the Zig source file that embeds the ghost compressed data
    const wf = b.addWriteFiles();
    _ = wf.addCopyFile(dist.framedata.path(b), "framedata.compressed");
    const zig_file = wf.add("framedata.zig",
        \\//! This file is auto-generated. Do not edit.
        \\
        \\pub const compressed = @embedFile("framedata.compressed");
        \\
    );

    // Generate the Zig source file that embeds the trident compressed data
    const twf = b.addWriteFiles();
    _ = twf.addCopyFile(dist.trident_framedata.path(b), "trident_framedata.compressed");
    const trident_zig_file = twf.add("trident_framedata.zig",
        \\//! This file is auto-generated. Do not edit.
        \\
        \\pub const compressed = @embedFile("trident_framedata.compressed");
        \\
    );

    return .{ .output = zig_file, .trident_output = trident_zig_file };
}

/// Add the "framedata" and "trident_framedata" imports.
pub fn addImport(self: *const GhosttyFrameData, step: *std.Build.Step.Compile) void {
    self.output.addStepDependencies(&step.step);
    step.root_module.addAnonymousImport("framedata", .{
        .root_source_file = self.output,
    });
    self.trident_output.addStepDependencies(&step.step);
    step.root_module.addAnonymousImport("trident_framedata", .{
        .root_source_file = self.trident_output,
    });
}

/// Creates the framedata resources that can be prebuilt for our dist build.
pub fn distResources(b: *std.Build) struct {
    framedata: DistResource,
    trident_framedata: DistResource,
} {
    const exe = b.addExecutable(.{
        .name = "framegen",
        .root_module = b.createModule(.{
            .target = b.graph.host,
        }),
    });
    exe.addCSourceFile(.{
        .file = b.path("src/build/framegen/main.c"),
        .flags = &.{},
    });
    exe.linkLibC();

    if (b.systemIntegrationOption("zlib", .{})) {
        exe.linkSystemLibrary2("zlib", .{
            .preferred_link_mode = .dynamic,
            .search_strategy = .mode_first,
        });
    } else {
        if (b.lazyDependency("zlib", .{
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        })) |zlib_dep| {
            exe.linkLibrary(zlib_dep.artifact("z"));
        }
    }

    // Ghost frames (boo)
    const run = b.addRunArtifact(exe);
    run.addDirectoryArg(b.path("src/build/framegen/frames"));
    const compressed_file = run.addOutputFileArg("framedata.compressed");

    // Trident frames
    const trident_run = b.addRunArtifact(exe);
    trident_run.addDirectoryArg(b.path("src/build/framegen/trident_frames"));
    const trident_compressed_file = trident_run.addOutputFileArg("trident_framedata.compressed");

    return .{
        .framedata = .{
            .dist = "src/build/framegen/framedata.compressed",
            .generated = compressed_file,
        },
        .trident_framedata = .{
            .dist = "src/build/framegen/trident_framedata.compressed",
            .generated = trident_compressed_file,
        },
    };
}
