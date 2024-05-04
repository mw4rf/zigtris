const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

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

fn Vec2(x: f32, y: f32) rl.Vector2 {
    return rl.Vector2{ .x = x, .y = y };
}

//=======================================
//========= GAME LOGIC ==================
//=======================================

const Game = struct {
    over: bool = false,
    pause: bool = true,
    score: u32 = 0,
    level: u8 = 0,
    grid: std.ArrayList(rl.Rectangle) = undefined,
    figures: std.ArrayList([4]rl.Rectangle) = undefined,
    figure: [4]rl.Rectangle = undefined,
    figureNext: [4]rl.Rectangle = undefined,
    frameCounter: u32 = 0,
    speed: u32 = 1,
};
var game: Game = Game{};

// Tetromino figures definition
const FIGURES_POS: [7][4]rl.Vector2 = .{
    .{Vec2(-1, 0), Vec2(-2, 0), Vec2(0, 0), Vec2(1, 0)},
    .{Vec2(0, -1), Vec2(-1, -1), Vec2(-1, 0), Vec2(0, 0)},
    .{Vec2(-1, 0), Vec2(-1, 1), Vec2(0, 0), Vec2(0, -1)},
    .{Vec2(0, 0), Vec2(-1, 0), Vec2(0, 1), Vec2(-1, -1)},
    .{Vec2(0, 0), Vec2(0, -1), Vec2(0, 1), Vec2(-1, -1)},
    .{Vec2(0, 0), Vec2(0, -1), Vec2(0, 1), Vec2(1, -1)},
    .{Vec2(0, 0), Vec2(0, -1), Vec2(0, 1), Vec2(-1, 0)},
};


fn start() !void {
    // Set game going
    game.over = false;
    game.score = 0;
    game.level = 0;
    // Initialize the grid
    game.grid.clearRetainingCapacity();
    // The grid is a 2D array of rectangles, each one representing a tile
    for (0..GRID_SIZE.x) |x| {
        for (0..GRID_SIZE.y) |y| {
            const rect = rl.Rectangle {
                .x = @floatFromInt(x * TILE_SIZE),
                .y = @floatFromInt(y * TILE_SIZE),
                .width = TILE_SIZE,
                .height = TILE_SIZE
            };
            try game.grid.append(rect);
        }
    }
    // Choose a random figure and its next
    // var prng = std.rand.Xoshiro256.init(1229948729847);
    // const random = prng.random();
    // game.figure = game.figures.items[random.uintAtMost(usize, game.figures.items.len)];
    // game.figureNext = game.figures.items[random.uintAtMost(usize, game.figures.items.len)];
    try makeFigure();
    try makeFigure();
}

fn makeFigure() !void {
    // Copy the next figure to the current figure
    game.figure = game.figureNext;
    // Choose a new next figure
    var prng = std.rand.Xoshiro256.init(1229948729847);
    const random = prng.random();
    game.figureNext = game.figures.items[random.uintAtMost(usize, game.figures.items.len)];
}

fn rotateFigure () void {
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
};

fn checkBorders(dir: Direction) bool {
    for (&game.figure) |*rect| {
        if (dir == Direction.LEFT) {
            if (rect.x <= 0) {
                return false;
            }
        } else if (dir == Direction.RIGHT) {
            if (rect.x >= BOARD_SIZE.x - TILE_SIZE) {
                return false;
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
    if (rl.IsKeyPressed(rl.KEY_DOWN)) {
        for (&game.figure) |*rect| {
            rect.y += TILE_SIZE;
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
        for (&game.figure) |*rect| {
            rect.y += TILE_SIZE;
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
    for (game.grid.items) |rect| {
        rl.DrawRectangleLinesEx(rect, 1, rl.DARKGRAY);
    }

    // Draw current figure
    for (game.figure) |rect| {
        // TODO: colors
        rl.DrawRectangleRec(rect, rl.RED);
        rl.DrawRectangleLinesEx(rect, 1, rl.YELLOW);
    }

}




pub fn main() !void {
    // Allocate memory for the game
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    game.grid = std.ArrayList(rl.Rectangle).init(allocator);
    defer game.grid.deinit();

    game.figures = std.ArrayList([4]rl.Rectangle).init(allocator);
    defer game.figures.deinit();

    // Initialize figures
    inline for (FIGURES_POS) |posList| {
        var rec: [4]rl.Rectangle = undefined;
        for(0.., posList) |j, pos| {
            rec[j] = rl.Rectangle {
                .x = @divTrunc(pos.x + GRID_SIZE.x, 2) * TILE_SIZE,
                .y = @as(f32, pos.y + 1) * TILE_SIZE,
                .width = TILE_SIZE,
                .height = TILE_SIZE,
            };
        }
        try game.figures.append(rec);
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
