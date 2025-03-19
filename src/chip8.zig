const std = @import("std");

memory: [4 * 1024]u8,
gfx: Gfx,
pc: u16,
i: u16,
stack: Stack,
delay_timer: u8,
sound_timer: u8,
regs: [16]u16,

pub fn init() @This() {
    return @This(){
        .memory = [_]u8{0} ** 4096,
        .gfx = Gfx.init(),
        .pc = 0,
        .i = 0,
        .stack = Stack.init(),
        .delay_timer = 0,
        .sound_timer = 0,
        .regs = [_]u16{0} ** 16,
    };
}

pub fn initFont(self: *@This()) void {
    @memcpy(self.memory[0x50 .. 0x9F + 1], &[_]u8{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    });
}

pub fn loadROM(self: *@This(), path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    var buffer: [2000]u8 = undefined;
    _ = try file.readAll(&buffer);
    @memcpy(self.memory[512..2512], &buffer);

    self.pc = 512;
}

pub const StepResult = enum {
    ok,
    gfx_changed,
    infinite_loop,
};

pub fn step(self: *@This()) StepResult {
    // fetch
    const shift: u8 = 0x08;
    var op: u16 = @intCast(self.memory[self.pc]);
    op = op << shift;
    op = op | self.memory[self.pc + 1];

    self.pc += 2;

    // decode and execute
    const nibble = (op >> 12) & 0xF;
    const x = (op >> 8) & 0xF;
    const y = (op >> 4) & 0xF;
    const n = op & 0x000F;
    const nn = op & 0x00FF;
    const nnn = op & 0x0FFF;
    var refreshDisplay = false;

    if (nibble == 0 and x == 0 and y == 0xE and n == 0) {
        // clear screen
        self.gfx.clear();
    } else if (nibble == 1) {
        // jump
        self.pc = nnn;
        if (nnn == self.pc) {
            return StepResult.infinite_loop;
        }
    } else if (nibble == 6) {
        // set VX to NN
        self.regs[x] = nn;
    } else if (nibble == 7) {
        // add NN to VX
        self.regs[x] += nn;
    } else if (nibble == 0xA) {
        // set I to NNN
        self.i = nnn;
    } else if (nibble == 0xD) {
        refreshDisplay = true;
        const startX = self.regs[x] & 63;
        const startY = self.regs[y] & 31;

        self.regs[0xF] = 0;

        for (0..n) |i| {
            const curY = @as(u8, @intCast(startY + i));
            const sprite = self.memory[self.i + i];
            for (0..8) |j| {
                const curX = @as(u8, @intCast(startX + j));
                const mask = @as(u8, 1) << @as(u3, @intCast(7 - j));
                const spriteBit = sprite & mask != 0;
                if (spriteBit) {
                    if (self.gfx.get(curX, curY)) {
                        self.regs[0xF] = 1;
                    }
                    self.gfx.toggle(curX, curY);
                }
            }
        }
    } else {
        @panic("illegal instruction");
    }

    if (refreshDisplay) {
        return StepResult.gfx_changed;
    } else {
        return StepResult.ok;
    }
}

pub const Gfx = struct {
    data: [256]u8,

    pub fn init() Gfx {
        return Gfx{
            .data = [_]u8{0} ** 256,
        };
    }

    pub fn clear(self: *Gfx) void {
        self.data = [_]u8{0} ** 256;
    }

    pub fn get(self: *const Gfx, x: u8, y: u8) bool {
        const coord: u11 = @as(u11, x) * 32 + @as(u11, y);
        const subcoord: u3 = @as(u3, @intCast(coord % 8));
        return 0 != (self.data[coord / 8] >> subcoord) & 1;
    }

    pub fn toggle(self: *Gfx, x: u8, y: u8) void {
        const one: u8 = 1;
        const coord: u11 = @as(u11, x) * 32 + @as(u11, y);
        const subcoord: u3 = @as(u3, @intCast(coord % 8));
        self.data[coord / 8] ^= one << subcoord;
    }
};

const Stack = struct {
    entries: [16]u16,
    pointer: u4,

    pub fn init() Stack {
        return Stack{
            .entries = [_]u16{0} ** 16,
            .pointer = 0,
        };
    }

    pub fn push(self: *Stack, item: u16) void {
        self.entries[self.pointer] = item;
        self.pointer = self.pointer + 1;
    }

    pub fn pop(self: *Stack) u16 {
        self.pointer = self.pointer - 1;
        return self.enties[self.pointer];
    }
};
