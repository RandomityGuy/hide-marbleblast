package hrt.prefab.l3d;

import h3d.Vector;
import h3d.Matrix;

enum PathedInteriorPathType {
	Time;
	Loop;
	LoopReverse;
}

class PathedInterior extends TorqueObject {
	@:s public var path:String;
	@:s public var so:Int;

	@:c public var pathType:PathedInteriorPathType = Time;
	@:s public var initialTargetPosition:Int;
	@:s public var initialPathPosition:Int;

	var innerMesh:h3d.scene.Object;
	var ctxObject:h3d.scene.Object;

	var pathObj:InteriorPath;

	public override function loadFromPath(p:String) {
		path = p;
		return true;
	}

	override function getEditorClassName():String {
		return "PathedInterior";
	}

	override function save() {
		var obj:Dynamic = super.save();
		obj.pathType = pathType.getIndex();
		return obj;
	}

	override function load(obj:Dynamic) {
		super.load(obj);
		pathType = obj.pathType == null ? Time : PathedInteriorPathType.createByIndex(obj.pathType);
	}

	override function makeInstance(ctx:Context):Context {
		if (path != null) {
			ctx = ctx.clone(this);

			ctxObject = new h3d.scene.Object(ctx.local3d);
			var mesh = new h3d.scene.Object(ctxObject);

			hrt.dif.DifBuilder.loadDif(path, mesh, so); // new h3d.scene.Mesh(h3d.prim.Cube.defaultUnitCube(), ctx.local3d);

			innerMesh = mesh;

			ctx.local3d = ctxObject;
			ctx.local3d.name = name;
			updateInstance(ctx);
		}
		return ctx;
	}

	override function updateInstance(ctx:hrt.prefab.Context, ?propName:String) {
		super.updateInstance(ctx, propName);
		if (this.parent is SimGroup && pathObj == null) {
			// find the Path
			for (ch in this.parent.children) {
				if (ch is InteriorPath) {
					var p:InteriorPath = cast ch;
					p.pathedInterior = this;
					this.pathObj = p;
					this.pathObj.updateInstance(ctx);
					break;
				}
			}
		}
	}

	#if editor
	override function removeInstance(ctx:Context):Bool {
		if (this.pathObj != null) {
			if (this.pathObj.pathedInterior == this) {
				this.pathObj.pathedInterior = null;
				this.pathObj.updateInstance(ctx);
				this.pathObj = null;
			}
		}
		return super.removeInstance(ctx);
	}
	#end

	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		var group = new hide.Element('
			<div class="group" name="Pathed Interior">
				<dl>
					<dt>File</dt><dd><input type="text" field="path" /></dd>
					<dt>Sub Object</dt><dd><input type="number" field="so" /></dd>
					<dt>Initial Target</dt>
                    <dd>
                   		<select field="pathType" >
							<option value="Time">Time</option>
							<option value="Loop">Loop</option>
                            <option value="LoopReverse">Reverse Loop</option>
						</select>
                    </dd>
					<div class="targetPosition">
						<dt>Initial Target Position</dt><dd><input type="text" field="initialTargetPosition" /></dd>
					</div>
					<dt>Initial Path Position</dt><dd><input type="text" field="initialPathPosition" /></dd>
				</dl>
			</div>
		');

		var tpos = group.find(".targetPosition");

		switch (pathType) {
			case Time:
				tpos.show();
			case Loop | LoopReverse:
				tpos.hide();
		}

		ctx.properties.add(group, this, function(pname) {
			ctx.onChange(this, pname);

			if (pname == "pathType") {
				switch (pathType) {
					case Time:
						initialTargetPosition = 0;
						tpos.show();
					case Loop:
						initialTargetPosition = -1;
						tpos.hide();
					case LoopReverse:
						initialTargetPosition = -2;
						tpos.hide();
				}

				this.pathObj.drawPath();
			}

			if (pname == "path" || pname == "so") {
				var prevChildren = [];
				for (ch in innerMesh)
					prevChildren.push(ch);

				innerMesh.removeChildren();
				try {
					hrt.dif.DifBuilder.loadDif(path, innerMesh, so); // new h3d.scene.Mesh(h3d.prim.Cube.defaultUnitCube(), ctx.local3d);
				} catch (e:Dynamic) {
					// if an error occurs, re-add previous children
					for (ch in prevChildren)
						innerMesh.addChild(ch);
				}
			}
		});

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "cube", name: "PathedInterior", fileSource: ["dif"]};
	}
	#end

	override function tick(ctx:Context, elapsedTime:Float, dt:Float) {
		super.tick(ctx, elapsedTime, dt);
		var mat = getTransformAtTime(getLocalTime(elapsedTime));
		innerMesh.setTransform(mat);
	}

	function getLocalTime(t:Float) {
		switch (pathType) {
			case Time:
				return hxd.Math.max(initialPathPosition / 1000.0 + t, 0);
			case Loop:
				return (initialPathPosition / 1000.0 + t) % (pathObj.getTotalTime() / 1000.0);
			case LoopReverse:
				var t2 = initialPathPosition / 1000.0 + t;
				return adjustedMod(t2 - pathObj.getTotalTime() / 1000.0, (pathObj.getTotalTime() / 1000.0));
		}
	}

	static function adjustedMod(a:Float, n:Float) {
		return ((a % n) + n) % n;
	}

	function getTransformAtTime(time:Float) {
		var m1 = pathObj.markers[0];
		var m2 = pathObj.markers[1];
		if (m1 == null) {
			// Incase there are no markers at all
			var tmp = new Matrix();
			return tmp;
		}
		// Find the two markers in question
		var currentEndTime = m1.msToNext / 1000.0;
		var i = 2;
		while (currentEndTime < time && i < pathObj.markers.length) {
			m1 = m2;
			m2 = pathObj.markers[i++];

			currentEndTime += m1.msToNext / 1000.0;
		}
		if (m2 == null)
			m2 = m1;
		// if (i == pathObj.markers.length && currentEndTime < time) { // MBU Timings
		// 	m1 = m2;
		// 	m2 = pathObj.markers[0];
		// 	currentEndTime += m1.msToNext / 1000.0;
		// }

		var m1Time = currentEndTime - m1.msToNext / 1000.0;
		var m2Time = currentEndTime;
		var duration = m2Time - m1Time;
		var position:Vector = null;
		var compvarion = hxd.Math.clamp(duration != 0 ? (time - m1Time) / duration : 1, 0, 1);
		if (m1.smoothingType == Accelerate) {
			// A simple easing function
			compvarion = Math.sin(compvarion * Math.PI - (Math.PI / 2)) * 0.5 + 0.5;
		} else if (m1.smoothingType == Spline) {
			// Smooth the path like it's a Catmull-Rom spline.
			var preStart = (i - 2) - 1;
			var postEnd = (i - 1) + 1;
			if (postEnd >= pathObj.markers.length)
				postEnd = 0;
			if (preStart < 0)
				preStart = pathObj.markers.length - 1;
			var p0 = new Vector(pathObj.markers[preStart].x, pathObj.markers[preStart].y, pathObj.markers[preStart].z);
			var p1 = new Vector(m1.x, m1.y, m1.z);
			var p2 = new Vector(m2.x, m2.y, m2.z);
			var p3 = new Vector(pathObj.markers[postEnd].x, pathObj.markers[postEnd].y, pathObj.markers[postEnd].z);
			position = new Vector();
			position.x = catmullRom(compvarion, p0.x, p1.x, p2.x, p3.x);
			position.y = catmullRom(compvarion, p0.y, p1.y, p2.y, p3.y);
			position.z = catmullRom(compvarion, p0.z, p1.z, p2.z, p3.z);
		}
		if (position == null) {
			var p1 = new Vector(m1.x, m1.y, m1.z);
			var p2 = new Vector(m2.x, m2.y, m2.z);
			position = p1.add(p2.sub(p1).multiply(compvarion));
		}
		// Offset by the position of the first marker
		var firstPosition = new Vector(pathObj.markers[0].x, pathObj.markers[0].y, pathObj.markers[0].z);
		position = position.sub(firstPosition);

		var mat = innerMesh.getTransform().clone();
		mat.setPosition(position);

		return mat;
	}

	static function catmullRom(t:Float, p0:Float, p1:Float, p2:Float, p3:Float) {
		var point = t * t * t * ((-1) * p0 + 3 * p1 - 3 * p2 + p3) / 2;
		point += t * t * (2 * p0 - 5 * p1 + 4 * p2 - p3) / 2;
		point += t * ((-1) * p0 + p2) / 2;
		point += p1;
		return point;
	}

	override function getRenderTransform() {
		return innerMesh.getAbsPos();
	}

	static var _ = Library.register("pathedinterior", PathedInterior);
}
