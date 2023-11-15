package hrt.prefab.l3d;

enum MarkerSmoothing {
	Linear;
	Accelerate;
	Spline;
}

class InteriorPathMarker extends TorqueObject {
	@:s public var seqNum:Int;
	@:s public var msToNext:Int;
	@:c public var smoothingType:MarkerSmoothing;

	public var interiorPath:InteriorPath;

	var mesh:h3d.scene.Mesh;

	override function getEditorClassName():String {
		return "Marker";
	}

	override function makeInstance(ctx:Context):Context {
		ctx = ctx.clone(this);

		var obj = new h3d.scene.Object(ctx.local3d);

		mesh = new h3d.scene.Mesh(h3d.prim.Sphere.defaultUnitSphere(), null, obj);
		mesh.material.setDefaultProps("ui");
		mesh.material.color.set(0, 0, 1, 1);
		mesh.scale(0.2);

		ctx.local3d = obj;
		ctx.local3d.name = name;
		updateInstance(ctx);
		return ctx;
	}

	override function save() {
		var obj:Dynamic = super.save();
		obj.smoothingType = smoothingType.getIndex();
		return obj;
	}

	override function load(obj:Dynamic) {
		super.load(obj);
		smoothingType = obj.smoothingType == null ? Linear : MarkerSmoothing.createByIndex(obj.smoothingType);
	}

	override function applyTransform(o:h3d.scene.Object) {
		super.applyTransform(o);
		interiorPath.drawPath();
	}

	public function setColor(color:Int) {
		mesh.material.color.setColor(color);
	}

	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		var group = new hide.Element('
			<div class="group" name="Marker">
				<dl>
					<dt>Sequence Number</dt><dd><input type="number" field="seqNum"/></dd>
                    <dt>Time To Next</dt><dd><input type="number" field="msToNext"/></dd>
					<dt>Smoothing Type</dt>
                    <dd>
                   		<select field="smoothingType" >
							<option value="Linear">Linear</option>
							<option value="Accelerate">Accelerate</option>
                            <option value="Spline">Spline</option>
						</select>
                    </dd>
				</dl>
			</div>
		');

		ctx.properties.add(group, this, function(pname) {
			ctx.onChange(this, pname);
			interiorPath.drawPath();
		});

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "arrows-v", name: "Marker"};
	}
	#end

	static var _ = Library.register("marker", InteriorPathMarker);
}

class InteriorPath extends Object3D {
	public var markers:Array<InteriorPathMarker>;

	var g:h3d.scene.Graphics;

	#if editor
	public var editor:hide.prefab.PathEditor;
	#end

	public var pathedInterior:PathedInterior;

	override function makeInstance(ctx:Context):Context {
		markers = [];
		for (ch in this.children) {
			cast(ch, InteriorPathMarker).interiorPath = this;
			markers.push(cast ch);
		}

		ctx = ctx.clone(this);

		g = new h3d.scene.Graphics(ctx.local3d);
		g.lineStyle(4, 0xFFFFFFFF);
		g.material.mainPass.setPassName("overlay");
		g.material.mainPass.depth(false, LessEqual);

		ctx.local3d = g;
		ctx.local3d.name = "Path";
		updateInstance(ctx);

		drawPath();

		return ctx;
	}

	public function drawPath() {
		if (markers == null)
			return;
		markers.sort((a, b) -> a.seqNum - b.seqNum); // sort

		g.clear();

		var doLoop = false;
		if (pathedInterior != null && pathedInterior.pathType != Time)
			doLoop = true;

		for (i in 0...markers.length) {
			var startNode = i;
			var endNode = (i + 1) % markers.length;

			if (!doLoop && endNode == 0)
				break;

			var m1 = markers[startNode];
			var m2 = markers[endNode];

			if (m1.smoothingType == Spline) {
				var preStart = startNode - 1;
				var postEnd = endNode + 1;
				if (postEnd >= this.markers.length)
					postEnd = 0;
				if (preStart < 0)
					preStart = this.markers.length - 1;

				for (i in 0...12) {
					var interpolation = (i / 12.0);
					var position = new h3d.Vector();
					position.x = catmullRom(interpolation, this.markers[preStart].x, m1.x, m2.x, this.markers[postEnd].x);
					position.y = catmullRom(interpolation, this.markers[preStart].y, m1.y, m2.y, this.markers[postEnd].y);
					position.z = catmullRom(interpolation, this.markers[preStart].z, m1.z, m2.z, this.markers[postEnd].z);
					g.lineTo(position.x, position.y, position.z);
				}
			} else {
				g.moveTo(m1.x, m1.y, m1.z);
				g.lineTo(m2.x, m2.y, m2.z);
			}
		}
	}

	public function getTotalTime() {
		var t = 0;
		for (i in 0...(markers.length - 1)) {
			t += markers[i].msToNext;
		}
		return t;
	}

	static function catmullRom(t:Float, p0:Float, p1:Float, p2:Float, p3:Float) {
		var point = t * t * t * ((-1) * p0 + 3 * p1 - 3 * p2 + p3) / 2;
		point += t * t * (2 * p0 - 5 * p1 + 4 * p2 - p3) / 2;
		point += t * ((-1) * p0 + p2) / 2;
		point += p1;
		return point;
	}

	override function updateInstance(ctx:hrt.prefab.Context, ?propName:String) {
		super.updateInstance(ctx, propName);
		drawPath();
	}

	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		if (editor == null) {
			editor = new hide.prefab.PathEditor(this, ctx.properties.undo);
		}

		editor.editContext = ctx;
		editor.edit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "arrows-v", name: "Path"};
	}
	#end

	static var _ = Library.register("path", InteriorPath);
}
