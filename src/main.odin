package main

import "core:fmt"
import "core:slice"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1024
SCREEN_HEIGHT :: 800

SELECTION_MARGIN :: 10.0
SELECTION_CORNER_RECT_SIZE :: 8.0

RECTANGLE_MIN_SIZE :: 12

DruidObjectType :: enum {
	Rectangle,
}

DruidObject :: struct {
	position: rl.Vector2,
	scale:    rl.Vector2,
	type:     DruidObjectType,
}

DruidMouseMode :: enum {
	Deleting,
	Creating,
	Dragging,
	ResizingNS,
	ResizingEW,
	ResizingNWSE,
	ResizingNESW,
	None,
}

DruidCoord :: enum {
	N,
	S,
	W,
	E,
	NW,
	NE,
	SW,
	SE,
	CENTER,
	None,
}

DruidCreation :: struct {
	mouse_mode:   DruidMouseMode,
	resizing_idx: int,
}

DruidDeletion :: struct {
	mouse_mode:        DruidMouseMode,
	deleting_idxs:     [dynamic]int,
	deleting_idxs_map: map[int]bool,
	mouse_pressed:     bool,
}

DruidState :: struct {
	mouse_position: rl.Vector2,
	toolbar:        DruidToolbar,
	objects:        [dynamic]DruidObject,
	selection:      DruidSelection,
	creation:       DruidCreation,
	deletion:       DruidDeletion,
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Druid")

	rl.SetTargetFPS(60)

	state := DruidState {
		toolbar = toolbar_init(),
		objects = {},
		selection = {
			mouse_mode = .None,
			selected_idx = -1,
			hovered_idx = -1,
			mouse_pressed = false,
		},
		creation = {mouse_mode = .None, resizing_idx = -1},
		deletion = {mouse_mode = .None, deleting_idxs = {}, mouse_pressed = false},
	}

	for (!rl.WindowShouldClose()) {
		// Update
		mouse_position := rl.GetMousePosition()
		state.mouse_position = mouse_position

		toolbar_update(&state)

		if (!rl.CheckCollisionPointRec(mouse_position, toolbar_rect)) {
			switch state.toolbar.selected {
			case .Selection:
				selection_update(&state)
			case .Rectangle:
				if (rl.IsMouseButtonPressed(.LEFT)) {
					state.creation.mouse_mode = .Creating

					obj := DruidObject {
						position = mouse_position,
						scale    = rl.Vector2{RECTANGLE_MIN_SIZE, RECTANGLE_MIN_SIZE},
						type     = .Rectangle,
					}
					append(&state.objects, obj)
					state.creation.resizing_idx = len(state.objects) - 1
				}

				if (state.creation.mouse_mode == .Creating && state.creation.resizing_idx != -1) {
					obj := &state.objects[state.creation.resizing_idx]
					obj.scale.x = (mouse_position.x - obj.position.x)
					obj.scale.y = (mouse_position.y - obj.position.y)

					// Check minimum rec size
					if (obj.scale.x < RECTANGLE_MIN_SIZE) {
						obj.scale.x = RECTANGLE_MIN_SIZE
					}

					if (obj.scale.y < RECTANGLE_MIN_SIZE) {
						obj.scale.y = RECTANGLE_MIN_SIZE
					}

					if (rl.IsMouseButtonReleased(.LEFT)) {
						state.creation.mouse_mode = .None
						state.creation.resizing_idx = -1
					}
				}

			case .Eraser:
				if (rl.IsMouseButtonPressed(.LEFT)) {
					state.deletion.mouse_mode = .Deleting
					state.deletion.mouse_pressed = true
				}

				if (state.deletion.mouse_pressed) {
					for obj, idx in state.objects {
						obj_rect := rl.Rectangle {
							x      = obj.position.x,
							y      = obj.position.y,
							width  = obj.scale.x,
							height = obj.scale.y,
						}
						_, ok := state.deletion.deleting_idxs_map[idx]

						if (rl.CheckCollisionPointRec(mouse_position, obj_rect) && !ok) {
							append(&state.deletion.deleting_idxs, idx)
							state.deletion.deleting_idxs_map[idx] = true
						}
					}
				}

				if (rl.IsMouseButtonReleased(.LEFT)) {
					state.creation.mouse_mode = .None
					state.creation.resizing_idx = -1

					// INFO: Sort the indexes to remove first to prevent out of
					// bounds deletions
					del_slice := state.deletion.deleting_idxs[:]
					slice.reverse_sort(del_slice)

					for del_idx in del_slice {
						unordered_remove(&state.objects, del_idx)
					}

					clear(&state.deletion.deleting_idxs)
					clear(&state.deletion.deleting_idxs_map)
				}

			case .None:
			}
		}

		set_mouse_cursor(&state, mouse_position)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		selection_draw(&state)

		// Objects
		for item, i in state.objects {
			switch item.type {
			case .Rectangle:
				_, erasing := state.deletion.deleting_idxs_map[i]
				color := erasing ? rl.GRAY : rl.RAYWHITE
				rl.DrawRectangleLines(
					cast(i32)item.position.x,
					cast(i32)item.position.y,
					cast(i32)item.scale.x,
					cast(i32)item.scale.y,
					color,
				)
			}
		}

		// Toolbar
		toolbar_draw(&state)

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

set_mouse_cursor :: proc(state: ^DruidState, mouse_position: rl.Vector2) {
	switch state.toolbar.selected {
	case .Selection:
		// TODO: Separate the idea of hovered_idx and selection
		// There is a bug when some objects overlap the others
		if (state.selection.hovered_idx != -1 &&
			   state.selection.selected_idx != state.selection.hovered_idx &&
			   !state.selection.mouse_pressed) {
			rl.SetMouseCursor(.POINTING_HAND)
		} else if (state.selection.selected_idx != -1) {
			#partial switch state.selection.mouse_mode {
			case .Dragging:
				rl.SetMouseCursor(.RESIZE_ALL)
			case .ResizingNS:
				rl.SetMouseCursor(.RESIZE_NS)
			case .ResizingEW:
				rl.SetMouseCursor(.RESIZE_EW)
			case .ResizingNWSE:
				rl.SetMouseCursor(.RESIZE_NWSE)
			case .ResizingNESW:
				rl.SetMouseCursor(.RESIZE_NESW)
			case .None:
				rl.SetMouseCursor(.DEFAULT)
			}
		} else {
			rl.SetMouseCursor(.DEFAULT)
		}
	case .Rectangle:
		rl.SetMouseCursor(.CROSSHAIR)
	case .Eraser:
		rl.SetMouseCursor(.POINTING_HAND)
	case .None:
		rl.SetMouseCursor(.DEFAULT)
	}
}

mouse_collides_with_object :: proc(mouse_position: rl.Vector2, object: DruidObject) -> bool {
	object_border_rects := [?]rl.Rectangle {
		{x = object.position.x, y = object.position.y - 2.0, width = object.scale.x, height = 8.0},
		{x = object.position.x - 2.0, y = object.position.y, width = 8.0, height = object.scale.y},
		{
			x = object.position.x,
			y = object.position.y + object.scale.y - 2.0,
			width = object.scale.x,
			height = 8.0,
		},
		{
			x = object.position.x + object.scale.x - 2.0,
			y = object.position.y,
			width = 8.0,
			height = object.scale.y,
		},
	}

	for rect in object_border_rects {
		if (rl.CheckCollisionPointRec(mouse_position, rect)) {
			return true
		}
	}

	return false
}

object_resize :: proc(state: ^DruidState) {
	obj := &state.objects[state.selection.selected_idx]

	switch state.selection.selection_area_coord {
	case .None:
		state.selection.selected_idx = state.selection.hovered_idx
	case .N:
		delta := state.mouse_position.y - obj.position.y

		obj.scale.y -= delta
		obj.position.y += delta

		if (obj.scale.y < RECTANGLE_MIN_SIZE) {
			obj.scale.y = RECTANGLE_MIN_SIZE
			obj.position.y -= delta
		}
	case .S:
		delta := state.mouse_position.y - (obj.position.y + obj.scale.y)

		obj.scale.y += delta

		if (obj.scale.y < RECTANGLE_MIN_SIZE) {
			obj.scale.y = RECTANGLE_MIN_SIZE
		}
	case .W:
		delta := state.mouse_position.x - obj.position.x

		obj.scale.x -= delta
		obj.position.x += delta

		if (obj.scale.x < RECTANGLE_MIN_SIZE) {
			obj.scale.x = RECTANGLE_MIN_SIZE
			obj.position.x -= delta
		}
	case .E:
		obj := &state.objects[state.selection.selected_idx]
		delta := state.mouse_position.x - (obj.position.x + obj.scale.x)

		obj.scale.x += delta

		if (obj.scale.x < RECTANGLE_MIN_SIZE) {
			obj.scale.x = RECTANGLE_MIN_SIZE
		}
	case .NW:
		delta := state.mouse_position - obj.position

		obj.scale -= delta
		obj.position += delta

		if (obj.scale.x < RECTANGLE_MIN_SIZE) {
			obj.scale.x = RECTANGLE_MIN_SIZE
			obj.position.x -= delta.x
		}

		if (obj.scale.y < RECTANGLE_MIN_SIZE) {
			obj.scale.y = RECTANGLE_MIN_SIZE
			obj.position.y -= delta.y
		}
	case .NE:
		delta_x := state.mouse_position.x - (obj.position.x + obj.scale.x)
		delta_y := state.mouse_position.y - obj.position.y

		obj.scale.x += delta_x
		obj.scale.y -= delta_y
		obj.position.y += delta_y

		if (obj.scale.x < RECTANGLE_MIN_SIZE) {
			obj.scale.x = RECTANGLE_MIN_SIZE
		}

		if (obj.scale.y < RECTANGLE_MIN_SIZE) {
			obj.scale.y = RECTANGLE_MIN_SIZE
			obj.position.y -= delta_y
		}
	case .SW:
		delta_x := state.mouse_position.x - obj.position.x
		delta_y := state.mouse_position.y - (obj.position.y + obj.scale.y)

		obj.scale.x -= delta_x
		obj.position.x += delta_x
		obj.scale.y += delta_y

		if (obj.scale.x < RECTANGLE_MIN_SIZE) {
			obj.scale.x = RECTANGLE_MIN_SIZE
			obj.position.x -= delta_x
		}

		if (obj.scale.y < RECTANGLE_MIN_SIZE) {
			obj.scale.y = RECTANGLE_MIN_SIZE
		}
	case .SE:
		delta_y := state.mouse_position.y - (obj.position.y + obj.scale.y)
		delta_x := state.mouse_position.x - (obj.position.x + obj.scale.x)

		obj.scale.x += delta_x
		obj.scale.y += delta_y

		if (obj.scale.x < RECTANGLE_MIN_SIZE) {
			obj.scale.x = RECTANGLE_MIN_SIZE
		}

		if (obj.scale.y < RECTANGLE_MIN_SIZE) {
			obj.scale.y = RECTANGLE_MIN_SIZE
		}
	case .CENTER:
		delta := state.mouse_position - state.selection.mouse_pressed_pos

		state.selection.mouse_pressed_pos += delta

		obj.position += delta
	}
}
