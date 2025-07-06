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

DruidSelection :: struct {
	mouse_mode:           DruidMouseMode,
	mouse_pressed:        bool,
	mouse_pressed_pos:    rl.Vector2,
	selection_area_coord: DruidCoord,
	selected_idx:         int,
	hovered_idx:          int,
}

DruidSelectionArea :: struct {
	rect:  rl.Rectangle,
	coord: DruidCoord,
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
				hovered_idx := -1
				for obj, i in state.objects {
					if (mouse_collides_with_object(mouse_position, obj)) {
						hovered_idx = i
						break
					}
				}
				state.selection.hovered_idx = hovered_idx

				if (rl.IsMouseButtonPressed(.LEFT)) {
					state.selection.mouse_pressed = true
					state.selection.mouse_pressed_pos = mouse_position

					if (state.selection.selected_idx == -1) {
						state.selection.selected_idx = state.selection.hovered_idx
					}
				}

				if (state.selection.mouse_pressed) {
					if (state.selection.selected_idx != -1) {
						object_resize(&state, mouse_position)
					} else {
						// TODO: Check for objects selected
					}
				}

				if (rl.IsMouseButtonReleased(.LEFT)) {
					state.selection.mouse_pressed = false
				}

				if (state.selection.selected_idx != -1 && !state.selection.mouse_pressed) {
					set_selection_mouse_mode(&state, mouse_position)
				}
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

		// Objects
		for item, i in state.objects {
			switch item.type {
			case .Rectangle:
				if (state.selection.selected_idx == i) {
					selection_rect := rl.Rectangle {
						x      = item.position.x - SELECTION_MARGIN,
						y      = item.position.y - SELECTION_MARGIN,
						width  = item.scale.x + SELECTION_MARGIN * 2,
						height = item.scale.y + SELECTION_MARGIN * 2,
					}

					rl.DrawRectangleLines(
						cast(i32)selection_rect.x,
						cast(i32)selection_rect.y,
						cast(i32)selection_rect.width,
						cast(i32)selection_rect.height,
						rl.SKYBLUE,
					)

					rl.DrawRectangle(
						cast(i32)selection_rect.x - SELECTION_CORNER_RECT_SIZE / 2,
						cast(i32)selection_rect.y - SELECTION_CORNER_RECT_SIZE / 2,
						SELECTION_CORNER_RECT_SIZE,
						SELECTION_CORNER_RECT_SIZE,
						rl.SKYBLUE,
					)
					rl.DrawRectangle(
						cast(i32)selection_rect.x +
						cast(i32)selection_rect.width -
						SELECTION_CORNER_RECT_SIZE / 2,
						cast(i32)selection_rect.y - SELECTION_CORNER_RECT_SIZE / 2,
						SELECTION_CORNER_RECT_SIZE,
						SELECTION_CORNER_RECT_SIZE,
						rl.SKYBLUE,
					)
					rl.DrawRectangle(
						cast(i32)selection_rect.x +
						cast(i32)selection_rect.width -
						SELECTION_CORNER_RECT_SIZE / 2,
						cast(i32)selection_rect.y +
						cast(i32)selection_rect.height -
						SELECTION_CORNER_RECT_SIZE / 2,
						SELECTION_CORNER_RECT_SIZE,
						SELECTION_CORNER_RECT_SIZE,
						rl.SKYBLUE,
					)
					rl.DrawRectangle(
						cast(i32)selection_rect.x - SELECTION_CORNER_RECT_SIZE / 2,
						cast(i32)selection_rect.y +
						cast(i32)selection_rect.height -
						SELECTION_CORNER_RECT_SIZE / 2,
						SELECTION_CORNER_RECT_SIZE,
						SELECTION_CORNER_RECT_SIZE,
						rl.SKYBLUE,
					)
				} else if (state.selection.mouse_pressed && state.selection.selected_idx == -1) {
					selection_origin := state.selection.mouse_pressed_pos
					selection_rect := rl.Rectangle {
						x      = selection_origin.x,
						y      = selection_origin.y,
						width  = mouse_position.x - selection_origin.x,
						height = mouse_position.y - selection_origin.y,
					}

					rl.DrawRectangleLines(
						cast(i32)selection_rect.x,
						cast(i32)selection_rect.y,
						cast(i32)selection_rect.width,
						cast(i32)selection_rect.height,
						rl.SKYBLUE,
					)
				}

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

set_selection_mouse_mode :: proc(state: ^DruidState, mouse_position: rl.Vector2) {
	mouse_mode: DruidMouseMode = .None

	selection_object := state.objects[state.selection.selected_idx]
	selection_rect := rl.Rectangle {
		x      = selection_object.position.x - SELECTION_MARGIN,
		y      = selection_object.position.y - SELECTION_MARGIN,
		width  = selection_object.scale.x + SELECTION_MARGIN * 2,
		height = selection_object.scale.y + SELECTION_MARGIN * 2,
	}
	selection_areas := [?]DruidSelectionArea {
		DruidSelectionArea {
			rect = rl.Rectangle {
				selection_rect.x,
				selection_rect.y,
				selection_rect.width,
				selection_rect.height,
			},
			coord = .CENTER,
		},
		DruidSelectionArea {
			rect = rl.Rectangle {
				selection_rect.x,
				selection_rect.y - SELECTION_MARGIN,
				selection_rect.width,
				SELECTION_MARGIN * 2,
			},
			coord = .N,
		},
		DruidSelectionArea {
			rect = rl.Rectangle {
				selection_rect.x,
				selection_rect.y + selection_rect.height - SELECTION_MARGIN,
				selection_rect.width,
				SELECTION_MARGIN * 2,
			},
			coord = .S,
		},
		DruidSelectionArea {
			rect = rl.Rectangle {
				selection_rect.x - SELECTION_MARGIN,
				selection_rect.y,
				SELECTION_MARGIN * 2,
				selection_rect.height,
			},
			coord = .W,
		},
		DruidSelectionArea {
			rect = rl.Rectangle {
				selection_rect.x + selection_rect.width - SELECTION_MARGIN,
				selection_rect.y,
				SELECTION_MARGIN * 2,
				selection_rect.height,
			},
			coord = .E,
		},
		DruidSelectionArea {
			rect = rl.Rectangle {
				selection_rect.x - SELECTION_CORNER_RECT_SIZE / 2,
				selection_rect.y - SELECTION_CORNER_RECT_SIZE / 2,
				SELECTION_CORNER_RECT_SIZE,
				SELECTION_CORNER_RECT_SIZE,
			},
			coord = .NW,
		},
		DruidSelectionArea {
			rect = rl.Rectangle {
				selection_rect.x + selection_rect.width - SELECTION_CORNER_RECT_SIZE / 2,
				selection_rect.y - SELECTION_CORNER_RECT_SIZE / 2,
				SELECTION_CORNER_RECT_SIZE,
				SELECTION_CORNER_RECT_SIZE,
			},
			coord = .NE,
		},
		DruidSelectionArea {
			rect = rl.Rectangle {
				selection_rect.x + selection_rect.width - SELECTION_CORNER_RECT_SIZE / 2,
				selection_rect.y + selection_rect.height - SELECTION_CORNER_RECT_SIZE / 2,
				SELECTION_CORNER_RECT_SIZE,
				SELECTION_CORNER_RECT_SIZE,
			},
			coord = .SE,
		},
		DruidSelectionArea {
			rect = rl.Rectangle {
				selection_rect.x - SELECTION_CORNER_RECT_SIZE / 2,
				selection_rect.y + selection_rect.height - SELECTION_CORNER_RECT_SIZE / 2,
				SELECTION_CORNER_RECT_SIZE,
				SELECTION_CORNER_RECT_SIZE,
			},
			coord = .SW,
		},
	}

	state.selection.selection_area_coord = .None
	for area in selection_areas {
		if (rl.CheckCollisionPointRec(mouse_position, area.rect)) {
			state.selection.selection_area_coord = area.coord
		}
	}

	switch state.selection.selection_area_coord {
	case .N, .S:
		mouse_mode = .ResizingNS
	case .W, .E:
		mouse_mode = .ResizingEW
	case .NW, .SE:
		mouse_mode = .ResizingNWSE
	case .NE, .SW:
		mouse_mode = .ResizingNESW
	case .CENTER:
		mouse_mode = .Dragging
	case .None:
		mouse_mode = .None
	}

	state.selection.mouse_mode = mouse_mode
}

object_resize :: proc(state: ^DruidState, mouse_position: rl.Vector2) {
	obj := &state.objects[state.selection.selected_idx]

	switch state.selection.selection_area_coord {
	case .None:
		state.selection.selected_idx = state.selection.hovered_idx
	case .N:
		delta := mouse_position.y - obj.position.y

		obj.scale.y -= delta
		obj.position.y += delta

		if (obj.scale.y < RECTANGLE_MIN_SIZE) {
			obj.scale.y = RECTANGLE_MIN_SIZE
			obj.position.y -= delta
		}
	case .S:
		delta := mouse_position.y - (obj.position.y + obj.scale.y)

		obj.scale.y += delta

		if (obj.scale.y < RECTANGLE_MIN_SIZE) {
			obj.scale.y = RECTANGLE_MIN_SIZE
		}
	case .W:
		delta := mouse_position.x - obj.position.x

		obj.scale.x -= delta
		obj.position.x += delta

		if (obj.scale.x < RECTANGLE_MIN_SIZE) {
			obj.scale.x = RECTANGLE_MIN_SIZE
			obj.position.x -= delta
		}
	case .E:
		obj := &state.objects[state.selection.selected_idx]
		delta := mouse_position.x - (obj.position.x + obj.scale.x)

		obj.scale.x += delta

		if (obj.scale.x < RECTANGLE_MIN_SIZE) {
			obj.scale.x = RECTANGLE_MIN_SIZE
		}
	case .NW:
		delta := mouse_position - obj.position

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
		delta_x := mouse_position.x - (obj.position.x + obj.scale.x)
		delta_y := mouse_position.y - obj.position.y

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
		delta_x := mouse_position.x - obj.position.x
		delta_y := mouse_position.y - (obj.position.y + obj.scale.y)

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
		delta_y := mouse_position.y - (obj.position.y + obj.scale.y)
		delta_x := mouse_position.x - (obj.position.x + obj.scale.x)

		obj.scale.x += delta_x
		obj.scale.y += delta_y

		if (obj.scale.x < RECTANGLE_MIN_SIZE) {
			obj.scale.x = RECTANGLE_MIN_SIZE
		}

		if (obj.scale.y < RECTANGLE_MIN_SIZE) {
			obj.scale.y = RECTANGLE_MIN_SIZE
		}
	case .CENTER:
		delta := mouse_position - state.selection.mouse_pressed_pos

		state.selection.mouse_pressed_pos += delta

		obj.position += delta
	}
}
