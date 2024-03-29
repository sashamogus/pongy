package pongy

import "core:fmt"
import "core:math"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480

PADDLE_OFFSET :: 15
PADDLE_WIDTH :: 15
PADDLE_HEIGHT :: 60
PADDLE_SPEED :: 200
PADDLE_SPEED_COM :: 300
PADDLE_START :: (WINDOW_HEIGHT - PADDLE_HEIGHT) / 2

BALL_RADIUS :: 10
BALL_SPEED :: 150
BALL_ACCEL :: 10

SERVE_TIME :: 3
SCORE_TIME :: 3

GameState :: enum {
    MENU,
    SERVE,
    GAME,
    SCORE,
}

game_state := GameState.MENU
state_timer: f32
scored_player: int

InputType :: enum {
    PLAYER1,
    PLAYER2,
    COM,
}

Player :: struct {
    input_type: InputType,
    paddle_pos: [2]f32,
    score: int,
}

players := [2]Player {
    Player {
        input_type = .PLAYER1,
        paddle_pos = { PADDLE_OFFSET, PADDLE_START },
    },
    Player {
        input_type = .PLAYER2,
        paddle_pos = { WINDOW_WIDTH - PADDLE_OFFSET - PADDLE_WIDTH, PADDLE_START },
    },
}

ball_pos: [2]f32
ball_vel: [2]f32

init_game :: proc() {
    enter_menu()
}

enter_menu :: proc() {
    game_state = .MENU
    state_timer = 0
    for &p in players {
        p.paddle_pos.y = PADDLE_START
        p.score = 0
    }
    ball_vel = BALL_SPEED
}

enter_serve :: proc() {
    game_state = .SERVE
    state_timer = 0
    ball_pos = { WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2 }
}

enter_game :: proc() {
    game_state = .GAME
    state_timer = 0
}

enter_score :: proc(player_id: int) {
    game_state = .SCORE
    state_timer = 0
    scored_player = player_id
    players[player_id].score += 1
    ball_pos = { WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2 }
    ball_vel = BALL_SPEED
    if player_id == 1 {
        ball_vel = -ball_vel
    }
}

update_game :: proc() {
    state_timer += rl.GetFrameTime()
    reflect := [2]f32 { 1, -1 }
    for &p, i in players {
        up_held: bool
        down_held: bool
        switch p.input_type {
            case .PLAYER1:
                up_held = rl.IsKeyDown(.W)
                down_held = rl.IsKeyDown(.S)
            case .PLAYER2:
                up_held = rl.IsKeyDown(.I)
                down_held = rl.IsKeyDown(.K)
            case .COM:
                center_y := p.paddle_pos.y + PADDLE_HEIGHT / 2
                if abs(center_y - ball_pos.y) > 10 {
                    up_held = center_y > ball_pos.y
                    down_held = center_y < ball_pos.y
                }
        }
        speed := f32(p.input_type == .COM ? PADDLE_SPEED_COM : PADDLE_SPEED)
        if up_held {
            p.paddle_pos.y -= speed * rl.GetFrameTime()
        }
        if down_held {
            p.paddle_pos.y += speed * rl.GetFrameTime()
        }
        if p.paddle_pos.y < 0 do p.paddle_pos.y = 0
        MAX_Y :: WINDOW_HEIGHT - PADDLE_HEIGHT
        if p.paddle_pos.y > MAX_Y do p.paddle_pos.y = MAX_Y

        if math.sign(ball_vel.x) != reflect[i] {
            if rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, rl.Rectangle { p.paddle_pos.x, p.paddle_pos.y, PADDLE_WIDTH, PADDLE_HEIGHT }) {
                ball_vel.x = reflect[i] * (abs(ball_vel.x) + BALL_ACCEL)
            }
        }
    }
    switch game_state {
        case .MENU:
            if rl.IsKeyPressed(.ONE) {
                players[1].input_type = .COM
                enter_serve()
            }
            if rl.IsKeyPressed(.TWO) {
                players[1].input_type = .PLAYER2
                enter_serve()
            }
        case .SERVE:
            if state_timer > SERVE_TIME {
                enter_game()
            }
        case .GAME:
            ball_pos += ball_vel * rl.GetFrameTime()
            if ball_pos.y < BALL_RADIUS {
                ball_pos.y = BALL_RADIUS
                ball_vel.y = -ball_vel.y + BALL_ACCEL
            }
            if ball_pos.y > WINDOW_HEIGHT - BALL_RADIUS {
                ball_pos.y = WINDOW_HEIGHT - BALL_RADIUS
                ball_vel.y = -ball_vel.y - BALL_ACCEL
            }
            if ball_pos.x < -BALL_RADIUS {
                enter_score(1)
            }
            if ball_pos.x > WINDOW_WIDTH + BALL_RADIUS {
                enter_score(0)
            }
        case .SCORE:
            if state_timer > SCORE_TIME {
                enter_serve()
            }
    }
}

draw_game :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)

    for p in players {
        rl.DrawRectangleV(p.paddle_pos, { PADDLE_WIDTH, PADDLE_HEIGHT }, rl.WHITE)
    }

    if game_state != .MENU {
        rl.DrawCircleV(ball_pos, BALL_RADIUS, rl.WHITE)
    }
    
    draw_number(cast(i32)players[0].score, { (WINDOW_WIDTH / 2) - 100, 20 }, 50)
    draw_number(cast(i32)players[1].score, { (WINDOW_WIDTH / 2) + 100, 20 }, 50)

    if game_state == .GAME {
        for y := f32(0); y < WINDOW_HEIGHT; y += 50 {
            rl.DrawRectangleV({ (WINDOW_WIDTH / 2) - 5, y }, { 10, 25 }, rl.WHITE)
        }
    }

    #partial switch game_state {
        case .MENU:
            draw_text_centered("Press 1 for single player", { WINDOW_WIDTH / 2, 100 }, 30)
            draw_text_centered("Press 2 for 2 player", { WINDOW_WIDTH / 2, 200 }, 30)
        case .SERVE:
            draw_text_centered("Ready?", { WINDOW_WIDTH / 2, (WINDOW_HEIGHT / 2) - 50 }, 30)
        case .SCORE:
            text := fmt.caprintf("Player %d Scored!", scored_player + 1)
            defer delete(text)
            draw_text_centered(text, { WINDOW_WIDTH / 2, (WINDOW_HEIGHT / 2) - 50 }, 30)
    }

    rl.EndDrawing()
}

draw_number :: proc(n: i32, pos: [2]i32, font_size: i32) {
    buf: [256]byte
    result := strconv.append_int(buf[:], cast(i64)n, 10)
    cstr := strings.clone_to_cstring(result)
    defer delete(cstr)
    draw_text_centered(cstr, pos, font_size)
}

draw_text_centered :: proc(text: cstring, pos: [2]i32, font_size: i32) {
    length := rl.MeasureText(text, font_size)
    rl.DrawText(text, pos.x - length / 2, pos.y, font_size, rl.WHITE)
}

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Pongy :)")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    init_game()

    for !rl.WindowShouldClose() {
        update_game()
        draw_game()
    }
}