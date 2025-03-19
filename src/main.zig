const std = @import("std");
const rl = @import("raylib");
const Chip8 = @import("chip8.zig");
const Renderer = @import("renderer.zig");

pub fn main() !void {
    const scale = 10; // multiplier to scale CHIP-8 display
    const gap = 1; // gap between cells
    const foregroundColor = rl.Color.fromHSV(126, 0.69, 0.90);
    const backgroundColor = rl.Color.fromHSV(225, 0.07, 0.07);

    const renderer = Renderer.init(scale, gap, foregroundColor, backgroundColor);
    defer Renderer.close();

    var c8 = Chip8.init();
    c8.initFont();
    try c8.loadROM("./IBM Logo.ch8");

    loop: while (!Renderer.shouldClose()) {
        const res = c8.step();

        switch (res) {
            .ok => {},
            .gfx_changed => {
                renderer.invalidate(c8.gfx);
            },
            .infinite_loop => {
                break :loop;
            },
        }

        const op_per_s = 700;
        std.time.sleep(std.time.ns_per_s / op_per_s);
    }

    Renderer.halt();
}
