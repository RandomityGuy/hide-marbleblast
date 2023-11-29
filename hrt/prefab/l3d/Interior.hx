package hrt.prefab.l3d;

import h3d.scene.Mesh;
import h3d.mat.Material;

@:publicFields
class InteriorMeshInstance {
	var instancer:InteriorMeshInstancer;
	var selected:Bool;
	var o:h3d.scene.Object;

	public function new(instancer:InteriorMeshInstancer, o:h3d.scene.Object) {
		this.instancer = instancer;
		this.o = o;
		this.selected = false;
	}

	public function remove() {
		instancer.removeInstance(this);
	}

	public function setSelected(b:Bool) {
		selected = b;
	}
}

@:publicFields
class InteriorMeshInstancer {
	var defaultMeshBatch:h3d.scene.MeshBatch;
	var defaultSelectedMeshBatch:h3d.scene.MeshBatch;
	var colliderMesh:Mesh;
	var instances:Array<InteriorMeshInstance>;

	public function new() {
		instances = [];
	}

	public function createMesh(prim:h3d.prim.MeshPrimitive, m:Material, ctx:Context) {
		colliderMesh = new Mesh(prim, m);

		defaultMeshBatch = new h3d.scene.MeshBatch(prim, cast m.clone());
		defaultSelectedMeshBatch = new h3d.scene.MeshBatch(prim, cast m.clone());

		fixMeshbatchMaterials(defaultMeshBatch.material, m);
		fixMeshbatchMaterials(defaultSelectedMeshBatch.material, m);
		makeHighlightMeshBatch(defaultSelectedMeshBatch);

		// transparencyMeshBatch = new h3d.scene.MeshBatch(prim, m);
		ctx.shared.root3d.addChild(defaultMeshBatch);
		ctx.shared.root3d.addChild(defaultSelectedMeshBatch);
	}

	function fixMeshbatchMaterials(mb:Material, m:Material) {
		var minfoshaders = [];
		for (shader in mb.mainPass.getShaders()) {
			minfoshaders.push(shader);
		}
		for (shader in minfoshaders)
			mb.mainPass.removeShader(shader);
		var addshaders = [];
		for (shader in m.mainPass.getShaders()) {
			addshaders.push(shader);
		}
		for (shader in addshaders)
			mb.mainPass.addShader(shader);

		mb.mainPass.depthWrite = m.mainPass.depthWrite;
		mb.mainPass.depthTest = m.mainPass.depthTest;
		mb.mainPass.setPassName(m.mainPass.name);
		mb.mainPass.enableLights = m.mainPass.enableLights;
		mb.mainPass.culling = m.mainPass.culling;

		mb.mainPass.blendSrc = m.mainPass.blendSrc;
		mb.mainPass.blendDst = m.mainPass.blendDst;
		mb.mainPass.blendOp = m.mainPass.blendOp;
		mb.mainPass.blendAlphaSrc = m.mainPass.blendAlphaSrc;
		mb.mainPass.blendAlphaDst = m.mainPass.blendAlphaDst;
		mb.mainPass.blendAlphaOp = m.mainPass.blendAlphaOp;
	}

	function makeHighlightMeshBatch(mb:h3d.scene.MeshBatch) {
		var shader = new h3d.shader.FixedColor(0xffffff);
		var shader2 = new h3d.shader.FixedColor(0xff8000);
		var p = mb.material.allocPass("highlight");
		p.culling = None;
		p.depthWrite = false;
		p.depthTest = LessEqual;
		p.addShader(shader);
		var p = mb.material.allocPass("highlightBack");
		p.culling = None;
		p.depthWrite = false;
		p.depthTest = Always;
		p.addShader(shader2);
	}

	public function addInstance(o:h3d.scene.Object) {
		var inst = new InteriorMeshInstance(this, o);
		instances.push(inst);
		return inst;
	}

	public function removeInstance(o:InteriorMeshInstance) {
		instances.remove(o);
	}

	public function emitInstances(ctx:h3d.scene.RenderContext) {
		var unselectedInsts = [];
		var selectedInsts = [];
		for (inst in instances) {
			if (!inst.o.visible || !inst.o.parent.visible)
				continue;
			if (inst.selected)
				selectedInsts.push(inst);
			else
				unselectedInsts.push(inst);
		}

		defaultMeshBatch.begin(unselectedInsts.length);
		for (instance in unselectedInsts) {
			defaultMeshBatch.worldPosition = instance.o.getAbsPos();
			// fixMeshbatchMaterials(defaultMeshBatch, colliderMesh.material, true);
			defaultMeshBatch.emitInstance();
		}

		defaultSelectedMeshBatch.begin(selectedInsts.length);
		for (instance in selectedInsts) {
			defaultSelectedMeshBatch.worldPosition = instance.o.getAbsPos();
			// fixMeshbatchMaterials(defaultSelectedMeshBatch, colliderMesh.material, true);
			defaultSelectedMeshBatch.emitInstance();
		}
	}

	public function dispose() {
		this.defaultMeshBatch.remove();
		this.defaultMeshBatch = null;
		this.defaultSelectedMeshBatch.remove();
		this.defaultSelectedMeshBatch = null;
		this.instances = [];
	}
}

@:publicFields
class InteriorInstancer {
	var identifier:String;
	var meshes:Array<InteriorMeshInstancer>;
	var meshMap:Map<Int, Int>;
	var collider:hrt.collision.Collider;

	public function new(identifier:String) {
		this.identifier = identifier;
		this.meshes = [];
		this.meshMap = [];
	}

	public function allocMesh(meshIndex:Int) {
		if (!meshMap.exists(meshIndex)) {
			meshes.push(new InteriorMeshInstancer());
			meshMap.set(meshIndex, meshes.length - 1);
			return meshes[meshes.length - 1];
		} else {
			return meshes[meshMap.get(meshIndex)];
		}
	}

	public function emitInstances(alphaPass:Bool, ctx:h3d.scene.RenderContext) {
		for (mesh in meshes) {
			// if (mesh.isAlpha == alphaPass)
			mesh.emitInstances(ctx);
		}
	}

	public function setCollider(c:hrt.collision.Collider) {
		this.collider = c;
	}

	public function dispose() {
		for (mesh in meshes) {
			mesh.dispose();
		}
	}
}

@:publicFields
class InteriorInstanceManager {
	static var _inited:Bool = false;

	static var managers:Map<ContextShared, InteriorInstanceManager> = [];

	var lastUpdateFrame:Int;

	var instancers:Array<InteriorInstancer>;
	var instancerMap:Map<String, Int>;

	public function new() {
		instancers = [];
		instancerMap = [];
	}

	public static function getManagerForContext(ctx:Context) {
		if (!managers.exists(ctx.shared)) {
			var manager = new InteriorInstanceManager();
			ctx.cleanup = () -> {
				for (insts in manager.instancers) {
					insts.dispose();
				}
				manager.instancers = [];
				manager.instancerMap = [];
				manager = null;
				managers.remove(ctx.shared);
			};
			managers.set(ctx.shared, manager);
		}
		return managers.get(ctx.shared);
	}

	public function allocInstancer(ident:String) {
		if (!instancerMap.exists(ident)) {
			instancers.push(new InteriorInstancer(ident));
			instancerMap.set(ident, instancers.length - 1);
			return instancers[instancers.length - 1];
		} else {
			return instancers[instancerMap.get(ident)];
		}
	}

	public function emitInstances(ctx:h3d.scene.RenderContext) {
		if (ctx.frame == lastUpdateFrame)
			return;
		lastUpdateFrame = ctx.frame;
		for (instancer in instancers) {
			instancer.emitInstances(false, ctx);
		}
	}

	public function isInstanced(ident:String) {
		return instancerMap.exists(ident);
	}
}

class InteriorRootObject extends h3d.scene.Object {
	var context:Context;

	public function setContent(c:Context) {
		this.context = c;
	}

	override function syncRec(ctx:h3d.scene.RenderContext) {
		super.syncRec(ctx);
		InteriorInstanceManager.getManagerForContext(context).emitInstances(ctx);
	}
}

class Interior extends TorqueObject {
	@:s public var path:String;

	var innerMesh:h3d.scene.Object;

	var ctxObject:h3d.scene.Object;

	var meshInstances:Array<InteriorMeshInstance> = [];

	public override function loadFromPath(p:String) {
		path = p;
		return true;
	}

	override function makeInstance(ctx:Context):Context {
		if (path != null) {
			ctx = ctx.clone(this);

			ctxObject = new h3d.scene.Object(ctx.local3d);

			var mesh = new InteriorRootObject(ctxObject);
			mesh.setContent(ctx);

			var isInstanced = InteriorInstanceManager.getManagerForContext(ctx).isInstanced(path);
			var instancer = InteriorInstanceManager.getManagerForContext(ctx).allocInstancer(path);

			if (!isInstanced) {
				var meshTemp = new h3d.scene.Object();
				var collider = hrt.dif.DifBuilder.loadDif(path, meshTemp); // new h3d.scene.Mesh(h3d.prim.Cube.defaultUnitCube(), ctx.local3d);
				instancer.setCollider(collider);
				for (i in 0...meshTemp.numChildren) {
					var ch = meshTemp.getChildAt(i);
					if (ch is Mesh) {
						var chmesh:Mesh = cast ch;
						var minst = instancer.allocMesh(i);
						minst.createMesh(cast chmesh.primitive, chmesh.material, ctx);
						meshInstances.push(minst.addInstance(mesh));
					}
				}
			} else {
				for (m in instancer.meshes) {
					meshInstances.push(m.addInstance(mesh));
				}
			}

			buildAnimators(mesh, ctx);

			innerMesh = mesh;

			ctx.local3d = ctxObject;
			ctx.local3d.name = name;
			updateInstance(ctx);
		}
		return ctx;
	}

	override function removeInstance(ctx:Context):Bool {
		if (ctx.local3d != null)
			ctx.local3d.remove();
		for (insts in meshInstances)
			insts.remove();

		return true;
	}

	override function getEditorClassName():String {
		return "InteriorInstance";
	}

	#if editor
	override function setSelected(ctx:Context, b:Bool):Bool {
		for (inst in meshInstances)
			inst.setSelected(b);
		return true;
	}

	override function makeInteractive(ctx:Context):hxd.SceneEvents.Interactive {
		var local3d = ctx.local3d;
		if (local3d == null)
			return null;
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
		for (inst in meshInstances) {
			var mesh = @:privateAccess inst.instancer.colliderMesh;
			if (mesh.ignoreCollide)
				continue;

			var localMat = inst.o.getAbsPos().clone();
			localMat.multiply(localMat, invRootMat);

			if (mesh.primitive == null)
				continue;
			visibleMeshes.push(mesh);

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
		var meshCollider = InteriorInstanceManager.getManagerForContext(ctx).allocInstancer(path).collider;
		var collider:h3d.col.Collider = new h3d.col.ObjectCollider(innerMesh, bounds);
		var int = new h3d.scene.Interactive(collider, innerMesh);
		int.ignoreParentTransform = true;
		int.preciseShape = meshCollider;
		int.propagateEvents = true;
		int.enableRightButton = true;
		return int;
	}

	override function edit(ctx:EditContext) {
		super.edit(ctx);

		ctx.properties.add(new hide.Element('<div class="group" name="Path">
			<dl>
				<dt>File</dt><dd><input type="fileselect" extensions="dif" field="path" /></dd>
			</dl></div>'), this, function(pname) {
			ctx.onChange(this, pname);

			if (pname == "path") {
				var prevChildren = [];
				for (ch in innerMesh)
					prevChildren.push(ch);

				innerMesh.removeChildren();
				try {
					hrt.dif.DifBuilder.loadDif(path, innerMesh); // new h3d.scene.Mesh(h3d.prim.Cube.defaultUnitCube(), ctx.local3d);
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
		return {icon: "cube", name: "InteriorInstance", fileSource: ["dif"]};
	}
	#end

	override function getRenderTransform() {
		return innerMesh.getAbsPos();
	}

	override function cleanup() {
		innerMesh.remove();
		innerMesh.removeChildren();
		innerMesh = null;
		ctxObject.remove();
		ctxObject.removeChildren();
		ctxObject = null;
		for (inst in meshInstances) {
			inst.remove();
			inst.instancer = null;
			inst.o = null;
		}
		meshInstances = null;
	}

	static var _ = Library.register("interiorinstance", Interior, "dif");
}
