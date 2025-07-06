package main

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Druid")

	rl.SetTargetFPS(60)

	state := druid_init()

	for (!rl.WindowShouldClose()) {
		// Update
		druid_update(&state)

		rl.BeginDrawing()

		rl.ClearBackground(rl.BLACK)

		druid_draw(&state)

		rl.EndDrawing()
	}

	rl.CloseWindow()
}
