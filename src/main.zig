const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

// NOTE: see https://github.com/StanislavPetrovV/Python-Tetris/blob/master/main.py

//=======================================
//========= CONSTANTS  ==================
//=======================================
const APP_NAME = "Zigsteroids"; // "All your base are belong to us!"

const TILE_SIZE = 45;
const GRID_SIZE = Vec2(10, 20); // Grid size

const WINDOW_SIZE = Vec2(750, 940); // Window size
const BOARD_SIZE = Vec2(GRID_SIZE.x * TILE_SIZE, GRID_SIZE.y * TILE_SIZE); // Game area size

const WINDOW_POSITION = Vec2(100, 100); // Window position
const FPS = 60; // Frames per second

//=======================================
//========= UTILS   =====================
//=======================================

/// Returns a Raylib.Vector2 object from two f32 x,y values
fn Vec2(x: f32, y: f32) rl.Vector2 {
    return rl.Vector2{ .x = x, .y = y };
}

//=======================================
//========= GAME LOGIC ==================
//=======================================

const Block = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    filled: bool,
    color: rl.Color,

    fn getRect(self: @This()) rl.Rectangle {
        return rl.Rectangle{ .x = self.x, .y = self.y, .width = self.width, .height = self.height };
    }
};

const Game = struct {
    over: bool = false,
    pause: bool = true,
    score: u32 = 0,
    level: u8 = 0,
    grid: std.ArrayList(Block) = undefined,
    field: std.ArrayList(Block) = undefined,
    figures: std.ArrayList([4]Block) = undefined,
    figure: [4]Block = undefined,
    figureNext: [4]Block = undefined,
    frameCounter: u32 = 0,
    speed: u32 = 1,
    allocator: std.mem.Allocator = undefined,
};
var game: Game = Game{};

// Tetromino figures definition
const FIGURES_POS: [7][4]rl.Vector2 = .{
    .{ Vec2(-1, 0), Vec2(-2, 0), Vec2(0, 0), Vec2(1, 0) },
    .{ Vec2(0, -1), Vec2(-1, -1), Vec2(-1, 0), Vec2(0, 0) },
    .{ Vec2(-1, 0), Vec2(-1, 1), Vec2(0, 0), Vec2(0, -1) },
    .{ Vec2(0, 0), Vec2(-1, 0), Vec2(0, 1), Vec2(-1, -1) },
    .{ Vec2(0, 0), Vec2(0, -1), Vec2(0, 1), Vec2(-1, -1) },
    .{ Vec2(0, 0), Vec2(0, -1), Vec2(0, 1), Vec2(1, -1) },
    .{ Vec2(0, 0), Vec2(0, -1), Vec2(0, 1), Vec2(-1, 0) },
};

/// Start or restart the game
fn start() !void {
    // Set game going
    game.over = false;
    game.score = 0;
    game.level = 1;
    // Initialize/clear the game field
    game.field.clearRetainingCapacity();
    // Initialize the grid
    game.grid.clearRetainingCapacity();
    // The grid is a 2D array of rectangles, each one representing a tile
    for (0..GRID_SIZE.x) |x| {
        for (0..GRID_SIZE.y) |y| {
            const block = Block{
                .x = @floatFromInt(x * TILE_SIZE),
                .y = @floatFromInt(y * TILE_SIZE),
                .width = TILE_SIZE,
                .height = TILE_SIZE,
                .filled = false,
                .color = rl.DARKGRAY,
            };
            try game.grid.append(block);
        }
    }
    // Choose a random figure and its next
    // Call it twice to initialize both current and next figures
    try makeFigure();
    try makeFigure();
}

/// The next figure becomes the current figure and a new next figure is randomly chosen
fn makeFigure() !void {
    // Copy the next figure to the current figure
    game.figure = game.figureNext;
    // Choose a new next figure
    var prng = std.rand.Xoshiro256.init(1229948729847);
    const random = prng.random();
    game.figureNext = game.figures.items[random.uintAtMost(usize, game.figures.items.len)];
}

fn rotateFigure() void {
    const center = game.figure[0];
    for (&game.figure) |*rect| {
        const x = rect.x - center.x;
        const y = rect.y - center.y;
        rect.x = center.x - y;
        rect.y = center.y + x;
    }
}

const Direction = enum {
    LEFT,
    RIGHT,
    DOWN,
};

/// Prevent the figure from going out of the board
fn checkBorders(dir: Direction) bool {
    for (&game.figure) |*rect| {
        if (dir == Direction.LEFT) {
            // The figure has reached the left border
            if (rect.x <= 0) {
                return false;
            }
            // The figure has reached the field
            for (game.field.items) |*fieldRect| {
                if (rect.x - TILE_SIZE == fieldRect.x and rect.y == fieldRect.y) {
                    return false;
                }
            }
        } else if (dir == Direction.RIGHT) {
            // The figure has reached the right border
            if (rect.x >= BOARD_SIZE.x - TILE_SIZE) {
                return false;
            }
            // The figure has reached the field
            for (game.field.items) |*fieldRect| {
                if (rect.x + TILE_SIZE == fieldRect.x and rect.y == fieldRect.y) {
                    return false;
                }
            }
        } else if (dir == Direction.DOWN) {
            // The figure has reached the bottom
            if (rect.y >= BOARD_SIZE.y - TILE_SIZE) {
                return false;
            }
            // The figure has reached the field
            for (game.field.items) |*fieldRect| {
                if (rect.x == fieldRect.x and rect.y + TILE_SIZE == fieldRect.y) {
                    return false;
                }
            }
        }
    }
    return true;
}

//=======================================
//========= GAME LOOP  ==================
//=======================================

fn update() !void {
    // Is game over?
    if (game.over) {
        // Press ENTER: Reset the game
        if (rl.IsKeyPressed(rl.KEY_ENTER))
            try start();
        return;
    }

    // Is game paused?
    if (game.pause) {
        // Press ENTER: Un-pause the game
        if (rl.IsKeyPressed(rl.KEY_ENTER))
            game.pause = false;
        // Press R: Reset the game
        if (rl.IsKeyPressed(rl.KEY_R))
            try start();
        return;
    } else {
        // Press ENTER: Pause the game
        if (rl.IsKeyPressed(rl.KEY_ENTER)) {
            game.pause = true;
            return;
        }
    }

    // Move the figure
    if (rl.IsKeyPressed(rl.KEY_LEFT)) {
        if (checkBorders(Direction.LEFT)) {
            for (&game.figure) |*rect| {
                rect.x -= TILE_SIZE;
            }
        }
    }
    if (rl.IsKeyPressed(rl.KEY_RIGHT)) {
        if (checkBorders(Direction.RIGHT)) {
            for (&game.figure) |*rect| {
                rect.x += TILE_SIZE;
            }
        }
    }
    if (rl.IsKeyDown(rl.KEY_DOWN)) {
        if (checkBorders(Direction.DOWN)) {
            for (&game.figure) |*rect| {
                rect.y += TILE_SIZE;
            }
        }
    }

    // Rotate the figure
    if (rl.IsKeyPressed(rl.KEY_UP)) {
        rotateFigure();
    }

    // Move the figure down (gravity)
    game.frameCounter += game.speed;
    if (game.frameCounter >= FPS) {
        game.frameCounter = 0;
        if (checkBorders(Direction.DOWN)) {
            for (&game.figure) |*rect| {
                rect.y += TILE_SIZE;
            }
        } else {
            // The figure has reached the bottom
            for (&game.figure) |*block| {
                // Mark the figure as filled
                block.filled = true;
                // Copy the figure to the game field
                try game.field.append(block.*);
            }
            // Choose a new figure
            try makeFigure();
        }
    }

    // Check every row of the field
    for (0..GRID_SIZE.y) |y| {
        var count: usize = 0;
        // Calculate the y position of the current row to check
        const py = @as(f32, @floatFromInt(y * TILE_SIZE));
        // Count filled blocks at this y position
        for (game.field.items) |*block| {
            if (block.filled and block.y == py) {
                count += 1;
            }
        }
        // If the row is full, remove it
        if (count == GRID_SIZE.x) {
            // Remove the row
            for (0.., game.field.items) |i, *block| {
                if (block.y == py) {
                    _ = game.field.orderedRemove(i);
                }
            }
            // Move down the upper rows
            for (game.field.items) |*block| {
                if (block.y < py) {
                    block.y += TILE_SIZE;
                }
            }
            // Increase the score
            game.score += 10;
        }
    }
}

fn render() !void {
    // Top left: app name
    rl.DrawText(APP_NAME, 10, 10, 20, rl.DARKGRAY);

    // Data strings
    const allocator = std.heap.page_allocator;
    const scoreString = try std.fmt.allocPrint(allocator, "Score: {d}", .{game.score});
    const levelString = try std.fmt.allocPrint(allocator, "Level: {d}", .{game.level});
    defer allocator.free(scoreString);
    defer allocator.free(levelString);

    // Center: game over
    if (game.over) {
        rl.DrawText("Game Over!", WINDOW_SIZE.x / 2 - 100, WINDOW_SIZE.y / 2 - 40, 60, rl.RED);
        rl.DrawText(scoreString.ptr, WINDOW_SIZE.x / 2 - 100, WINDOW_SIZE.y / 2 + 20, 20, rl.DARKGRAY);
        rl.DrawText("Press [ENTER] to restart", WINDOW_SIZE.x / 2 - 150, WINDOW_SIZE.y - 40, 20, rl.DARKGRAY);
        return;
    }

    // Center: pause text (level, score, lives)
    if (game.pause) {
        rl.DrawText(levelString.ptr, WINDOW_SIZE.x / 2 - 100, WINDOW_SIZE.y / 2 - 40, 60, rl.GREEN);
        rl.DrawText(scoreString.ptr, WINDOW_SIZE.x / 2 - 100, WINDOW_SIZE.y / 2 + 20, 20, rl.DARKGRAY);
        rl.DrawText("Press [R] to reset", WINDOW_SIZE.x / 2 - 150, WINDOW_SIZE.y - 60, 20, rl.DARKGRAY);
        rl.DrawText("Press [ENTER] to start", WINDOW_SIZE.x / 2 - 150, WINDOW_SIZE.y - 40, 20, rl.DARKGRAY);
        return;
    }

    // Top right: score
    rl.DrawText(scoreString.ptr, WINDOW_SIZE.x - 150, 40, 20, rl.DARKGRAY);

    // Draw grid
    for (game.grid.items) |block| {
        rl.DrawRectangleLinesEx(block.getRect(), 1, block.color);
    }

    // Draw field
    for (game.field.items) |block| {
        rl.DrawRectangleRec(block.getRect(), rl.GRAY);
        rl.DrawRectangleLinesEx(block.getRect(), 1, rl.DARKGRAY);
    }

    // Draw current figure
    for (game.figure) |block| {
        rl.DrawRectangleRec(block.getRect(), block.color);
        rl.DrawRectangleLinesEx(block.getRect(), 1, rl.YELLOW);
    }
}

pub fn main() !void {
    // Allocate memory for the game
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    game.allocator = gpa.allocator();

    game.grid = std.ArrayList(Block).init(game.allocator);
    defer game.grid.deinit();

    game.field = std.ArrayList(Block).init(game.allocator);
    defer game.field.deinit();

    game.figures = std.ArrayList([4]Block).init(game.allocator);
    defer game.figures.deinit();

    // Initialize figures
    inline for (FIGURES_POS) |posList| {
        var blocks: [4]Block = undefined;
        for (0.., posList) |j, pos| {
            blocks[j] = Block{
                .x = @divTrunc(pos.x + GRID_SIZE.x, 2) * TILE_SIZE,
                .y = @as(f32, pos.y + 1) * TILE_SIZE,
                .width = TILE_SIZE,
                .height = TILE_SIZE,
                .filled = true,
                .color = rl.RED,
            };
        }
        try game.figures.append(blocks);
    }

    // Initialize raylib
    rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, APP_NAME);
    defer rl.CloseWindow();
    rl.SetWindowPosition(WINDOW_POSITION.y, WINDOW_POSITION.y);
    rl.SetTargetFPS(FPS);

    try start();

    // Raylib main loop
    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.BLACK);

        try update();
        try render();
    }
}
