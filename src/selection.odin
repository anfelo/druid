package main

import rl "vendor:raylib"

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

selection_update :: proc(state: ^DruidState) {
	hovered_idx := -1
	for obj, i in state.objects {
		if (mouse_collides_with_object(state.mouse_position, obj)) {
			hovered_idx = i
			break
		}
	}
	state.selection.hovered_idx = hovered_idx

	if (rl.IsMouseButtonPressed(.LEFT)) {
		state.selection.mouse_pressed = true
		state.selection.mouse_pressed_pos = state.mouse_position

		if (state.selection.selected_idx == -1) {
			state.selection.selected_idx = state.selection.hovered_idx
		}
	}

	if (state.selection.mouse_pressed) {
		if (state.selection.selected_idx != -1) {
			object_resize(state)
		} else {
			// TODO: Check for objects selected
		}
	}

	if (rl.IsMouseButtonReleased(.LEFT)) {
		state.selection.mouse_pressed = false
	}

	if (state.selection.selected_idx != -1 && !state.selection.mouse_pressed) {
		selection_set_mouse_mode(state)
	}
}

selection_draw :: proc(state: ^DruidState) {
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
			}
		}
	}

	if (state.toolbar.selected == .Selection) {
		if (state.selection.mouse_pressed && state.selection.selected_idx == -1) {
			selection_origin := state.selection.mouse_pressed_pos
			selection_rect := rl.Rectangle {
				x      = selection_origin.x,
				y      = selection_origin.y,
				width  = state.mouse_position.x - selection_origin.x,
				height = state.mouse_position.y - selection_origin.y,
			}

			rl.DrawRectangleLines(
				cast(i32)selection_rect.x,
				cast(i32)selection_rect.y,
				cast(i32)selection_rect.width,
				cast(i32)selection_rect.height,
				rl.SKYBLUE,
			)
		}
	}

}

selection_set_mouse_mode :: proc(state: ^DruidState) {
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
		if (rl.CheckCollisionPointRec(state.mouse_position, area.rect)) {
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
