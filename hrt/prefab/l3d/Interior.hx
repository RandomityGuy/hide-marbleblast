package hrt.prefab.l3d;

import h3d.scene.Mesh;
import h3d.mat.Material;

using Lambda;

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

	public override function setName(name:String) {
		this.ctxObject.name = name;
	}

	override function makeInstance(ctx:Context):Context {
		if (path != null) {
			ctx = ctx.clone(this);

			ctxObject = new h3d.scene.Object(ctx.local3d);

			var mesh = new InteriorRootObject(ctxObject);
			mesh.setContent(ctx);

			innerMesh = mesh;

			loadInteriorFromPath(path, ctx);
			buildAnimators(mesh, ctx);

			ctx.local3d = ctxObject;
			ctx.local3d.name = name;
			updateInstance(ctx);
		}
		return ctx;
	}

	function loadInteriorFromPath(p:String, ctx:Context) {
		path = p;
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
					meshInstances.push(minst.addInstance(innerMesh));
				}
			}
		} else {
			for (m in instancer.meshes) {
				meshInstances.push(m.addInstance(innerMesh));
			}
		}
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

	function getInteractiveBounds(ctx:Context) {
		var local3d = ctx.local3d;
		if (local3d == null)
			return null;
		var invRootMat = local3d.getAbsPos().clone();
		invRootMat.invert();
		var bounds = new h3d.col.Bounds();
		var localBounds = [];
		var totalSeparateBounds = 0.;
		var visibleMeshes = [];

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
		return bounds;
	}

	override function makeInteractive(ctx:Context):hxd.SceneEvents.Interactive {
		var bounds = getInteractiveBounds(ctx);
		if (bounds == null)
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

	function updateInteractiveMesh(ctx:Context) {
		var bounds = getInteractiveBounds(ctx);
		var int:h3d.scene.Interactive = cast ctxObject.find(x -> x is h3d.scene.Interactive ? x : null);
		if (int != null) {
			int.preciseShape = InteriorInstanceManager.getManagerForContext(ctx).allocInstancer(path).collider;
			var collider:h3d.col.ObjectCollider = cast int.shape;
			collider.collider = bounds;
		}
	}

	function createSubobject(ge:hrt.dif.GameEntity, ctx:EditContext) {
		var mi = parent.getPrefabByName("MissionGroup");
		if (mi == null)
			mi = parent;

		var pmodel = hrt.prefab.Library.getRegistered().get(ge.gameClass.toLowerCase());

		var dbDef = hrt.mis.TorqueConfig.getDataBlock(ge.datablock);
		if (dbDef == null)
			return null;

		var skin = ge.properties.get("skin");

		var classLowercase = ge.gameClass.toLowerCase();
		if (classLowercase == "item" || classLowercase == "staticshape") {
			var p:hrt.prefab.l3d.DtsMesh = cast Type.createInstance(pmodel.cl, [mi]);
			@:privateAccess p.type = ge.gameClass.toLowerCase();
			p.name = "";
			p.customFieldProvider = ge.datablock.toLowerCase();
			p.path = StringTools.replace(StringTools.replace(dbDef.shapefile.toLowerCase(), "marble/", ""), "platinum/", "");
			p.skin = skin == "" ? null : skin;

			var ourTform = getRenderTransform();
			var ourRot = new h3d.Quat();
			ourRot.initRotateMatrix(ourTform);
			var gePos = new h3d.Vector(-ge.position.x, ge.position.y, ge.position.z);
			gePos.transform(ourTform);

			p.x = gePos.x;
			p.y = gePos.y;
			p.z = gePos.z;
			p.rotationX = ourRot.x;
			p.rotationY = ourRot.y;
			p.rotationZ = ourRot.z;
			p.rotationW = ourRot.w;

			p.customFields = hrt.mis.TorqueConfig.getDataBlock(ge.datablock).fields.filter(x -> x.defaultValue != null).map(x -> {
				return {field: x.name.toLowerCase(), value: '${x.defaultValue}'};
			});
			if (dbDef.fieldMap.exists("skin") && p.skin != null && p.customFields.find(x -> x.field == "skin") == null)
				p.customFields.push({field: "skin", value: p.skin});

			for (k => v in ge.properties) {
				var key = k.toLowerCase();

				if (classLowercase == "item") {
					var itemObj:hrt.prefab.l3d.Item = cast p;
					if (key == "static") {
						@:privateAccess itemObj.isStatic = v == "1" || v == "true";
						continue;
					}
					if (key == "rotate") {
						@:privateAccess itemObj.rotate = v == "1" || v == "true";
						continue;
					}
					if (key == "collideable") {
						@:privateAccess itemObj.collideable = v == "1" || v == "true";
						continue;
					}
				}

				if (dbDef.fieldMap.exists(key))
					p.setCustomFieldValue(key, v);
				else
					p.dynamicFields.push({field: key, value: v});
			}

			var skinDef = p.customFields.find(x -> x.field == "skin");
			if (skinDef != null && p.skin != null && skinDef.value != p.skin)
				skinDef.value = p.skin;
			return p;
		}
		return null;
	}

	override function edit(ctx:EditContext) {
		super.edit(ctx);

		var el = new hide.Element('<div class="group" name="Path">
			<dl>
				<dt>File</dt><dd><input type="fileselect" extensions="dif" field="path" /></dd>
				<dt></dt><dd><input type="button" value="Create Subs" id="createSubs"/></dd>
			</dl></div>');

		el.find("#createSubs").click(function(_) {
			var dif:hrt.dif.Dif = null;
			try {
				dif = hrt.dif.Dif.LoadFromBuffer(hxd.res.Loader.currentInstance.fs.get(path).getBytes());
			} catch (e:Dynamic) {
				return;
			}
			if (dif != null) {
				// Add the gameEntities first
				var els:Array<hrt.prefab.Prefab> = [];
				for (ge in dif.gameEntities) {
					var p = createSubobject(ge, ctx);
					if (p != null)
						els.push(p);
				}

				var mi = parent.getPrefabByName("MissionGroup");
				if (mi == null)
					mi = parent;

				var ourTform = getRenderTransform();
				var ourRot = new h3d.Quat();
				ourRot.initRotateMatrix(ourTform);

				var pis = [];

				// now for PathedInteriors
				for (itr in dif.interiorPathfollowers) {
					var g = new hrt.prefab.l3d.SimGroup(mi);
					els.push(g);
					g.name = '${itr.name}_g';
					g.type = "simgroup";

					// Create the Markers and path

					var pathObj = new hrt.prefab.l3d.InteriorPath(g);
					pathObj.name = '${itr.name}_path';
					pathObj.type = "path";
					var seqNum = 0;
					for (wp in itr.wayPoint) {
						var marker = new hrt.prefab.l3d.InteriorPath.InteriorPathMarker(pathObj);
						// els.push(marker);
						marker.seqNum = seqNum;
						marker.msToNext = wp.msToNext;
						marker.type = "marker";

						var mPos = new h3d.Vector(-wp.position.x, wp.position.y, wp.position.z);
						mPos.transform(ourTform);

						marker.x = mPos.x;
						marker.y = mPos.y;
						marker.z = mPos.z;
						marker.name = '${itr.name}_m${seqNum}';
						marker.smoothingType = hrt.prefab.l3d.InteriorPath.MarkerSmoothing.createByIndex(wp.smoothingType);
						seqNum++;
					}

					// Relevant triggers
					for (triggerIdx in itr.triggerId) {
						var trigger = dif.triggers[triggerIdx];

						var db = hrt.mis.TorqueConfig.getDataBlock(trigger.datablock.toLowerCase());
						if (db != null) {
							var triggerObj = new hrt.prefab.l3d.Trigger(g);
							triggerObj.type = "trigger";
							triggerObj.customFieldProvider = trigger.datablock.toLowerCase();
							triggerObj.name = trigger.name;
							var trPos = new h3d.Vector(-trigger.offset.x, trigger.offset.y, trigger.offset.z);
							trPos.transform(ourTform);

							var minPt = new h3d.Vector(1e8, 1e8, 1e8);
							var maxPt = new h3d.Vector(-1e8, -1e8, -1e8);
							for (pt in trigger.polyhedron.pointList) {
								minPt.x = Math.min(-pt.x, minPt.x);
								minPt.y = Math.min(pt.y, minPt.y);
								minPt.z = Math.min(pt.z, minPt.z);

								maxPt.x = Math.max(-pt.x, maxPt.x);
								maxPt.y = Math.max(pt.y, maxPt.y);
								maxPt.z = Math.max(pt.z, maxPt.z);
							}

							@:privateAccess triggerObj.origin = {x: minPt.x, y: minPt.y, z: minPt.z};
							@:privateAccess triggerObj.e1 = {x: maxPt.x - minPt.x, y: 0, z: 0};
							@:privateAccess triggerObj.e2 = {x: 0, y: maxPt.y - minPt.y, z: 0};
							@:privateAccess triggerObj.e3 = {x: 0, y: 0, z: maxPt.z - minPt.z};

							triggerObj.x = trPos.x;
							triggerObj.y = trPos.y;
							triggerObj.z = trPos.z;
							triggerObj.rotationX = ourRot.x;
							triggerObj.rotationY = ourRot.y;
							triggerObj.rotationZ = ourRot.z;
							triggerObj.rotationW = ourRot.w;
							for (k => v in trigger.properties) {
								if (db.fieldMap.exists(k))
									triggerObj.setCustomFieldValue(k, v);
								else
									triggerObj.dynamicFields.push({field: k, value: v});
							}
						}
					}

					var p = new hrt.prefab.l3d.PathedInterior(g);
					p.type = "pathedinterior";
					pis.push(p);
					p.path = this.path;
					p.so = itr.interiorResIndex;

					var pPos = new h3d.Vector(-itr.offset.x, itr.offset.y, itr.offset.z);
					pPos.transform(ourTform);

					p.x = pPos.x;
					p.y = pPos.y;
					p.z = pPos.z;
					p.rotationX = ourRot.x;
					p.rotationY = ourRot.y;
					p.rotationZ = ourRot.z;
					p.rotationW = ourRot.w;
					p.dynamicFields.push({field: "dataBlock", value: itr.datablock});
					p.initialPathPosition = itr.properties.exists("initialpathposition") ? Std.parseInt(itr.properties.get("initialpathposition")) : 0;
					p.initialTargetPosition = itr.properties.exists("initialtargetposition") ? Std.parseInt(itr.properties.get("initialtargetposition")) : 0;
					p.pathType = switch (p.initialTargetPosition) {
						case -1:
							Loop;
						case -2:
							LoopReverse;
						default:
							Time;
					};
					p.name = itr.name;

					// Add the dynamic fields
					for (k => v in itr.properties) {
						if (k != "initialpathposition" && k != "initialtargetposition")
							p.dynamicFields.push({field: k, value: v});
					}
				}

				ctx.scene.editor.addElements(els, false, true);

				// Update the pathed interiors
				for (pi in pis) {
					pi.updateInstance(ctx.getContext(pi));
					pi.type = "pathedinterior";
				}
				// Update the rest
				for (el in els) {
					el.updateInstance(ctx.getContext(el));
				}
			}
		});

		ctx.properties.add(el, this, function(pname) {
			ctx.onChange(this, pname);

			if (pname == "path") {
				var noException = true;
				try {
					var meshTemp = new h3d.scene.Object();
					hrt.dif.DifBuilder.loadDif(path, meshTemp); // new h3d.scene.Mesh(h3d.prim.Cube.defaultUnitCube(), ctx.local3d);
				} catch (e:Dynamic) {
					noException = false;
				}
				if (noException) {
					// Do the load only if we won't get an exception
					for (inst in meshInstances) {
						inst.remove();
					}
					meshInstances = [];
					loadInteriorFromPath(path, ctx.getContext(this));
					updateInteractiveMesh(ctx.getContext(this));
				}
			}
		});

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {
			icon: "cube",
			name: "InteriorInstance",
			fileSource: ["dif"],
			allowChildren: function(s) return false
		}
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
