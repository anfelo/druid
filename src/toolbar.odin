package main

import rl "vendor:raylib"

TOOLBAR_WIDTH :: 118
TOOLBAR_HEIGHT :: 44
TOOLBAR_ITEM_SIZE :: 34
TOOLBAR_ITEM_MARGIN :: 4

DruidToolbarItemType :: enum {
	Selection,
	Rectangle,
	Eraser,
	None,
}

DruidToolbarItem :: struct {
	type: DruidToolbarItemType,
	icon: rl.GuiIconName,
}

DruidToolbar :: struct {
	position: rl.Vector2,
	selected: DruidToolbarItemType,
	hovered:  DruidToolbarItemType,
}

toolbar_items := [?]DruidToolbarItem {
	{type = .Selection, icon = .ICON_CURSOR_CLASSIC},
	{type = .Rectangle, icon = .ICON_BOX},
	{type = .Eraser, icon = .ICON_RUBBER},
}

toolbar_position := rl.Vector2{SCREEN_WIDTH / 2 - TOOLBAR_WIDTH / 2, 4}

toolbar_rect := rl.Rectangle{toolbar_position.x, toolbar_position.y, TOOLBAR_WIDTH, TOOLBAR_HEIGHT}

toolbar_init :: proc() -> DruidToolbar {
	return DruidToolbar {
		position = rl.Vector2{SCREEN_WIDTH / 2 - TOOLBAR_WIDTH / 2, 4},
		selected = .Selection,
		hovered = .None,
	}
}

toolbar_update :: proc(state: ^DruidState) {
	if (rl.CheckCollisionPointRec(state.mouse_position, toolbar_rect)) {
		for item, i in toolbar_items {
			item_rect := rl.Rectangle {
				toolbar_position.x +
				cast(f32)(TOOLBAR_ITEM_SIZE * i) +
				cast(f32)(TOOLBAR_ITEM_MARGIN * i) +
				TOOLBAR_ITEM_MARGIN,
				toolbar_position.y + 5,
				TOOLBAR_ITEM_SIZE,
				TOOLBAR_ITEM_SIZE,
			}
			if (rl.CheckCollisionPointRec(state.mouse_position, item_rect)) {
				state.toolbar.hovered = item.type
				if (rl.IsMouseButtonPressed(.LEFT)) {
					state.toolbar.selected = item.type
					state.selection.selected_idx = -1
				}
			} else if (state.toolbar.hovered == item.type) {
				state.toolbar.hovered = .None
			}
		}
	} else {
		state.toolbar.hovered = .None
	}
}

toolbar_draw :: proc(state: ^DruidState) {
	rl.DrawRectangle(
		cast(i32)toolbar_position.x,
		cast(i32)toolbar_position.y,
		TOOLBAR_WIDTH,
		TOOLBAR_HEIGHT,
		rl.BLACK,
	)
	rl.DrawRectangleLines(
		cast(i32)toolbar_position.x,
		cast(i32)toolbar_position.y,
		TOOLBAR_WIDTH,
		TOOLBAR_HEIGHT,
		rl.DARKGRAY,
	)
	for item, i in toolbar_items {
		color :=
			item.type == state.toolbar.selected ? rl.SKYBLUE : item.type == state.toolbar.hovered ? rl.BLUE : rl.DARKGRAY

		rl.DrawRectangleLines(
			cast(i32)toolbar_position.x +
			cast(i32)(TOOLBAR_ITEM_SIZE * i) +
			cast(i32)(TOOLBAR_ITEM_MARGIN * i) +
			TOOLBAR_ITEM_MARGIN,
			cast(i32)toolbar_position.y + 5,
			TOOLBAR_ITEM_SIZE,
			TOOLBAR_ITEM_SIZE,
			color,
		)

		rl.GuiDrawIcon(
			item.icon,
			cast(i32)toolbar_position.x +
			cast(i32)(TOOLBAR_ITEM_SIZE * i) +
			cast(i32)(TOOLBAR_ITEM_MARGIN * i) +
			TOOLBAR_ITEM_MARGIN +
			1,
			cast(i32)toolbar_position.y + 6,
			2,
			color,
		)
	}
}
