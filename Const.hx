import hxd.Key as K;

enum abstract Direction(Int) from Int to Int{
	var Up = 0;
	var Right = 1;
	var Down = 2;
	var Left = 3;

	public inline function rotateBy(i: Int): Direction {
		var a = this + i;
		if (a < 0)
			a += 4;
		a %= 4;
		return a;
	}
}

typedef InputConfig = {
	left: Int,
	right: Int,
	softDrop: Int,
	hardDrop: Int,
	rotateRight: Int,
	rotateLeft: Int,
	hold: Int,
}

@:publicFields class Const {

	static final TITLE = "The Roadtrip";

    static final MINO_COUNT = 7;
	static final NEXT_QUEUE_SIZE = 5;
	static final FIRST_TARGET_LINE = 12;
	static final TARGET_LINE_SPACING = 7;
	static final END_TARGET_SPACING = 8;
	static final TARGET_COL_MIN = 1;
	static final TARGET_COL_MAX = 3;
	static final SCROLL_LINE = 11; // dropping above this scrolls

    static final SIDE = 32;
    static final BOARD_WIDTH = 10;
	static final BOARD_HEIGHT = 20;
	static final BOARD_TOP_EXTRA = 3;
	static final BOARD_FULL_HEIGHT = BOARD_HEIGHT + BOARD_TOP_EXTRA;
	static final TRUCK_SPEED = SIDE * 1.8; // pixels per second
	static final TRUCK_LIGHTS_FREQUENCY = 3;

	static final ARR = 0.033;
	static final DAS = 0.15;

	static final ROAD_PULSE_FREQUENCY = 1;
	static final ROAD_PULSE_AMOUNT = 0.2;
	static final REGULAR_UPDATE_DT = 0.5;

	static final GRAVITY_PER_LEVEL = [
		0,
		0.01667,
		0.021017,
		0.026977,
		0.035256,
		0.04693,
		0.06361,
		0.0879,
		0.1236,
		0.1775,
		0.2598,
		0.388,
		0.59,
		0.92,
		1.46,
		2.36,
	];

	static final LOCK_DELAY = 0.5;
	static final LOCK_RESET_MAX = 10;
	static final ENTRY_DELAY = 0.06;

	static final wasdConfig: InputConfig = {
		left: K.Q,
		right: K.D,
		softDrop: K.S,
		hardDrop: K.W,
		rotateRight: K.RIGHT,
		rotateLeft: K.DOWN,
		hold: K.UP,
	};
	static final zqsdConfig: InputConfig = {
		left: K.Q,
		right: K.D,
		softDrop: K.S,
		hardDrop: K.Z,
		rotateRight: K.RIGHT,
		rotateLeft: K.DOWN,
		hold: K.UP,
	};
	static final baseConfig: InputConfig = {
		left: K.LEFT,
		right: K.RIGHT,
		softDrop: K.DOWN,
		hardDrop: K.SPACE,
		rotateRight: K.UP,
		rotateLeft: K.Z,
		hold: K.C,
	};
	static var config = #if debug zqsdConfig #else baseConfig #end;
}