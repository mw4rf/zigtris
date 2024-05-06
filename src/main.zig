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
const GRID_SIZE = Coord{ .x = 10, .y = 20}; // Grid size

const WINDOW_SIZE = Vec2(750, 940); // Window size
const OFFSET = Vec2(20, 20); // Offset from the window border

const WINDOW_POSITION = Vec2(100, 100); // Window position
const FPS = 60; // Frames per second

const BASE_SPEED = 1.0; // Speed of the game
const SCORE_INCREASE_PER_LINE = 100; // Score increase per line
const SCORE_NEXT_LEVEL :u32 = 1000; // Score to reach the next level
const LEVEL_SPEED_MULTIPLIER = 0.8; // Speed multiplier for each level

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

const BlockState = enum {
    EMPTY,  // Empty block of the grid
    FIGURE, // Block of the current figure
    GROUND, // Block of the ground
    REMOVE, // Block of a line to be removed
};

const Coord = struct {
    x: usize,
    y: usize,
};

const Block = struct {
    coord: Coord,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    state: BlockState,
    color: rl.Color,

    fn getRect(self: @This()) rl.Rectangle {
        return rl.Rectangle{ .x = self.x + OFFSET.x, .y = self.y + OFFSET.y, .width = self.width, .height = self.height };
    }
};

const Game = struct {
    over: bool = false,
    pause: bool = true,
    score: u32 = 0,
    level: u8 = 0,
    grid: [GRID_SIZE.x][GRID_SIZE.y]Block = undefined,
    figures: std.ArrayList([4]Block) = undefined,
    figure: [4]Block = undefined,
    figureNext: [4]Block = undefined,
    frameCounter: f32 = 0,
    speed: f32 = BASE_SPEED,
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
    game.speed = BASE_SPEED;
    // Initialize the grid
    // The grid is a 2D array of rectangles, each one representing a tile
    for (0..GRID_SIZE.x) |x| {
        for (0..GRID_SIZE.y) |y| {
            game.grid[x][y] = Block{
                .coord = Coord{ .x = x, .y = y },
                .x = @floatFromInt(x * TILE_SIZE),
                .y = @floatFromInt(y * TILE_SIZE),
                .width = TILE_SIZE,
                .height = TILE_SIZE,
                .color = rl.DARKGRAY,
                .state = BlockState.EMPTY,
            };
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
    var prng = std.rand.Xoshiro256.init(@as(u64, @intCast(std.time.milliTimestamp())));
    const random = prng.random();
    game.figureNext = game.figures.items[random.uintLessThan(usize, game.figures.items.len)];
}

fn rotateFigure() void {
    // We need a small hack here to prevent the rotation from going out of the grid
    // because the grid is a 2D array and we can't have indexes out of bounds

    // Copy the figure to a temporary array
    var tmpFigure: [4]Block = undefined;
    for (0..4) |i| {
        tmpFigure[i] = game.figure[i];
    }

    // Rotate the temporary figure
    const center = game.figure[0];
    for (&tmpFigure) |*rect| {
        // Rotation involve negative values, but coordinates are unsigned
        // so we need to convert them to signed integers
        const tmpX: isize = @intCast(rect.coord.x);
        const tmpY: isize = @intCast(rect.coord.y);
        const tmpCX: isize = @intCast(center.coord.x);
        const tmpCY: isize = @intCast(center.coord.y);
        // Now the logic
        const lX = tmpX - tmpCX;
        const lY = tmpY - tmpCY;
        const x = tmpCX - lY;
        const y = tmpCY + lX;
        // Convert back to unsigned integers
        rect.coord.x = @abs(x);
        rect.coord.y = @abs(y);
    }

    // Check if the temporary figure is inside the grid
    // If the rotation is illegal, return before applying it to the current figure
    for (tmpFigure) |rect| {
        if (rect.coord.x >= GRID_SIZE.x or rect.coord.y >= GRID_SIZE.y) {
            return;
        }
    }

    // Copy the temporary figure back to the current figure
    game.figure = tmpFigure;
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
            if (rect.coord.x == 0) {
                return false;
            }
            // The figure is blocked by another block
            if (game.grid[rect.coord.x - 1][rect.coord.y].state == BlockState.GROUND) {
                return false;
            }
        } else if (dir == Direction.RIGHT) {
            // The figure has reached the right border
            if (rect.coord.x >= GRID_SIZE.x - 1) {
                return false;
            }
            // The figure is blocked by another block
            if (game.grid[rect.coord.x + 1][rect.coord.y].state == BlockState.GROUND) {
                return false;
            }
        } else if (dir == Direction.DOWN) {
            // The figure has reached the bottom
            if (rect.coord.y >= GRID_SIZE.y - 1) {
                return false;
            }
            // The figure is blocked by another block (the ground)
            switch (game.grid[rect.coord.x][rect.coord.y + 1].state) {
                .GROUND => return false,
                .REMOVE => return false,
                else => {},
            }
        }
    }
    return true;
}

/// Returns the y index or the first full line found from the bottom
/// or a NoLine error if no full line is found
fn getNextLine() error{NoLine}!usize {
    for (0..GRID_SIZE.y) |y| {
        var full = true;
        for (0..GRID_SIZE.x) |x| {
            if (game.grid[x][y].state != BlockState.GROUND) {
                full = false;
                break;
            }
        }
        if (full) {
            return y;
        }
    }
    return error.NoLine;
}

/// Remove the line at the given index
fn removeLine(index: usize) void {
    // Mark blocks as empty
    for (0..GRID_SIZE.x) |x| {
        game.grid[x][index].state = BlockState.EMPTY;
    }
    // Move down the blocks above the removed line
    // until they reach a non-empty block
    for (0..index) |y| {
        for (0..GRID_SIZE.x) |x| {
            if (game.grid[x][y].state == BlockState.GROUND) {
                game.grid[x][y].state = BlockState.EMPTY;
                game.grid[x][y + 1].state = BlockState.GROUND;
            }
        }
    }
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
                rect.coord.x -= 1;
            }
        }
    }
    if (rl.IsKeyPressed(rl.KEY_RIGHT)) {
        if (checkBorders(Direction.RIGHT)) {
            for (&game.figure) |*rect| {
                rect.coord.x += 1;
            }
        }
    }
    if (rl.IsKeyDown(rl.KEY_DOWN)) {
        if (checkBorders(Direction.DOWN)) {
            for (&game.figure) |*rect| {
                rect.coord.y += 1;
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
                rect.coord.y += 1;
            }
        } else {
            // The figure has reached the bottom
            for (&game.figure) |*block| {
                block.state = BlockState.GROUND;
                game.grid[block.coord.x][block.coord.y] = block.*;
            }
            // Choose a new figure
            try makeFigure();
        }
    }

    // Remove full lines
    var score: u32 = 0;
    while (true) {
        const result = getNextLine() catch break;
        removeLine(result);
        score += SCORE_INCREASE_PER_LINE;
    }

    game.score += score;

    // Increase the level
    if (game.score >= SCORE_NEXT_LEVEL * game.level) {
        game.level += 1;
        game.speed = BASE_SPEED * @as(f32, @floatFromInt(game.level)) * LEVEL_SPEED_MULTIPLIER;
    }

}

fn render() !void {
    // Top left: app name
    rl.DrawText(APP_NAME, 10, 10, 20, rl.DARKGRAY);

    // Data strings
    const allocator = std.heap.page_allocator;
    const scoreString = try std.fmt.allocPrint(allocator, "Score:\n\n {d}", .{game.score});
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

    // Level and score
    rl.DrawText(levelString.ptr, WINDOW_SIZE.x - 220, 10, 30, rl.DARKGRAY);
    rl.DrawText(scoreString.ptr, WINDOW_SIZE.x - 220, 50, 30, rl.DARKGRAY);

    // Draw grid
    for (0..GRID_SIZE.x) |x| {
        for (0..GRID_SIZE.y) |y| {
            const block = &game.grid[x][y];
            switch (block.state) {
                .EMPTY => {
                    rl.DrawRectangleLinesEx(block.getRect(), 1, rl.DARKGRAY);
                },
                .GROUND => {
                    rl.DrawRectangleRec(block.getRect(), rl.GRAY);
                    rl.DrawRectangleLinesEx(block.getRect(), 1, rl.DARKGRAY);
                },
                .REMOVE => {
                    rl.DrawRectangleRec(block.getRect(), rl.GREEN);
                },
                else => {}, // current figure drawn later
            }
        }
    }

    // Draw current figure
    for (&game.figure) |*block| {
        // Compute the next figure position, given its coordinates in the grid
        block.x = @floatFromInt(block.coord.x * TILE_SIZE);
        block.y = @floatFromInt(block.coord.y * TILE_SIZE);
        // Draw
        rl.DrawRectangleRec(block.getRect(), block.color);
        rl.DrawRectangleLinesEx(block.getRect(), 1, rl.YELLOW);
    }

    // Draw next figure
    rl.DrawText("Next figure:", WINDOW_SIZE.x - 220, 150, 30, rl.DARKGRAY);
    for (&game.figureNext) |*block| {
        // Compute the next figure position, given its coordinates in the grid
        block.x = @floatFromInt(block.coord.x * TILE_SIZE);
        block.y = @floatFromInt(block.coord.y * TILE_SIZE);
        // Add offset
        block.x += 350.0;
        block.y += 200.0;
        // Draw
        rl.DrawRectangleRec(block.getRect(), rl.GRAY);
        rl.DrawRectangleLinesEx(block.getRect(), 1, rl.DARKGRAY);
    }

}

pub fn main() !void {
    // Allocate memory for the game
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    game.allocator = gpa.allocator();

    game.figures = std.ArrayList([4]Block).init(game.allocator);
    defer game.figures.deinit();

    // Initialize figures
    inline for (FIGURES_POS) |posList| {
        var blocks: [4]Block = undefined;
        for (0.., posList) |j, pos| {
            blocks[j] = Block{
                .coord = Coord{
                    .x = @intFromFloat(@divTrunc(pos.x + GRID_SIZE.x, 2)),
                    .y = @intFromFloat(pos.y + 1),
                },
                .x = @divTrunc(pos.x + GRID_SIZE.x, 2) * TILE_SIZE,
                .y = @as(f32, pos.y + 1) * TILE_SIZE,
                .width = TILE_SIZE,
                .height = TILE_SIZE,
                .color = rl.RED,
                .state = BlockState.FIGURE,
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
