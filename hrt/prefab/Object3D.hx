package hrt.prefab;

import hxd.Math;
import h3d.Quat;

using Lambda;

class Object3D extends Prefab {
	@:s public var x:Float = 0.;
	@:s public var y:Float = 0.;
	@:s public var z:Float = 0.;
	@:s public var scaleX:Float = 1.;
	@:s public var scaleY:Float = 1.;
	@:s public var scaleZ:Float = 1.;
	@:s public var rotationX:Float = 0.;
	@:s public var rotationY:Float = 0.;
	@:s public var rotationZ:Float = 0.;
	@:s public var rotationW:Float = 0.;
	@:s public var visible:Bool = true;

	public function new(?parent) {
		super(parent);
		type = "object";
	}

	public function loadTransform(t) {
		x = t.x;
		y = t.y;
		z = t.z;
		scaleX = t.scaleX;
		scaleY = t.scaleY;
		scaleZ = t.scaleZ;
		rotationX = t.rotationX;
		rotationY = t.rotationY;
		rotationZ = t.rotationZ;
		rotationW = t.rotationW;
	}

	public function saveTransform() {
		return {
			x: x,
			y: y,
			z: z,
			scaleX: scaleX,
			scaleY: scaleY,
			scaleZ: scaleZ,
			rotationX: rotationX,
			rotationY: rotationY,
			rotationZ: rotationZ,
			rotationW: rotationW
		};
	}

	public function localRayIntersection(ctx:Context, ray:h3d.col.Ray):Float {
		return -1;
	}

	function createObject(ctx:Context) {
		return new h3d.scene.Object(ctx.local3d);
	}

	override function makeInstance(ctx:Context):Context {
		ctx = ctx.clone(this);
		ctx.local3d = createObject(ctx);
		ctx.local3d.name = name;
		updateInstance(ctx);
		return ctx;
	}

	public function setTransform(mat:h3d.Matrix) {
		var rot = new Quat();
		rot.initRotateMatrix(mat);
		x = mat.tx;
		y = mat.ty;
		z = mat.tz;
		var s = mat.getScale();
		scaleX = s.x;
		scaleY = s.y;
		scaleZ = s.z;
		rotationX = rot.x;
		rotationY = rot.y;
		rotationZ = rot.z;
		rotationW = rot.w;
	}

	public function getTransform(?m:h3d.Matrix) {
		if (m == null)
			m = new h3d.Matrix();
		var m2 = new h3d.Matrix();
		m.initScale(scaleX, scaleY, scaleZ);
		var rot = new Quat(rotationX, rotationY, rotationZ, rotationW);
		m.multiply(m, rot.toMatrix());
		m.translate(x, y, z);
		return m;
	}

	public function getAbsPos() {
		var p = parent;
		while (p != null) {
			var obj = p.to(Object3D);
			if (obj == null) {
				p = p.parent;
				continue;
			}
			var m = getTransform();
			var abs = obj.getAbsPos();
			m.multiply3x4(m, abs);
			return m;
		}
		return getTransform();
	}

	public function applyTransform(o:h3d.scene.Object) {
		o.x = x;
		o.y = y;
		o.z = z;
		o.scaleX = scaleX;
		o.scaleY = scaleY;
		o.scaleZ = scaleZ;
		o.setRotationQuat(new Quat(rotationX, rotationY, rotationZ, rotationW));
	}

	override function updateInstance(ctx:Context, ?propName:String) {
		var o = ctx.local3d;
		applyTransform(o);
		o.visible = visible;
		#if editor
		addEditorUI(ctx);
		#end
	}

	override function removeInstance(ctx:Context):Bool {
		if (ctx.local3d != null)
			ctx.local3d.remove();
		#if editor
		if (ctx.local2d != null) {
			var f = Std.downcast(ctx.local2d, h2d.ObjectFollower);
			if (f != null && f.follow == ctx.local3d)
				f.remove();
		}
		#end
		return true;
	}

	#if editor
	override function setSelected(ctx:Context, b:Bool):Bool {
		var materials = ctx.shared.getMaterials(this);

		if (!b) {
			for (m in materials) {
				// m.mainPass.stencil = null;
				m.removePass(m.getPass("highlight"));
				m.removePass(m.getPass("highlightBack"));
			}
			return true;
		}

		var shader = new h3d.shader.FixedColor(0xffffff);
		var shader2 = new h3d.shader.FixedColor(0xff8000);
		for (m in materials) {
			if (m.name != null && StringTools.startsWith(m.name, "$UI."))
				continue;
			var p = m.allocPass("highlight");
			p.culling = None;
			p.depthWrite = false;
			p.depthTest = LessEqual;
			p.addShader(shader);
			var p = m.allocPass("highlightBack");
			p.culling = None;
			p.depthWrite = false;
			p.depthTest = Always;
			p.addShader(shader2);
		}
		return true;
	}

	public function addEditorUI(ctx:Context) {
		for (r in ctx.shared.getObjects(this, h3d.scene.Object))
			if (r.name != null && StringTools.startsWith(r.name, "$UI."))
				r.remove();
	}

	override function makeInteractive(ctx:Context):hxd.SceneEvents.Interactive {
		var local3d = ctx.local3d;
		if (local3d == null)
			return null;
		var meshes = ctx.shared.getObjects(this, h3d.scene.Mesh);
		var invRootMat = local3d.getAbsPos().clone();
		invRootMat.invert();
		var bounds = new h3d.col.Bounds();
		var localBounds = [];
		var totalSeparateBounds = 0.;
		var visibleMeshes = [];
		var hasSkin = false;

		inline function getVolume(b:h3d.col.Bounds) {
			var c = b.getSize();
			return c.x * c.y * c.z;
		}
		for (mesh in meshes) {
			if (mesh.ignoreCollide)
				continue;

			// invisible objects are ignored collision wise
			var p:h3d.scene.Object = mesh;
			while (p != local3d) {
				if (!p.visible)
					break;
				p = p.parent;
			}
			if (p != local3d)
				continue;

			var localMat = mesh.getAbsPos().clone();
			localMat.multiply(localMat, invRootMat);

			if (mesh.primitive == null)
				continue;
			visibleMeshes.push(mesh);

			if (Std.downcast(mesh, h3d.scene.Skin) != null) {
				hasSkin = true;
				continue;
			}

			var asIcon = Std.downcast(mesh, hrt.impl.EditorTools.EditorIcon);
			if (asIcon != null) {
				hasSkin = true; // hack
				/*var pos = asIcon.getAbsPos();
					bounds.addSpherePos(pos.tx, pos.ty, pos.tz, asIcon.billboardScale); */
				continue;
			}

			var lb = mesh.primitive.getBounds().clone();
			lb.transform(localMat);
			bounds.add(lb);

			totalSeparateBounds += getVolume(lb);
			for (b in localBounds) {
				var tmp = new h3d.col.Bounds();
				tmp.intersection(lb, b);
				totalSeparateBounds -= getVolume(tmp);
			}
			localBounds.push(lb);
		}
		if (visibleMeshes.length == 0)
			return null;
		var colliders = [
			for (m in visibleMeshes) {
				var c:h3d.col.Collider = try m.getGlobalCollider() catch (e:Dynamic) null;
				if (c != null) c;
			}
		];
		var meshCollider = colliders.length == 1 ? colliders[0] : new h3d.col.Collider.GroupCollider(colliders);
		var collider:h3d.col.Collider = new h3d.col.ObjectCollider(local3d, bounds);
		if (hasSkin) {
			collider = meshCollider; // can't trust bounds
			meshCollider = null;
		} else if (totalSeparateBounds / getVolume(bounds) < 0.5) {
			collider = new h3d.col.Collider.OptimizedCollider(collider, meshCollider);
			meshCollider = null;
		}
		var int = new h3d.scene.Interactive(collider, local3d);
		int.ignoreParentTransform = true;
		int.preciseShape = meshCollider;
		int.propagateEvents = true;
		int.enableRightButton = true;
		return int;
	}

	override function edit(ctx:EditContext) {
		var props = new hide.Element('
			<div class="group" name="Position">
				<dl>
					<dt>X</dt><dd><input type="range" min="-10" max="10" value="0" field="x"/></dd>
					<dt>Y</dt><dd><input type="range" min="-10" max="10" value="0" field="y"/></dd>
					<dt>Z</dt><dd><input type="range" min="-10" max="10" value="0" field="z"/></dd>
					<dt>Scale</dt><dd><input type="multi-range" min="0" max="5" value="0" field="scale" data-subfields="X,Y,Z"/></dd>
					<dt>Rotation X</dt><dd><input type="range" min="-180" max="180" value="0" field="rotationX" /></dd>
					<dt>Rotation Y</dt><dd><input type="range" min="-180" max="180" value="0" field="rotationY" /></dd>
					<dt>Rotation Z</dt><dd><input type="range" min="-180" max="180" value="0" field="rotationZ" /></dd>
					<dt>Visible</dt><dd><input type="checkbox" field="visible"/></dd>
				</dl>
			</div>
		');
		var rotEul = new h3d.Quat(rotationX, rotationY, rotationZ, rotationW);
		var rotEulVec = rotEul.toEuler();
		var editCtx = {
			x: x,
			y: y,
			z: z,
			scaleX: scaleX,
			scaleY: scaleY,
			scaleZ: scaleZ,
			rotationX: hxd.Math.radToDeg(rotEulVec.x),
			rotationY: hxd.Math.radToDeg(rotEulVec.y),
			rotationZ: hxd.Math.radToDeg(rotEulVec.z),
			visible: visible
		};
		ctx.properties.add(props, editCtx, function(pname) {
			switch (pname) {
				case 'x':
					x = editCtx.x;
				case 'y':
					y = editCtx.y;
				case 'z':
					z = editCtx.z;
				case 'scale':
					scaleX = editCtx.scaleX;
					scaleY = editCtx.scaleY;
					scaleZ = editCtx.scaleZ;
				case 'rotationX' | 'rotationY' | 'rotationZ':
					rotEul.initRotation(hxd.Math.degToRad(editCtx.rotationX), hxd.Math.degToRad(editCtx.rotationY), hxd.Math.degToRad(editCtx.rotationZ));
					rotationX = rotEul.x;
					rotationY = rotEul.y;
					rotationZ = rotEul.z;
					rotationW = rotEul.w;
				case 'visible':
					visible = editCtx.visible;
			}

			ctx.onChange(this, pname);
		});
	}

	public function getDisplayFilters():Array<String> {
		return [];
	}

	override function getHideProps():HideProps {
		// Check children
		var cname = Type.getClassName(Type.getClass(this)).split(".").pop();
		return {
			icon: children == null || children.length > 0 ? "folder-open" : "genderless",
			name: cname == "Object3D" ? "Group" : cname,
		};
	}
	#end

	override function getDefaultName() {
		return type == "object" ? "group" : super.getDefaultName();
	}

	static var _ = Library.register("object", Object3D);
}
