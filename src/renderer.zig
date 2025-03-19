const std = @import("std");
const rl = @import("raylib");
const Chip8 = @import("chip8.zig");

foreground: rl.Color,
background: rl.Color,
scale: i32,
gap: i32,

pub fn init(
    scale: i32,
    gap: i32,
    foreground: rl.Color,
    background: rl.Color,
) @This() {
    const renderer = @This(){
        .foreground = foreground,
        .background = background,
        .scale = scale,
        .gap = gap,
    };

    const screenWidth = (scale + gap) * 64;
    const screenHeight = (scale + gap) * 32;
    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    rl.setTargetFPS(60);

    return renderer;
}

pub fn shouldClose() bool {
    return rl.windowShouldClose();
}

pub fn halt() void {
    while (!@This().shouldClose()) {
        rl.waitTime(0.1);
        rl.pollInputEvents();
    }
}

pub fn close() void {
    defer rl.closeWindow();
}

pub fn invalidate(self: @This(), gfx: Chip8.Gfx) void {
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(self.background);
    for (0..64) |xCoord| {
        for (0..32) |yCoord| {
            if (gfx.get(@as(u8, @intCast(xCoord)), @as(u8, @intCast(yCoord)))) {
                rl.drawRectangle(
                    @as(i32, @intCast(xCoord)) * (self.scale + self.gap),
                    @as(i32, @intCast(yCoord)) * (self.scale + self.gap),
                    self.scale,
                    self.scale,
                    self.foreground,
                );
            }
        }
    }
}
