const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

// TODO FIX: weird rotation behavior on the left border for some figures (S -> square)
// TODO: improve display of score and level on the sidebar
// TODO: balance difficulty (speed increase should be more linear)
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

const FIGURE_COLORS: [12]rl.Color = .{
    rl.RED,
    rl.ORANGE,
    rl.GOLD,
    rl.LIME,
    rl.BLUE,
    rl.SKYBLUE,
    rl.VIOLET,
    rl.PURPLE,
    rl.MAGENTA,
    rl.MAROON,
    rl.PINK,
    rl.BROWN,
};

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
                    20, rl.DARKGRAY);
        rl.DrawText("Game Over!",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Game Over!", 60))) / 2.0)),
                    WINDOW_SIZE.y / 2 - 40,
                    60, rl.RED);
        rl.DrawText("Score",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Score", 40))) / 2.0 )),
                    WINDOW_SIZE.y / 2 + 40,
                    40, rl.DARKGRAY);
        rl.DrawText(scoreString.ptr,
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText(scoreString.ptr, 60))) / 2.0)),
                    WINDOW_SIZE.y / 2 + 100,
                    60, rl.DARKGRAY);
        rl.DrawText("Press [ENTER] to restart",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Press [ENTER] to restart", 20))) / 2.0)),
                    WINDOW_SIZE.y - 40,
                    20, rl.DARKGRAY);
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
                    20, rl.DARKGRAY);
        rl.DrawText(levelString.ptr,
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText(levelString.ptr, 60))) / 2.0)),
                    WINDOW_SIZE.y / 2 - 40,
                    60, rl.GREEN);
        rl.DrawText("Score",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Score", 40))) / 2.0 )),
                    WINDOW_SIZE.y / 2 + 40,
                    40, rl.DARKGRAY);
        rl.DrawText(scoreString.ptr,
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText(scoreString.ptr, 60))) / 2.0)),
                    WINDOW_SIZE.y / 2 + 100,
                    60, rl.DARKGRAY);
        rl.DrawText("Press [R] to reset",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Press [R] to reset", 20))) / 2.0)),
                    WINDOW_SIZE.y - 60,
                    20, rl.DARKGRAY);
        rl.DrawText("Press [ENTER] to start",
                    @as(c_int, @intFromFloat(WINDOW_SIZE.x / 2 - @as(f32, @floatFromInt(rl.MeasureText("Press [ENTER] to start", 20))) / 2.0)),
                    WINDOW_SIZE.y - 40,
                    20, rl.DARKGRAY);
        return;
    }

    // Sidebar
    const LM = WINDOW_SIZE.x - 220;
    const RM = WINDOW_SIZE.x - 20;

    rl.DrawText(APP_NAME, LM-10, 10, 60, rl.DARKGRAY);

    rl.DrawText("Score", LM-10, 100, 40, rl.DARKGRAY);
    rl.DrawText(scoreString.ptr, LM-10, 150, 40, rl.DARKGRAY);
    rl.DrawText(levelString.ptr, LM-10, 200, 40, rl.DARKGRAY);

    // Draw next figure
    rl.DrawText("Next figure", LM-10, WINDOW_SIZE.y - 260, 30, rl.DARKGRAY);
    rl.DrawRectangleLines(LM-10, RM-10, 200, 200, rl.DARKGRAY);
    for (&game.figureNext) |*block| {
        block.x = @floatFromInt(block.coord.x * TILE_SIZE);
        block.y = @floatFromInt(block.coord.y * TILE_SIZE);
        // Add offset
        block.x += 360;
        block.y += WINDOW_SIZE.y - 200.0;
        // Draw
        rl.DrawRectangleRec(block.getRect(), block.color);
        rl.DrawRectangleLinesEx(block.getRect(), 1, rl.RAYWHITE);
    }

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
        rl.DrawRectangleLinesEx(block.getRect(), 1, rl.RAYWHITE);
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

        rl.ClearBackground(rl.BLACK);

        try update();
        try render();
    }
}
