
import hxd.Key as K;
using Extensions;
using Const;
using Main;

// TODO TOMORROW
// Menu principal + credits
// defeat condition
// gravity
// auto lock
// better generated pieces?
// garbage
// scroll
// next target when grab
// final goal
// le camion
// fog
// fix that L rotation on the rotation table

// for better generated pieces:
// generate all possibles during startup
// assign weight on number of exits and road types (4-roads should be rarer)

enum RandomMode {
	FullRandom;
	Bag;
}

class SceneObject extends h2d.Object implements h2d.domkit.Object {
	public function new(?parent) {
		super(parent);
		initComponent();
	}
}

class SceneBitmap extends h2d.Bitmap implements h2d.domkit.Object {
	public function new(?tile : h2d.Tile, ?parent : h2d.Object) {
		super(tile, parent);
		initComponent();
	}
}

@:uiComp("board-ui")
class BoardUI extends h2d.Flow implements h2d.domkit.Object {
    static var SRC = <board-ui
		fill-width={true}
		content-halign={h2d.Flow.FlowAlign.Middle}
		spacing={{x: 10, y: 0}}
	>
		<flow class="left-cont"
			margin-top={topMargin}
			fill-height={true}
			layout={h2d.Flow.FlowLayout.Vertical}
			valign={h2d.Flow.FlowAlign.Top}
			spacing={{x: 0, y: pad}}
			height={boardHeight}
		>
			<flow class="hold-cont" id
				valign={h2d.Flow.FlowAlign.Top}
				background={panelBG}
				padding={padding}
				layout={h2d.Flow.FlowLayout.Vertical}
				content-halign={h2d.Flow.FlowAlign.Middle}
				spacing={{x: 0, y: pad}}
			>
				<text text={"HOLD"}/>
				<flow id="currHold" public
					min-width={pieceWidth}
					min-height={pieceHeight}
					offset-x={Const.SIDE}
				/>
			</flow>
			<flow class="score-cont" id
				valign={h2d.Flow.FlowAlign.Middle}
				background={panelBG}
				padding={padding}
				layout={h2d.Flow.FlowLayout.Vertical}
				content-halign={h2d.Flow.FlowAlign.Right}
				spacing={{x: 0, y: 15}}
				min-width={168}
				min-height={140}
			>
				<text id="score"/>
				<flow id="animalsCont"
					spacing={{x: 15, y: 0}}
					valign={h2d.Flow.FlowAlign.Bottom}
				/>
			</flow>
		</flow>
		<flow class="board-cont" id public/>
		<flow class="next-cont" id
			valign={h2d.Flow.FlowAlign.Top}
			background={panelBG}
			margin-top={topMargin}
			padding={padding}
			spacing={{x: 0, y: pad}}
			layout={h2d.Flow.FlowLayout.Vertical}
			content-halign={h2d.Flow.FlowAlign.Middle}
		>
			<text text={"NEXT"}/>
			${for (i in 0...Const.NEXT_QUEUE_SIZE) {
				<flow id="nextPieces[]" public
					min-width={pieceWidth}
					min-height={pieceHeight}
					offset-x={Const.SIDE}
				/>
			}}
		</flow>
	</board-ui>

    public function new(?parent) {
		super(parent);
		var panelBG = {
			tile : hxd.Res.panel_bg.toTile(),
			borderL : 4,
			borderT : 4,
			borderR : 4,
			borderB : 4,
		};

		var topMargin = Const.BOARD_TOP_EXTRA * Const.SIDE - 3;
		var pieceWidth = 4 * Const.SIDE;
		var pieceHeight = 2 * Const.SIDE;
		var pad = 20;
		var padding = {
			top: pad,
			right: pad,
			bottom: pad - 1, // mod 4
			left: pad,
		};
		var boardHeight = Const.BOARD_HEIGHT * Const.SIDE;

		initComponent();
		holdCont.background.tileCenter = true;
		nextCont.background.tileCenter = true;
		scoreCont.background.tileCenter = true;
		holdCont.background.tileBorders = true;
		nextCont.background.tileBorders = true;
		scoreCont.background.tileBorders = true;

		setScore(0);
	}

	public function setScore(v: Int) {
		score.text = 'SCORE: $v';
	}
	public function setAnimals(arr: Array<Data.Animal>) {
		animalsCont.removeChildren();
		for (a in arr) {
			new SceneBitmap(a.gfx.toTile(), animalsCont);
		}
	}
}

class RandomProvider {
	var rnd: hxd.Rand;
	var mode: RandomMode;
	var max = Const.MINO_COUNT;
	var all: Array<Int>;
	var currBag: Array<Int> = [];

	public function new(rnd, mode) {
		this.rnd = rnd;
		this.mode = mode;
		all = [for (i in 0...max) i];
	}

	public function getNext() {
		switch (mode) {
			case FullRandom:
				return rnd.random(max);
			case Bag:
				if (currBag.isEmpty()) {
					for (i in all)
						currBag.push(i);
				}
				var ret = currBag[rnd.random(currBag.length)];
				currBag.remove(ret);
				return ret;
		}
	}
}

class Block {
	public var x: Int;
	public var y: Int;
	public var obj: SceneObject;
	var bg: SceneBitmap;
	var roadBmp: SceneBitmap;
	public var inf(default, set): Data.Mino;
	public var rotation: Direction = Up;
	//					top	   right  bottom left
	public var roads = [false, false, false, false];

	public var on = false;
	public var phantomOn = false;
	public var isPhantom = false;
	public var isEmpty = false;
	public var phantomAddColor = new h3d.Vector();


	public function new(x, y, inf: Data.Mino, isPhantom=false, ?parent) {
		this.isPhantom = isPhantom;
		obj = new SceneObject(parent);
		bg = new SceneBitmap(inf.gfx.toTile(), obj);
		bg.dom.addClass("block-bg");
		roadBmp = new SceneBitmap(null, obj);
		roadBmp.colorAdd = phantomAddColor;
		roadBmp.dom.addClass("road");
		this.inf = inf;
		this.on = alwaysOn();
		this.phantomOn = alwaysOn();
		this.isEmpty = inf.flags.has(Empty);

		obj.dom.addClass("block");
		this.x = x;
		this.y = y;
		updatePos();
	}

	function set_inf(v) {
		bg.tile = v.gfx.toTile();
		if (isPhantom)
			bg.tile = v.phantom.toTile();
		roadBmp.tile = null;
		if (v.flags.has(AllRoads))
			roads = [true, true, true, true];
		return inf = v;
	}

	public function updatePos(sides = false) {
		var offs = (sides && inf.props.sideOffset != null) ? inf.props.sideOffset : 0.;
		obj.x = (x + offs) * Const.SIDE;
		obj.y = (y + 1) * Const.SIDE * -1;

		var roadInf = (inf.flags.has(HideRoads)) ? null : Data.road.all.find(function(r) {
			for (i in 0...roads.length) {
				if (r.match[i].v != hasDir(i))
					return false;
			}
			return true;
		});
		if (roadInf != null)
			roadBmp.tile = (on || phantomOn) ? roadInf.activeGfx.toTile() : roadInf.gfx.toTile();
		if (!phantomOn || on) {
			phantomAddColor.set(0, 0, 0);
			effectElapsed = 0;
		}
		roadBmp.visible = roadInf != null;
		if (isPhantom) {
			trace("getting a road", roadInf?.id, "at", obj.x, obj.y, roadBmp.tile == null);
		}
	}

	public function hasDir(i: Direction) {
		i = i.rotateBy(-rotation);
		return roads[i];
	}

	public function alwaysOn() {
		return inf.flags.has(AlwaysOn);
	}

	var effectElapsed = 0.;
	public function update(dt: Float) {
		if (phantomOn && !on) {
			effectElapsed += dt;
			var v = Const.ROAD_PULSE_AMOUNT * ((1 + hxd.Math.sin(effectElapsed * Const.ROAD_PULSE_FREQUENCY * 2 * hxd.Math.PI)) / 2);
			phantomAddColor.set(v, v, v);
		}
	}
}

class Piece {
	public var obj: SceneObject;
	public var blocks: Array<Block> = [];
	public var x: Int;
	public var y: Int;
	public var inf: Data.Mino;
	public var rotation: Direction = Up;
	public var follow: Piece = null;

	function fToString(v: Float, prec=5) {
		var p = Math.pow(10, prec);
		var val = Math.round(p * v);
		var fullDec = Std.string(val);
		var outStr = fullDec.substr(0, -prec) + '.' + fullDec.substr(fullDec.length - prec, prec);
		return outStr;
	}

	public function new(?i: Int, ?follow: Piece, ?parent) {
		obj = new SceneObject(parent);
		this.follow = follow;
		if (follow != null) {
			inf = follow.inf;
			obj.dom.addClass("phantom");
			blocks = [for (b in inf.blocks) new Block(b.x, b.y, inf, true, obj)];
		} else {
			inf = Data.mino.all[i];
			blocks = [for (b in inf.blocks) new Block(b.x, b.y, inf, obj)];
			if (Const.USE_DEFAULT_ROADS) {
				for (i in 0...inf.blocks.length) {
					var rds = inf.blocks[i].defaultRoads.match;
					for (j in 0...4) {
						blocks[i].roads[j] = rds[j].v;
					}
				}
			} else {
				var stamp = haxe.Timer.stamp();
				shuffleRoads();
				var tries = 0;
				while (!areRoadsValid()) {
					tries++;
					shuffleRoads();
					if (tries > 2000) {
						iterateRec(0, 0, areRoadsValid);
						break;
					}
				}
				var elapsed = haxe.Timer.stamp() - stamp;
				var elapsedStr = fToString(elapsed);
				if (tries > 2000)
					trace("TOOK ALL TRIES, FALLBACK");
				trace('Block ${inf.id} took $tries tries to find ($elapsedStr, $elapsed s). Valid: ${areRoadsValid()}');
			}
		}
		obj.dom.addClass(inf.id.toString().toLowerCase());

		// tryAll();

	}

	public function reset() {
		x = 4;
		y = Const.BOARD_HEIGHT - 1;
		rotation = 0;
		for (i in 0...blocks.length) {
			var b = blocks[i];
			b.rotation = rotation;
			b.x = inf.blocks[i].x;
			b.y = inf.blocks[i].y;
		}
		updatePos();
	}

	public function savePos() {
		return {
			prevBlocks: [for (b in blocks) {x: b.x, y: b.y}],
			prevPos: {x: x, y: y},
			prevRotation: rotation,
		};
	}
	public function loadPos(save) {
		x = save.prevPos.x;
		y = save.prevPos.y;
		for (i in 0...save.prevBlocks.length) {
			blocks[i].x = save.prevBlocks[i].x;
			blocks[i].y = save.prevBlocks[i].y;
			blocks[i].rotation = save.prevRotation;
		}
		rotation = save.prevRotation;
	}

	var pivotG = null;
	public function updatePos(sides = false) {
		if (follow != null) {
			this.x = follow.x;
			this.inf = follow.inf;
			this.rotation = follow.rotation;
			for (i in 0...blocks.length) {
				var fromb = follow.blocks[i];
				var tob = blocks[i];
				tob.x = fromb.x;
				tob.y = fromb.y;
				tob.rotation = fromb.rotation;
				tob.roads = fromb.roads; // TODO could break
			}
		} else {
			#if debug
			// if (pivotG == null)
			// 	pivotG = new h2d.Graphics(obj);
			// var px = inf.pivot.x;
			// var py = inf.pivot.y;
			// pivotG.clear();
			// pivotG.lineStyle(2, 0x00FF40);
			// pivotG.drawCircle(Const.SIDE * (px + 0.5), Const.SIDE * (-py - 0.5), 10);
			#end
		}
		for (b in blocks)
			b.updatePos(sides);
		obj.x = x * Const.SIDE;
		obj.y = y * Const.SIDE * -1;
	}

	public function rotate(ccw: Bool) {
		var px = inf.pivot.x;
		var py = inf.pivot.y;
		for (b in blocks) {
			var dx = b.x - px;
			var dy = b.y - py;
			var nx;
			var ny;
			if (ccw) {
				nx = Math.round(-dy + px);
				ny = Math.round(dx + py);
			} else {
				nx = Math.round(dy + px);
				ny = Math.round(-dx + py);
			}
			b.x = nx;
			b.y = ny;
		}

		rotation = rotation.rotateBy(ccw ? -1 : 1);
		for (b in blocks) {
			b.rotation = rotation;
		}
	}

	function shuffleRoads() {
		inline function randBool() {
			return Board.rnd.random(2) == 0;
		}
		for (b in blocks) {
			for (i in 0...4) {
				b.roads[i] = randBool();
			}
		}
	}

	function iterateRec(bi: Int, ri: Int, callb: Void -> Bool) {
		inline function iterNext() {
			return if (ri < 3) {
				iterateRec(bi, ri + 1, callb);
			} else if (bi < 3) {
				iterateRec(bi + 1, 0, callb);
			} else {
				callb();
			}
			// return false;
		}
		blocks[bi].roads[ri] = false;
		if (iterNext())
			return true;
		blocks[bi].roads[ri] = true;
		if (iterNext())
			return true;
		return false;
	}

	function tryAll() {
		var stamp = haxe.Timer.stamp();
		var valids = 0;
		var invalids = 0;
		var tries = 0;
		iterateRec(0, 0, function() {
			if (areRoadsValid())
				valids++;
			else
				invalids++;
			tries++;
			return false;
		});
		var elapsed = haxe.Timer.stamp() - stamp;
		var elapsedStr = fToString(elapsed);
		trace('Block ${inf.id} valid: $valids invalid: $invalids elapsed: ($elapsedStr) $elapsed s (total $tries)');
	}

	function checkRec(curr: Block, toCheck: Array<Block>, exits: Array<Array<Bool>>) {
		toCheck.remove(curr);
		var currIdx = blocks.indexOf(curr);
		for (k in 0...4) {
			var r: Direction = k;
			if (!curr.hasDir(r))
				continue;
			var i = curr.x;
			var j = curr.y;
			switch (r) {
				case Up: 	j++;
				case Right:	i++;
				case Down:	j--;
				case Left:	i--;
			}
			var to = blocks.find(b -> b.x == i && b.y == j);
			if (to == null) {
				exits[currIdx][k] = true;
			} else {
				// unterminated road inside
				if (!to.hasDir(r.rotateBy(2)))
					return false;
				if (toCheck.has(to)) {
					var check = checkRec(to, toCheck, exits);
					if (!check)
						return false;
				}
			}
		}
		return true;
	}
	public function areRoadsValid() {
		var roadedBlocks = blocks.filter(b -> b.roads.count(r -> r) > 0);
		if (roadedBlocks.length < Const.MIN_ROADED_PER_PIECE)
			return false;
		if (roadedBlocks.any(b -> b.roads.count(r -> r) == 1))
			return false;
		var toCheck = roadedBlocks.copy();
		var exits = [for (i in 0...blocks.length) [for (i in 0...4) false]];
		var check = checkRec(toCheck[0], toCheck, exits);
		if (!check)
			return false;
		if (toCheck.length > 0) // unconnected block inside
			return false;
		var separateExitSets = 0;
		var exitBlocks = 0;
		for (i in 0...exits.length) {
			var hasExit = false;
			for (j in 0...exits[i].length) {
				if (exits[i][j]) {
					if (!hasExit) {
						exitBlocks++;
						hasExit = true;
					}

					for (i2 in (i + 1)...exits.length) {
						for (j2 in 0...exits[i2].length) {
							if (j2 == j)
								continue;
							if (exits[i2][j2])
								separateExitSets++;
						}
					}
				}
			}
		}
		if (separateExitSets < Const.MIN_SEPARATE_EXITS)
			return false;
		if (exitBlocks > Const.MAX_EXIT_BLOCKS || exitBlocks < Const.MIN_EXIT_BLOCKS)
			return false;

		return true;
	}

	public function update(dt: Float) {
		for (b in blocks)
			b.update(dt);
	}
}


class Board {

	public var gridCont : SceneObject;
	var gridGraphics : h2d.Graphics;
	var boardObj : SceneObject;
	var lockedObj : SceneObject;
	var phantomCont : SceneObject;
	var tf : h2d.Text;
	var fullUi : BoardUI;

	// 0, 0 is bottom LEFT
	var board: Array<Array<Block>> = [];
	var current: Piece = null;
	var phantom: Piece = null;
	var hold: Piece = null;
	var nextQueue: Array<Piece> = [];

	var targets: Array<Block> = [];
	var allTargets: Array<Block> = [];
	var animals: Array<Data.Animal> = [];

	var seed = Std.random(0x7FFFFFFF);
	public static var rnd: hxd.Rand;
	var bag: RandomProvider;
	public static var style : h2d.domkit.Style;

	public function new() {}

	public function init(s2d: h2d.Scene) {
		var cdbData = hxd.Res.data.entry.getText();
		Data.load(cdbData, false);
		hxd.Res.data.watch(function() {
			var cdbData = hxd.Res.data.entry.getText();
			Data.load(cdbData, true);
		});

		fullUi = new BoardUI(s2d);

		trace("Seed: " + seed);
		rnd = new hxd.Rand(seed);
		bag = new RandomProvider(rnd, Bag);
		// creates a new object and put it at the center of the sceen
		gridCont = new SceneObject(fullUi.boardCont);

		style = new h2d.domkit.Style();
		style.allowInspect = #if debug true #else false #end;
		style.addObject(gridCont);
		gridCont.dom.addClass("root");
		// gridCont.dom = domkit.Properties.create("object", gridCont, {"class": "root"});

		gridGraphics = new h2d.Graphics(gridCont);
		drawGrid(gridGraphics);
		boardObj = new SceneObject(gridCont);
		boardObj.dom.addClass("board");
		boardObj.y = Const.BOARD_FULL_HEIGHT * Const.SIDE;
		lockedObj = new SceneObject(boardObj);
		phantomCont = new SceneObject(boardObj);
		clearBoard();
	}

	function drawGrid(g: h2d.Graphics) {
		g.clear();

		g.lineStyle(2, 0xF8DCC1);
		g.moveTo(0, Const.BOARD_TOP_EXTRA * Const.SIDE);
		g.lineTo(0, (Const.BOARD_HEIGHT + Const.BOARD_TOP_EXTRA) * Const.SIDE);
		g.lineTo(Const.BOARD_WIDTH * Const.SIDE, (Const.BOARD_HEIGHT + Const.BOARD_TOP_EXTRA) * Const.SIDE);
		g.lineTo(Const.BOARD_WIDTH * Const.SIDE, Const.BOARD_TOP_EXTRA * Const.SIDE);
		g.lineTo(0, Const.BOARD_TOP_EXTRA * Const.SIDE);

		g.lineStyle(1, 0xF8DCC1);
		for (i in 1...Const.BOARD_WIDTH) {
			g.moveTo(i * Const.SIDE, Const.BOARD_TOP_EXTRA * Const.SIDE);
			g.lineTo(i * Const.SIDE, Const.BOARD_FULL_HEIGHT * Const.SIDE);
		}
		for (i in 1...Const.BOARD_HEIGHT) {
			g.moveTo(0, (i + Const.BOARD_TOP_EXTRA) * Const.SIDE);
			g.lineTo(Const.BOARD_WIDTH * Const.SIDE, (i + Const.BOARD_TOP_EXTRA) * Const.SIDE);
		}
		g.lineStyle();
	}

	function blockIsEmpty(x, y) {
		return board[x][y] == null || board[x][y].isEmpty;
	}

	function fillNext() {
		for (_ in nextQueue.length...Const.NEXT_QUEUE_SIZE) {
			nextQueue.push(new Piece(bag.getNext()));
		}
		for (i in 0...Const.NEXT_QUEUE_SIZE) {
			fullUi.nextPieces[i].removeChildren();
			fullUi.nextPieces[i].addChild(nextQueue[i].obj);
			nextQueue[i].updatePos(true);
		}
	}
	function nextMino(?remove = true) {
		if (current != null && remove)
			current.obj.remove();
		current = nextQueue.shift();
		boardObj.addChild(current.obj);
		current.reset();
		fillNext();
		updateConnections();
	}
	function collides(m: Piece, offsetx = 0, offsety = 0) {
		for (b in m.blocks) {
			var x = b.x + m.x + offsetx;
			var y = b.y + m.y + offsety;
			if (x < 0 || x >= board.length || y < 0)
				return true;
			if (!blockIsEmpty(x, y))
				return true;
		}
		return false;
	}
	function lockCurrent(m: Piece) {
		for (b in m.blocks) {
			var x = b.x + m.x;
			var y = b.y + m.y;
			if (board[x][y] != null) {
				board[x][y].obj.remove();
			}
			board[x][y] = b;
			lockedObj.addChild(b.obj);
			b.x = x;
			b.y = y;
			b.updatePos();
		}
	}
	function getHardDropDiff() {
		var prev = 0;
		for (i in 1...(current.y + 1)) {
			if (collides(current, 0, -i)) {
				break;
			}
			prev = i;
		}
		return prev;
	}
	function hardDrop() {
		current.y -= getHardDropDiff();
		lockCurrent(current);
		nextMino();
	}
	function rotate(ccw: Bool) {
		var initial = current.savePos();
		var from = current.rotation;
		current.rotate(ccw);
		var to = current.rotation;
		var r = current.inf.rotation.rotate.find(r -> r.from == from && r.to == to);
		var found = false;
		for (t in r.tests) {
			var inter = current.savePos();
			current.x += t.x;
			current.y += t.y;
			if (collides(current)) {
				current.loadPos(inter);
			} else {
				found = true;
				break;
			}
		}
		if (found)
			current.updatePos();
		else
			current.loadPos(initial);
		updateConnections();
	}

	function swapHold() {
		if (hold == null) {
			hold = current;
			nextMino(false);
		} else {
			var a = hold;
			hold = current;
			current = a;
			current.reset();
			boardObj.addChild(current.obj);
		}
		hold.reset();
		hold.x = 0;
		hold.y = 0;
		hold.updatePos(true);
		fullUi.currHold.addChild(hold.obj);
		updateConnections();
	}


	function clearBoard() {
		for (i in 0...board.length) {
			for (j in 0...board[i].length) {
				if (board[i][j] != null)
					board[i][j].obj.remove();
			}
		}
		if (current != null)
			current.obj.remove();

		board = [for (i in 0...Const.BOARD_WIDTH) [
			for (j in 0...Const.BOARD_FULL_HEIGHT) {
				if (j >= Const.BOARD_HEIGHT) null
				else new Block(i, j, Data.mino.get(Background), lockedObj);
			}
		]];
		fillNext();
		nextMino();
		if (hold != null)
			hold.obj.remove();
		hold = null;

		var source = new Block(4, 0, Data.mino.get(SourceL), lockedObj);
		board[4][0].obj.remove();
		board[4][0] = source;
		source = new Block(5, 0, Data.mino.get(SourceR), lockedObj);
		board[5][0].obj.remove();
		board[5][0] = source;
		animals = [];
		fullUi.setScore(animals.length);
		fullUi.setAnimals(animals);

		targets.clear();
		allTargets.clear();
		spawnTarget();
		updateConnections();
	}

	function spawnTarget() {
		var y = Const.FIRST_TARGET_LINE;
		var side = false; // true is left, false is right
		if (!allTargets.isEmpty()) {
			var prev = allTargets.last();
			y = prev.y + Const.TARGET_LINE_SPACING;
			side = Const.BOARD_WIDTH < 5;
		} else {
			side = rnd.random(2) == 0;
		}
		var col = rnd.random(Const.TARGET_COL_MAX - Const.TARGET_COL_MIN) + Const.TARGET_COL_MIN;
		var x = side ? col : Const.BOARD_WIDTH - col - 1;
		var t = new Block(x, y, Data.mino.get(Target), lockedObj);
		if (board[x][y] != null)
			board[x][y].obj.remove();
		board[x][y] = t;
		targets.push(t);
		allTargets.push(t);
	}

	function fillRec(x: Int, y: Int, forPhantom = false) {
		function getAt(x: Int, y: Int) {
			if (!blockIsEmpty(x, y))
				return board[x][y];
			if (!forPhantom)
				return null;
			return phantom.blocks.find(e -> e.x == x && e.y == y);
		}
		var b = getAt(x, y);
		for (k in 0...4) {
			var r: Direction = k;
			var i = b.x;
			var j = b.y;
			switch (r) {
				case Up: 	j++;
				case Right:	i++;
				case Down:	j--;
				case Left:	i--;
			}
			if (i < 0 || i >= Const.BOARD_WIDTH || j < 0 || j >= Const.BOARD_FULL_HEIGHT)
				continue;
			var curr = getAt(i, j);
			if (curr == null)
				continue;
			if (!b.hasDir(r) || curr.on || !curr.hasDir(r.rotateBy(2)) || (forPhantom && curr.phantomOn))
				continue;
			if (forPhantom)
				curr.phantomOn = true;
			else
				board[i][j].on = true;
			fillRec(i, j, forPhantom);
		}
	}
	function fillPhantom() {
		var starts = [];
		for (b in phantom.blocks) {
			b.phantomOn = false;
			b.x += phantom.x;
			b.y += phantom.y;
		}
		for (b in phantom.blocks) {
			for (k in 0...4) {
				var r: Direction = k;
				var i = b.x;
				var j = b.y;
				switch (r) {
					case Up: 	j++;
					case Right:	i++;
					case Down:	j--;
					case Left:	i--;
				}
				if (i < 0 || i >= Const.BOARD_WIDTH || j < 0 || j >= Const.BOARD_FULL_HEIGHT)
					continue;
				if (blockIsEmpty(i, j))
					continue;
				if (!b.hasDir(r) || !board[i][j].on || !board[i][j].hasDir(r.rotateBy(2)))
					continue;
				b.phantomOn = true;
				starts.push(b);
				break;
			}
		}
		for (s in starts) {
			fillRec(s.x, s.y, true);
		}
		for (b in phantom.blocks) {
			b.x -= phantom.x;
			b.y -= phantom.y;
		}
	}
	function updateConnections() {
		var starts = [];
		for (i in 0...board.length) {
			for (j in 0...board[i].length) {
				if (!blockIsEmpty(i, j)) {
					if (board[i][j].alwaysOn()) {
						starts.push(board[i][j]);
					} else {
						board[i][j].on = false;
						board[i][j].phantomOn = false;
					}
				}
			}
		}
		for (s in starts)
			fillRec(s.x, s.y);

		if (phantom != null && phantom.follow != current) {
			phantom.obj.remove();
			phantom = new Piece(current, phantomCont);
		}
		if (phantom == null)
			phantom = new Piece(current, phantomCont);
		phantom.y = current.y - getHardDropDiff();
		phantom.updatePos();
		fillPhantom();
		phantom.updatePos();

		for (i in 0...board.length) {
			for (j in 0...board[i].length) {
				if (board[i][j] != null) {
					board[i][j].updatePos();
				}
			}
		}
		for (t in targets) {
			if (t.on) {
				targets.remove(t);
				t.inf = Data.mino.get(TargetObtained);
				animals.push(Data.animal.all[rnd.random(Data.animal.all.length)]);
			}
		}
		fullUi.setScore(animals.length);
		fullUi.setAnimals(animals);
	}

	function move(by: Int) {
		if (!collides(current, by, 0)) {
			current.x += by;
			current.updatePos();
			updateConnections();
		}
	}

	function updateMove(dt: Float) {
		static var prevDir = 0;
		static var hasDas = false;
		static var accum = 0.;
		var dir = 0;
		if (K.isDown(Const.config.right))
			dir++;
		if (K.isDown(Const.config.left))
			dir--;

		if (K.isPressed(Const.config.right)) {
			move(1);
			hasDas = false;
			accum = 0;
			prevDir = 1;
		}
		if (K.isPressed(Const.config.left)) {
			move(-1);
			hasDas = false;
			accum = 0;
			prevDir = -1;
		}
		if (dir != 0) {
			accum += dt;
			if ((hasDas && accum >= Const.ARR) || (!hasDas && accum >= Const.DAS)) {
				hasDas = true;
				move(dir);
			}
		}
	}
	function updateSoftDrop(dt: Float) {
		static var accum = 0.;
		if (K.isDown(Const.config.softDrop)) {
			if (accum == 0 || accum > Const.SD_DELAY)
				softDrop();
			accum += dt;
		} else
			accum = 0;
	}
	function softDrop() {
		if (!collides(current, 0, -1)) {
			current.y -= 1;
			current.updatePos();
		}
	}
	public function update(dt:Float) {
		if (K.isPressed(K.R)) {
			clearBoard();
		}
		if (K.isPressed(Const.config.hardDrop)) {
			hardDrop();
		}
		if (K.isPressed(Const.config.rotateRight)) {
			rotate(false);
		}
		if (K.isPressed(Const.config.rotateLeft)) {
			rotate(true);
		}
		if (K.isPressed(Const.config.hold)) {
			swapHold();
		}
		updateSoftDrop(dt);
		updateMove(dt);
		current.update(dt);
		phantom.update(dt);
		for (col in board) {
			for (block in col) {
				if (block != null)
					block.update(dt);
			}
		}

		#if debug
		if (K.isPressed(K.M)) {
			current.areRoadsValid();
		}
		#end
	}
}