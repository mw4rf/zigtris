const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

// TODO: save high score

//=======================================
//========= CONSTANTS  ==================
//=======================================
const APP_NAME = "ZigTris"; // "All your base are belong to us!"

const TILE_SIZE = 45;
const GRID_SIZE = Coord{ .x = 10, .y = 20}; // Grid size

const WINDOW_SIZE = Vec2(750, 940); // Window size
const OFFSET = Vec2(20, 20); // Offset from the window border

const WINDOW_POSITION = Vec2(100, 100); // Window position
const FPS = 60; // Frames per second

const BASE_SPEED = 1.0; // Speed of the game
const SCORE_INCREASE_PER_LINE = 80; // Score increase per line
const SCORE_NEXT_LEVEL :u32 = 1000; // Score to reach the next level
const LEVEL_SPEED_MULTIPLIER = 0.3; // Speed multiplier for each level
const LEVEL_SCORE_MULTIPLIER = 1.1; // Score multiplier for each level

const NEUTRAL_LINE_COLOR = false; // Use a neutral color for the lines instead of the figure color
const NIGHT_MODE = true;

//=======================================
//========= COLORS  =====================
//=======================================

const MOCHA_ROSEWATER = .{ .r = 245, .g = 224, .b = 220, .a = 255 };
const MOCHA_FLAMINGO = .{ .r = 242, .g = 205, .b = 205, .a = 255 };
const MOCHA_PINK = .{ .r = 245, .g = 194, .b = 231, .a = 255 };
const MOCHA_MAUVE = .{ .r = 203, .g = 166, .b = 247, .a = 255 };
const MOCHA_RED = .{ .r = 243, .g = 139, .b = 168, .a = 255 };
const MOCHA_MAROON = .{ .r = 235, .g = 160, .b = 172, .a = 255 };
const MOCHA_PEACH = .{ .r = 250, .g = 179, .b = 135, .a = 255 };
const MOCHA_YELLOW = .{ .r = 249, .g = 226, .b = 175, .a = 255 };
const MOCHA_GREEN = .{ .r = 166, .g = 227, .b = 161, .a = 255 };
const MOCHA_TEAL = .{ .r = 148, .g = 226, .b = 213, .a = 255 };
const MOCHA_SKY = .{ .r = 137, .g = 220, .b = 235, .a = 255 };
const MOCHA_SAPPHIRE = .{ .r = 116, .g = 199, .b = 236, .a = 255 };
const MOCHA_BLUE = .{ .r = 137, .g = 180, .b = 250, .a = 255 };
const MOCHA_LAVENDER = .{ .r = 180, .g = 190, .b = 254, .a = 255 };

const LATTE_ROSEWATER = .{ .r = 220, .g = 138, .b = 120, .a = 255 };
const LATTE_FLAMINGO = .{ .r = 221, .g = 120, .b = 120, .a = 255 };
const LATTE_PINK = .{ .r = 234, .g = 118, .b = 203, .a = 255 };
const LATTE_MAUVE = .{ .r = 136, .g = 57, .b = 239, .a = 255 };
const LATTE_RED = .{ .r = 210, .g = 15, .b = 57, .a = 255 };
const LATTE_MAROON = .{ .r = 230, .g = 69, .b = 83, .a = 255 };
const LATTE_PEACH = .{ .r = 254, .g = 100, .b = 11, .a = 255 };
const LATTE_YELLOW = .{ .r = 223, .g = 142, .b = 29, .a = 255 };
const LATTE_GREEN = .{ .r = 64, .g = 160, .b = 43, .a = 255 };
const LATTE_TEAL = .{ .r = 23, .g = 146, .b = 153, .a = 255 };
const LATTE_SKY = .{ .r = 4, .g = 165, .b = 229, .a = 255 };
const LATTE_SAPPHIRE = .{ .r = 32, .g = 159, .b = 181, .a = 255 };
const LATTE_BLUE = .{ .r = 30, .g = 102, .b = 245, .a = 255 };
const LATTE_LAVENDER = .{ .r = 114, .g = 135, .b = 253, .a = 255 };

const FIGURE_COLORS: [14]rl.Color =
    if (NIGHT_MODE) .{
        MOCHA_ROSEWATER, MOCHA_FLAMINGO, MOCHA_PINK, MOCHA_MAUVE, MOCHA_RED, MOCHA_MAROON, MOCHA_PEACH, MOCHA_YELLOW, MOCHA_GREEN, MOCHA_TEAL, MOCHA_SKY, MOCHA_SAPPHIRE, MOCHA_BLUE, MOCHA_LAVENDER
    } else .{
        LATTE_ROSEWATER, LATTE_FLAMINGO, LATTE_PINK, LATTE_MAUVE, LATTE_RED, LATTE_MAROON, LATTE_PEACH, LATTE_YELLOW, LATTE_GREEN, LATTE_TEAL, LATTE_SKY, LATTE_SAPPHIRE, LATTE_BLUE, LATTE_LAVENDER
};


const BACKGROUND_COLOR = if (NIGHT_MODE) rl.BLACK else rl.LIGHTGRAY;
const GRID_COLOR = if (NIGHT_MODE) rl.DARKGRAY else rl.GRAY;
const LINE_COLOR = if (NIGHT_MODE) rl.GRAY else rl.DARKGRAY;
const TEXT_COLOR = if (NIGHT_MODE) rl.GRAY else rl.DARKGRAY;

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
    sound: bool = true,
    music: rl.Music = undefined,
    over: bool = false,
    pause: bool = true,
    score: u32 = 0,
    level: u8 = 0,
    grid: [GRID_SIZE.x][GRID_SIZE.y]Block = undefined,
    figures: std.ArrayList([4]Block) = undefined,
    figure: [4]Block = undefined,
    figureNext: [4]Block = undefined,
    figureHadLanded: bool = false,
    frameCounter: f32 = 0,
    speed: f32 = BASE_SPEED,
    allocator: std.mem.Allocator = undefined,
};
var game: Game = Game{};

// Tetromino figures definition
const FIGURES_POS: [7][4]Coord = .{
    .{ Coord{.x = 3, .y = 5}, Coord{.x = 2, .y = 5}, Coord{.x = 4, .y = 5}, Coord{.x = 5, .y = 5} }, // I-Tetromino
    .{ Coord{.x = 3, .y = 5}, Coord{.x = 2, .y = 4}, Coord{.x = 2, .y = 5}, Coord{.x = 3, .y = 4} }, // S-Tetromino
    .{ Coord{.x = 2, .y = 5}, Coord{.x = 2, .y = 6}, Coord{.x = 3, .y = 5}, Coord{.x = 3, .y = 4} }, // Z-Tetromino
    .{ Coord{.x = 3, .y = 5}, Coord{.x = 2, .y = 5}, Coord{.x = 3, .y = 6}, Coord{.x = 2, .y = 4} }, // T-Tetromino
    .{ Coord{.x = 3, .y = 5}, Coord{.x = 3, .y = 4}, Coord{.x = 3, .y = 6}, Coord{.x = 2, .y = 4} }, // L-Tetromino
    .{ Coord{.x = 3, .y = 5}, Coord{.x = 3, .y = 4}, Coord{.x = 3, .y = 6}, Coord{.x = 4, .y = 4} }, // J-Tetromino
    .{ Coord{.x = 3, .y = 5}, Coord{.x = 3, .y = 4}, Coord{.x = 3, .y = 6}, Coord{.x = 2, .y = 5} }, // O-Tetromino
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
                .color = GRID_COLOR,
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
    const ri = random.uintLessThan(usize, game.figures.items.len);
    game.figureNext = game.figures.items[ri];
    // Set the new figure color
    const color = FIGURE_COLORS[random.uintLessThan(usize, FIGURE_COLORS.len)];
    for (&game.figureNext) |*block| {
        block.color = color;
    }
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

        // Compute local coordinates relative to the center
        const lX: isize = @as(isize, @intCast(rect.coord.x)) - @as(isize, @intCast(center.coord.x));
        const lY: isize = @as(isize, @intCast(rect.coord.y)) - @as(isize, @intCast(center.coord.y));
        // Perform rotation: (x, y) -> (-y, x)
        const newX: isize = -lY + @as(isize, @intCast(center.coord.x));
        const newY: isize = lX + @as(isize, @intCast(center.coord.y));
        // Ensure new coordinates are within grid bounds
        if (newX < 0 or newX >= @as(isize, @intCast(GRID_SIZE.x)) or newY < 0 or newY >= @as(isize, @intCast(GRID_SIZE.y))) {
            return; // Rotation would move part of the figure out of bounds, do not apply
        }
        rect.coord.x = @as(usize, @intCast(newX));
        rect.coord.y = @as(usize, @intCast(newY));
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
            // The figure is blocked by another block
            if (game.grid[rect.coord.x][rect.coord.y + 1].state == BlockState.GROUND) {
                return false;
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
    var y = index;
    while (y > 0) : (y -= 1) {
        for (0..GRID_SIZE.x) |x| {
            game.grid[x][y].state = game.grid[x][y - 1].state;
        }
    }
}

/// Save the high score to a file
fn saveHighScore() !void {
    var file = try std.fs.cwd().createFile("highscore.txt", .{ .read = true, .truncate = false });
    defer file.close();

    const stat = try file.stat();
    const buffer = try file.readToEndAlloc(game.allocator, stat.size);
    defer game.allocator.free(buffer);
    const trimmedBuffer = std.mem.trimRight(u8, buffer, "\r\n");

    const highScore = std.fmt.parseUnsigned(u32, trimmedBuffer, 10) catch 0;

    if (game.score > highScore) {
        var buf :[4]u8 = undefined;
        const score = try std.fmt.bufPrint(&buf, "{d}", .{game.score});
        try file.seekTo(0); // overwrite
        _ = try file.write(score);
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

    // Music
    if (rl.IsKeyPressed(rl.KEY_S)) {
        game.sound = !game.sound;
        if (!game.sound) {
            rl.PauseMusicStream(game.music);
        } else {
            rl.ResumeMusicStream(game.music);
        }
    }

    // Check if the figure has landed
    if (!checkBorders(Direction.DOWN)) {
        for (&game.figure) |*block| {
            block.state = BlockState.GROUND;
            game.grid[block.coord.x][block.coord.y] = block.*;
        }
        game.figureHadLanded = true;
    }

    // The figure has landed
    if (game.figureHadLanded) {

        // Remove full lines
        var nLines: u8 = 0;
        var score: u32 = 0;
        while (true) {
            const result = getNextLine() catch break;
            removeLine(result);
            nLines += 1;
        }

        // Update the score
        const roundedScore = @round(SCORE_INCREASE_PER_LINE * @as(f32, @floatFromInt(nLines)) * LEVEL_SCORE_MULTIPLIER * @as(f32, @floatFromInt(game.level)));
        score += @as(u32, @intFromFloat(roundedScore));
        game.score += score;

        // Increase the level
        if (game.score >= SCORE_NEXT_LEVEL * game.level) {
            game.level += 1;
            game.speed = BASE_SPEED * @as(f32, @floatFromInt(game.level)) * LEVEL_SPEED_MULTIPLIER;
        }

        // Game over logic
        for (0..GRID_SIZE.x) |x| {
            if (game.grid[x][0].state == BlockState.GROUND) {
                game.over = true;
                try saveHighScore();
                return;
            }
        }

        // Reset the flag
        game.figureHadLanded = false;

        // Make a new figure
        try makeFigure();

        // Render before looping again
        return;
    }


    // The figure has not landed: allow movement

    // Rotate the figure
    if (rl.IsKeyPressed(rl.KEY_UP)) {
        rotateFigure();
    }

    // Move the figure left
    if (rl.IsKeyPressed(rl.KEY_LEFT)) {
        if (checkBorders(Direction.LEFT)) {
            for (&game.figure) |*rect| {
                rect.coord.x -= 1;
            }
        }
    }
    // Move te figure right
    if (rl.IsKeyPressed(rl.KEY_RIGHT)) {
        if (checkBorders(Direction.RIGHT)) {
            for (&game.figure) |*rect| {
                rect.coord.x += 1;
            }
        }
    }
    // Move the figure down (manually)
    if (rl.IsKeyDown(rl.KEY_DOWN)) {
        if (checkBorders(Direction.DOWN)) {
            for (&game.figure) |*rect| {
                rect.coord.y += 1;
            }
        }
    }

    // Move the figure down (gravity)
    game.frameCounter += game.speed;
    if (game.frameCounter >= FPS) {
        game.frameCounter = 0;
        if (checkBorders(Direction.DOWN)) {
            for (&game.figure) |*rect| {
                rect.coord.y += 1;
            }
        }
    }
}

fn render() !void {

    // Data strings
    const allocator = std.heap.page_allocator;
    const scoreString = try std.fmt.allocPrint(allocator, "{d}", .{game.score});
    const levelString = try std.fmt.allocPrint(allocator, "Level {d}", .{game.level});
    defer allocator.free(scoreString);
    defer allocator.free(levelString);

    // Center: game over
    if (game.over) {
        rl.DrawText("ZigTris",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("ZigTris", 100))) / 2.0)),
                    100,
                    100, rl.RED);
        rl.DrawText("All your base are belong to us",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("All your base are belong to us", 20))) / 2.0)),
                    210,
                    20, TEXT_COLOR);
        rl.DrawText("Game Over!",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Game Over!", 60))) / 2.0)),
                    WINDOW_SIZE.y / 2 - 40,
                    60, rl.RED);
        rl.DrawText("Score",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Score", 40))) / 2.0 )),
                    WINDOW_SIZE.y / 2 + 40,
                    40, TEXT_COLOR);
        rl.DrawText(scoreString.ptr,
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText(scoreString.ptr, 60))) / 2.0)),
                    WINDOW_SIZE.y / 2 + 100,
                    60, TEXT_COLOR);
        rl.DrawText("Press [ENTER] to restart",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Press [ENTER] to restart", 20))) / 2.0)),
                    WINDOW_SIZE.y - 40,
                    20, TEXT_COLOR);
        return;
    }

    // Center: pause text (level, score, lives)
    if (game.pause) {
        rl.DrawText("ZigTris",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("ZigTris", 100))) / 2.0)),
                    100,
                    100, rl.RED);
        rl.DrawText("All your base are belong to us",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("All your base are belong to us", 20))) / 2.0)),
                    210,
                    20, TEXT_COLOR);
        rl.DrawText(levelString.ptr,
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText(levelString.ptr, 60))) / 2.0)),
                    WINDOW_SIZE.y / 2 - 40,
                    60, rl.GREEN);
        rl.DrawText("Score",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Score", 40))) / 2.0 )),
                    WINDOW_SIZE.y / 2 + 40,
                    40, TEXT_COLOR);
        rl.DrawText(scoreString.ptr,
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText(scoreString.ptr, 60))) / 2.0)),
                    WINDOW_SIZE.y / 2 + 100,
                    60, TEXT_COLOR);
        rl.DrawText("Press [R] to reset",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Press [R] to reset", 20))) / 2.0)),
                    WINDOW_SIZE.y - 60,
                    20, TEXT_COLOR);
        rl.DrawText("Press [ENTER] to start",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Press [ENTER] to start", 20))) / 2.0)),
                    WINDOW_SIZE.y - 40,
                    20, TEXT_COLOR);
        return;
    }

    // Sidebar
    const LM = WINDOW_SIZE.x - 220;
    const RM = WINDOW_SIZE.x - 20;

    rl.DrawText(APP_NAME, LM-10, 10, 60, TEXT_COLOR);

    rl.DrawText("Score", LM-10, 100, 40, TEXT_COLOR);
    rl.DrawText(scoreString.ptr, LM-10, 150, 40, TEXT_COLOR);
    rl.DrawText(levelString.ptr, LM-10, 200, 40, TEXT_COLOR);

    // Draw next figure
    rl.DrawText("Next figure", LM-10, WINDOW_SIZE.y - 260, 30, TEXT_COLOR);
    rl.DrawRectangleLines(LM-20, RM-10, 200, 200, TEXT_COLOR);
    for (&game.figureNext) |*block| {
        block.x = @floatFromInt(block.coord.x * TILE_SIZE);
        block.y = @floatFromInt(block.coord.y * TILE_SIZE);
        // Add offset
        block.x += 360;
        block.y += WINDOW_SIZE.y - 200.0;
        // Draw
        rl.DrawRectangleRec(block.getRect(), block.color);
        rl.DrawRectangleLinesEx(block.getRect(), 1, GRID_COLOR);
    }

    // Draw grid
    for (0..GRID_SIZE.x) |x| {
        for (0..GRID_SIZE.y) |y| {
            const block = &game.grid[x][y];
            switch (block.state) {
                .EMPTY => {
                    rl.DrawRectangleLinesEx(block.getRect(), 1, GRID_COLOR);
                },
                .GROUND => {
                    if(NEUTRAL_LINE_COLOR) {
                        rl.DrawRectangleRec(block.getRect(), LINE_COLOR);
                    } else {
                        rl.DrawRectangleRec(block.getRect(), block.color);
                    }
                    rl.DrawRectangleLinesEx(block.getRect(), 1, GRID_COLOR);
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
        rl.DrawRectangleLinesEx(block.getRect(), 1, GRID_COLOR);
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
        // Center figures
        var minX: usize = std.math.maxInt(usize);
        var maxX: usize = 0;
        var minY: usize = std.math.maxInt(usize);
        var maxY: usize = 0;

        for (posList) |pos| {
            if (pos.x < minX) minX = pos.x;
            if (pos.x > maxX) maxX = pos.x;
            if (pos.y < minY) minY = pos.y;
            if (pos.y > maxY) maxY = pos.y;
        }

        const offsetX = (GRID_SIZE.x - (maxX - minX + 1)) / 2 - minX;
        const offsetY = 0;

        // Create figure blocks
        var blocks: [4]Block = undefined;
        for (0.., posList) |j, pos| {
            blocks[j] = Block{
                .coord = Coord{
                    .x = pos.x + offsetX,
                    .y = pos.y - minY + offsetY,
                },
                .x = 0,
                .y = 0,
                .width = TILE_SIZE,
                .height = TILE_SIZE,
                .color = rl.RAYWHITE, // Color is set later
                .state = BlockState.FIGURE,
            };
        }
        try game.figures.append(blocks);
    }


    // Initialize music
    rl.InitAudioDevice();
    defer rl.CloseAudioDevice();
    game.music = rl.LoadMusicStream("sound/korobeiniki.wav");
    rl.PlayMusicStream(game.music);
    defer rl.UnloadMusicStream(game.music);

    // Initialize raylib
    rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, APP_NAME);
    defer rl.CloseWindow();
    rl.SetWindowPosition(WINDOW_POSITION.y, WINDOW_POSITION.y);
    rl.SetTargetFPS(FPS);

    try start();

    // Raylib main loop
    while (!rl.WindowShouldClose()) {
        rl.UpdateMusicStream(game.music);

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(BACKGROUND_COLOR);

        try update();
        try render();
    }
}
