package hrt.prefab.l3d;

import hxd.IndexBuffer;
import hrt.dts.TSDrawPrimitive;
import hrt.shader.DtsTexture;
import h3d.Matrix;
import hrt.dts.DtsFile;
import hrt.dts.Node;
import h3d.scene.Mesh;
import h3d.prim.Polygon;
import h3d.prim.UV;
import h3d.Vector;
import h3d.Quat;
import h3d.mat.BlendMode;
import h3d.mat.Data.Wrap;
import h3d.mat.Texture;
import h3d.mat.Material;
import h3d.scene.Object;
import haxe.io.Path;
import hrt.prefab.props.PathNodeAnimator;
import hrt.prefab.props.ParentingAnimator;

typedef GraphNode = {
	var index:Int;
	var node:Node;
	var children:Array<GraphNode>;
	var parent:GraphNode;
}

typedef MaterialGeometry = {
	var vertices:Array<Vector>;
	var normals:Array<Vector>;
	var uvs:Array<UV>;
	var indices:Array<Int>;
}

typedef SkinMeshData = {
	var meshIndex:Int;
	var vertices:Array<Vector>;
	var normals:Array<Vector>;
	var indices:Array<Int>;
	var geometry:Object;
}

@:publicFields
class DtsMeshInstance {
	var instancer:DtsMeshInstancer;
	var mesh:Mesh;
	var selected:Bool;
	var o:Object;
	var l3d:Object;

	public function new(instancer:DtsMeshInstancer, o:Object, l3d:Object) {
		this.instancer = instancer;
		this.o = o;
		this.l3d = l3d;
		this.selected = false;
	}

	public function remove() {
		instancer.removeInstance(this);
	}

	public function setSelected(b:Bool) {
		selected = b;
		if (mesh != null) {
			if (!b) {
				mesh.material.removePass(mesh.material.getPass("highlight"));
				mesh.material.removePass(mesh.material.getPass("highlightBack"));
			} else {
				var shader = new h3d.shader.FixedColor(0xffffff);
				var shader2 = new h3d.shader.FixedColor(0xff8000);
				var p = mesh.material.allocPass("highlight");
				p.culling = None;
				p.depthWrite = false;
				p.depthTest = LessEqual;
				p.addShader(shader);
				var p = mesh.material.allocPass("highlightBack");
				p.culling = None;
				p.depthWrite = false;
				p.depthTest = Always;
				p.addShader(shader2);
			}
		}
	}
}

@:publicFields
class DtsMeshInstancer {
	var defaultMeshBatch:h3d.scene.MeshBatch;
	var defaultSelectedMeshBatch:h3d.scene.MeshBatch;
	var colliderMesh:Mesh;
	var instances:Array<DtsMeshInstance>;
	var isAlpha:Bool;

	public function new() {
		instances = [];
	}

	public function createMesh(prim:h3d.prim.MeshPrimitive, m:Material, ctx:Context) {
		colliderMesh = new Mesh(prim, m);

		if (m.blendMode == Alpha) {
			// Just use the colliderMesh for all our purposes
			isAlpha = true;
			return;
		}

		defaultMeshBatch = new h3d.scene.MeshBatch(prim, cast m.clone());
		defaultSelectedMeshBatch = new h3d.scene.MeshBatch(prim, cast m.clone());

		fixMeshbatchMaterials(defaultMeshBatch.material, m);
		fixMeshbatchMaterials(defaultSelectedMeshBatch.material, m);
		makeHighlightMeshBatch(defaultSelectedMeshBatch);

		// transparencyMeshBatch = new h3d.scene.MeshBatch(prim, m);
		ctx.shared.root3d.addChild(defaultMeshBatch);
		ctx.shared.root3d.addChild(defaultSelectedMeshBatch);

		if (m.blendMode == Alpha)
			isAlpha = true;
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

		var dtsShader = mb.mainPass.getShader(DtsTexture);
		if (dtsShader != null) {
			dtsShader.currentOpacity = m.mainPass.getShader(DtsTexture).currentOpacity;
		}

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

	public function addInstance(o:Object, l3d:Object) {
		if (colliderMesh == null)
			return null;
		var inst = new DtsMeshInstance(this, o, l3d);
		instances.push(inst);
		if (isAlpha) {
			var cloneMat:Material = cast colliderMesh.material.clone();
			fixMeshbatchMaterials(cloneMat, colliderMesh.material);
			inst.mesh = new Mesh(colliderMesh.primitive, cloneMat, o);
		}
		return inst;
	}

	public function removeInstance(o:DtsMeshInstance) {
		instances.remove(o);
		if (isAlpha) {
			o.mesh.remove();
			o.mesh = null;
		}
	}

	public function emitInstances(ctx:h3d.scene.RenderContext) {
		if (isAlpha)
			return;
		var unselectedInsts = [];
		var selectedInsts = [];
		for (inst in instances) {
			if (!inst.l3d.visible || !inst.l3d.parent.visible)
				continue;
			if (inst.selected)
				selectedInsts.push(inst);
			else
				unselectedInsts.push(inst);
		}

		var cam = ctx.camera.m;
		selectedInsts.sort((a, b) -> {
			var aAbsPos = a.o.getAbsPos();
			var z = aAbsPos._41 * cam._13 + aAbsPos._42 * cam._23 + aAbsPos._43 * cam._33 + cam._43;
			var w = aAbsPos._41 * cam._14 + aAbsPos._42 * cam._24 + aAbsPos._43 * cam._34 + cam._44;
			var aDepth = z / w;

			aAbsPos = b.o.getAbsPos();
			z = aAbsPos._41 * cam._13 + aAbsPos._42 * cam._23 + aAbsPos._43 * cam._33 + cam._43;
			w = aAbsPos._41 * cam._14 + aAbsPos._42 * cam._24 + aAbsPos._43 * cam._34 + cam._44;
			var bDepth = z / w;

			return isAlpha ? (aDepth > bDepth ? -1 : 1) : (aDepth > bDepth ? 1 : -1);
		});

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
class DtsInstancer {
	var identifier:String;
	var meshes:Array<DtsMeshInstancer>;
	var meshMap:Map<Int, Int>;
	var collider:hrt.collision.Collider;

	public function new(identifier:String) {
		this.identifier = identifier;
		this.meshes = [];
		this.meshMap = [];
	}

	public function allocMesh(meshIndex:Int) {
		if (!meshMap.exists(meshIndex)) {
			meshes.push(new DtsMeshInstancer());
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
class DtsInstanceManager {
	static var _inited:Bool = false;

	static var managers:Map<ContextShared, DtsInstanceManager> = [];

	var lastUpdateFrame:Int;

	var instancers:Array<DtsInstancer>;
	var instancerMap:Map<String, Int>;

	public function new() {
		instancers = [];
		instancerMap = [];
	}

	public static function getManagerForContext(ctx:Context) {
		if (!managers.exists(ctx.shared)) {
			var manager = new DtsInstanceManager();
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
			instancers.push(new DtsInstancer(ident));
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
		// for (instancer in instancers) {
		// 	instancer.emitInstances(true, ctx);
		// }
	}

	public function isInstanced(ident:String) {
		return instancerMap.exists(ident);
	}
}

class DtsRootObject extends Object {
	var context:Context;

	public function setContent(c:Context) {
		this.context = c;
	}

	override function syncRec(ctx:h3d.scene.RenderContext) {
		super.syncRec(ctx);
		DtsInstanceManager.getManagerForContext(context).emitInstances(ctx);
	}
}

class DtsCache {
	static var cache:Map<String, DtsFile> = [];

	public static function readDTS(path:String) {
		if (cache.exists(path))
			return cache[path];
		var dts = new DtsFile();
		dts.read(path);
		cache.set(path, dts);
		return dts;
	}
}

class DtsMesh extends TorqueObject {
	@:s public var path:String;

	var dtsPath:String;
	var directoryPath:String;
	var dts:DtsFile;

	var graphNodes:Array<Object> = [];
	var materials:Array<Material> = [];
	var materialInfos:Map<Material, Array<String>> = new Map();

	@:s public var skin:String;

	var skinMeshData:SkinMeshData;

	var rootObject:DtsRootObject;

	var ctxObject:Object;

	var isInstanced:Bool = false;

	var meshInstances:Array<DtsMeshInstance> = [];

	public function setColor(ctx:Context, color:Int) {
		// #if editor
		// if (ctx.local3d == null)
		// 	return;
		// var mesh = Std.downcast(ctx.local3d, h3d.scene.Mesh);
		// if (mesh != null) {
		// 	setDebugColor(color, mesh.material);
		// }
		// #end
	}

	public override function loadFromPath(p:String) {
		path = p;
		return true;
	}

	override function makeInstance(ctx:Context):Context {
		if (path != null) {
			ctx = ctx.clone(this);

			dts = DtsCache.readDTS(path);
			dtsPath = path;
			init(ctx.local3d, ctx); // new h3d.scene.Mesh(h3d.prim.Cube.defaultUnitCube(), ctx.local3d);

			// #if editor
			// setDebugColor(0x60ffffff, mesh.material);

			// var wire = new h3d.scene.Box(mesh);
			// wire.color = 0;
			// wire.ignoreCollide = true;
			// wire.material.shadows = false;
			// #end

			ctx.local3d = ctxObject;
			ctx.local3d.name = name;
			assignPropertyProvider();
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

	function init(par:h3d.scene.Object, ctx:Context) {
		this.directoryPath = Path.directory(this.dtsPath);
		this.isInstanced = DtsInstanceManager.getManagerForContext(ctx).isInstanced(this.dtsPath + (this.skin != null ? this.skin : ""));
		if (!this.isInstanced)
			this.computeMaterials();

		if (!isInstanced) {
			for (i in 0...this.materials.length) {
				var info = this.materialInfos.get(this.materials[i]);

				if (info == null)
					continue;
				var iflSequence = this.dts.sequences.filter(seq -> seq.iflMatters.length > 0 ? seq.iflMatters[0] > 0 : false);

				if (iflSequence.length == 0)
					continue;
				var completion = 0 / (iflSequence[0].duration);
				var keyframe = Math.floor(completion * info.length) % info.length;
				var currentFile = info[keyframe];
				var ext = haxe.io.Path.extension(currentFile);
				var basename = haxe.io.Path.withoutExtension(currentFile);

				var exts = ["jpg", "png"];

				var texture = null;

				for (ext in exts) {
					if (hxd.res.Loader.currentInstance.fs.exists(this.directoryPath + '/' + basename + "." + ext)) {
						texture = hxd.res.Loader.currentInstance.load(this.directoryPath + '/' + basename + "." + ext).toTexture();
						break;
					}
				}

				var flags = this.dts.matFlags[i];

				if (flags & 1 > 0 || flags & 2 > 0)
					texture.wrap = Wrap.Repeat;
				this.materials[i].texture = texture;
			}
		}

		if (ctxObject == null)
			ctxObject = new Object(par);

		if (rootObject == null)
			rootObject = new DtsRootObject(ctxObject);

		buildAnimators(rootObject, ctx);

		var graphNodes = [];
		var rootNodesIdx = [];
		meshInstances = [];

		var instancer = DtsInstanceManager.getManagerForContext(ctx).allocInstancer(this.dtsPath + (this.skin != null ? this.skin : ""));

		for (i in 0...this.dts.nodes.length) {
			graphNodes.push(new Object());
		}
		for (i in 0...this.dts.nodes.length) {
			var node = this.dts.nodes[i];

			if (node.parent != -1) {
				graphNodes[node.parent].addChild(graphNodes[i]);
			} else {
				rootNodesIdx.push(i);
			}
		}
		this.graphNodes = graphNodes;
		// this.rootGraphNodes = graphNodes.filter(node -> node.parent == null);
		var affectedBySequences = this.dts.sequences.length > 0 ? (this.dts.sequences[0].rotationMatters.length < 0 ? 0 : this.dts.sequences[0].rotationMatters[0]) | (this.dts.sequences[0].translationMatters.length > 0 ? this.dts.sequences[0].translationMatters[0] : 0) : 0;

		var meshIdx = 0;
		var collider = null;
		if (!isInstanced) {
			collider = new hrt.collision.Collider();
		}

		for (i in 0...dts.nodes.length) {
			var objects = dts.objects.filter(object -> object.node == i);
			var sequenceAffected = ((1 << i) & affectedBySequences) != 0;

			for (object in objects) {
				var isCollisionObject = dts.names[object.name].substr(0, 3).toLowerCase() == "col";

				if (isCollisionObject)
					continue;
				for (j in object.firstMesh...(object.firstMesh + object.numMeshes)) {
					if (j >= this.dts.meshes.length)
						continue;
					var mesh = this.dts.meshes[j];

					var meshDetail = this.dts.detailLevels[j - object.firstMesh];
					if (dts.names[meshDetail.name].substr(0, 3).toLowerCase() == "col")
						continue;
					if (mesh == null)
						continue;
					if (mesh.parent >= 0)
						continue; // Fix teleporter being broken
					if (mesh.vertices.length == 0)
						continue;
					if (!isInstanced) {
						var vertices = mesh.vertices.map(v -> new Vector(-v.x, v.y, v.z));
						var vertexNormals = mesh.normals.map(v -> new Vector(-v.x, v.y, v.z));

						var geometry = this.generateMaterialGeometry(collider, mesh, vertices, vertexNormals);

						for (k in 0...geometry.length) {
							if (geometry[k].vertices.length == 0)
								continue;

							var meshInstance = instancer.allocMesh(meshIdx++);

							var ib = new IndexBuffer(geometry[k].vertices.length);
							for (i in 0...geometry[k].vertices.length) {
								ib.push(i);
							}

							var poly = new Polygon(geometry[k].vertices.map(x -> x.toPoint()), ib);
							poly.normals = geometry[k].normals.map(x -> x.toPoint());
							poly.uvs = geometry[k].uvs;

							meshInstance.createMesh(poly, materials[k], ctx);
							var obj = new Object(this.graphNodes[i]);
							meshInstances.push(meshInstance.addInstance(obj, rootObject));
						}
					} else {
						var usedMats = [];

						for (prim in mesh.primitives) {
							if (!usedMats.contains(prim.matIndex & TSDrawPrimitive.MaterialMask)) {
								usedMats.push(prim.matIndex & TSDrawPrimitive.MaterialMask);
							}
						}

						for (k in usedMats) {
							var meshInstance = instancer.allocMesh(meshIdx++);
							var obj = new Object(this.graphNodes[i]);
							meshInstances.push(meshInstance.addInstance(obj, rootObject));
						}
					}
				}
			}
		}
		this.updateNodeTransforms();
		for (i in 0...this.dts.meshes.length) {
			var mesh = this.dts.meshes[i];

			if (mesh == null)
				continue;
			if (mesh.meshType == 1) {
				var skinObj = new Object();

				var meshInstance = instancer.allocMesh(i);

				if (!isInstanced) {
					var vertices = mesh.vertices.map(v -> new Vector(-v.x, v.y, v.z));
					var vertexNormals = mesh.normals.map(v -> new Vector(-v.x, v.y, v.z));
					var geometry = this.generateMaterialGeometry(collider, mesh, vertices, vertexNormals);

					for (k in 0...geometry.length) {
						if (geometry[k].vertices.length == 0)
							continue;
						var poly = new Polygon(geometry[k].vertices.map(x -> x.toPoint()));

						poly.normals = geometry[k].normals.map(x -> x.toPoint());
						poly.uvs = geometry[k].uvs;
						var obj = new Object(skinObj);
						meshInstance.createMesh(poly, materials[k], ctx);
						meshInstances.push(meshInstance.addInstance(obj, rootObject));
					}
					skinMeshData = {
						meshIndex: i,
						vertices: vertices,
						normals: vertexNormals,
						indices: [],
						geometry: skinObj
					};
					var idx = geometry.map(x -> x.indices);
					for (indexes in idx) {
						skinMeshData.indices = skinMeshData.indices.concat(indexes);
					}
				} else {
					var usedMats = [];

					for (prim in mesh.primitives) {
						if (!usedMats.contains(prim.matIndex)) {
							usedMats.push(prim.matIndex);
						}
					}

					for (k in usedMats) {
						var obj = new Object(skinObj);
						meshInstances.push(meshInstance.addInstance(obj, rootObject));
					}
					skinMeshData = {
						meshIndex: i,
						vertices: [],
						normals: [],
						indices: [],
						geometry: skinObj
					};
				}
			}
		}
		if (!isInstanced) {
			collider.finalize();
			instancer.setCollider(collider);
		}
		rootObject.setContent(ctx);
		for (i in rootNodesIdx) {
			rootObject.addChild(this.graphNodes[i]);
		}
		if (this.skinMeshData != null) {
			rootObject.addChild(this.skinMeshData.geometry);
		}
	}

	function getFullNamesOf(path:String) {
		var files = hxd.res.Loader.currentInstance.fs.dir(Path.directory(path)); // FileSystem.readDirectory(Path.directory(path));
		var names = [];
		var fname = Path.withoutDirectory(path).toLowerCase();
		for (file in files) {
			var fname2 = file.name;
			if (Path.withoutExtension(fname2).toLowerCase() == fname || fname2.toLowerCase() == fname)
				names.push(file.path);
		}
		return names;
	}

	function computeMaterials() {
		var environmentMaterial:Material = null;
		this.materials = [];
		this.materialInfos = [];

		for (i in 0...dts.matNames.length) {
			var matName = this.dts.matNames[i];
			if (matName.indexOf('/') != -1)
				matName = matName.substring(matName.lastIndexOf('/') + 1);
			if (skin != null && StringTools.startsWith(matName, "base."))
				matName = StringTools.replace(matName, "base.", skin + ".");
			var flags = dts.matFlags[i];
			var fullNames = getFullNamesOf(this.directoryPath + '/' + matName).filter(x -> Path.extension(x) != "dts");
			var fullName = fullNames.length > 0 ? fullNames[0] : null;

			// if (this.isTSStatic && environmentMaterial != null && DROP_TEXTURE_FOR_ENV_MAP.contains(this.dtsPath)) {
			// 	this.materials.push(environmentMaterial);
			// 	continue;
			// }

			var material = Material.create();

			var iflMaterial = false;

			if (fullName == null) {
				// if (this.isTSStatic) {
				// 	material.mainPass.enableLights = false;
				// 	if (flags & (1 << 31) > 0) {
				// 		environmentMaterial = material;
				// 	}
				// 	// Console.warn('Unsupported material type for ${fullName}, dts: ${this.dtsPath}');
				// 	// TODO USE PBR???
				// }
			} else if (Path.extension(fullName) == "ifl") {
				var keyframes = parseIfl(fullName);
				this.materialInfos.set(material, keyframes);
				iflMaterial = true;
			} else {
				var texture = hxd.res.Loader.currentInstance.load(fullName).toTexture();
				texture.wrap = Wrap.Repeat;
				material.texture = texture;
				var dtsshader = new DtsTexture();
				dtsshader.texture = texture;
				dtsshader.currentOpacity = 1;
				// if (this.identifier == "Tornado")
				dtsshader.normalizeNormals = false; // These arent normalized
				material.mainPass.removeShader(material.textureShader);
				material.mainPass.addShader(dtsshader);
				// TODO TRANSLUENCY SHIT
			}
			material.shadows = false;
			if (material.texture == null && !iflMaterial) {
				var dtsshader = new DtsTexture();
				dtsshader.currentOpacity = 1;
				// if (this.identifier == "Tornado")
				dtsshader.normalizeNormals = false; // These arent normalized
				// Make a 1x1 white texture
				#if hl
				var bitmap = new hxd.BitmapData(1, 1);
				bitmap.lock();
				bitmap.setPixel(0, 0, 0xFFFFFF);
				bitmap.unlock();
				var texture = new Texture(1, 1);
				texture.uploadBitmap(bitmap);
				texture.wrap = Wrap.Repeat;
				#end
				// Apparently creating these bitmap datas dont work so we'll just get the snag a white texture in the filesystem
				#if js
				var texture:Texture = hxd.res.Loader.currentInstance.load("data/shapes/hazards/null.png").toTexture();
				texture.wrap = Wrap.Repeat;
				#end
				material.texture = texture;
				dtsshader.texture = texture;
				material.mainPass.addShader(dtsshader);
				material.shadows = false;
			}
			if (flags & 4 > 0) {
				material.blendMode = BlendMode.Alpha;
				material.mainPass.culling = h3d.mat.Data.Face.None;
				material.receiveShadows = false;
				material.mainPass.depthWrite = false;
			}
			if (flags & 8 > 0) {
				material.blendMode = BlendMode.Add;
			}
			if (flags & 16 > 0) {
				material.blendMode = BlendMode.Sub;
			}

			if (flags & 32 > 0) {
				material.mainPass.enableLights = false;
				material.receiveShadows = false;
			}

			// if (this.isTSStatic && !(flags & 64 > 0)) {
			// 	var reflectivity = this.dts.matNames.length == 1 ? 1 : (environmentMaterial != null ? 0.5 : 0.333);
			// 	var cubemapshader = new EnvMap(this.level.sky.cubemap, reflectivity);
			// 	material.mainPass.addShader(cubemapshader);
			// }

			this.materials.push(material);
		}

		if (this.materials.length == 0) {
			#if hl
			var bitmap = new hxd.BitmapData(1, 1);
			bitmap.lock();
			bitmap.setPixel(0, 0, 0xFFFFFF);
			bitmap.unlock();
			var texture = new Texture(1, 1);
			texture.uploadBitmap(bitmap);
			texture.wrap = Wrap.Repeat;
			#end
			// Apparently creating these bitmap datas dont work so we'll just get the snag a white texture in the filesystem
			#if js
			var texture:Texture = hxd.res.Loader.currentInstance.load("data/shapes/hazards/null.png").toTexture();
			texture.wrap = Wrap.Repeat;
			#end
			var dtsshader = new DtsTexture();
			var mat = Material.create();
			mat.texture = texture;
			dtsshader.texture = texture;
			mat.mainPass.addShader(dtsshader);
			mat.shadows = false;
			this.materials.push(mat);
			// TODO THIS
		}
	}

	function generateMaterialGeometry(col:hrt.collision.Collider, dtsMesh:hrt.dts.Mesh, vertices:Array<Vector>, vertexNormals:Array<Vector>) {
		var materialGeometry:Array<MaterialGeometry> = this.dts.matNames.map(x -> {
			vertices: [],
			normals: [],
			uvs: [],
			indices: []
		});
		if (materialGeometry.length == 0 && dtsMesh.primitives.length > 0) {
			materialGeometry.push({
				vertices: [],
				normals: [],
				uvs: [],
				indices: []
			});
		}

		var ab = new Vector();
		var ac = new Vector();
		function addTriangleFromIndices(hs:hrt.collision.CollisionSurface, i1:Int, i2:Int, i3:Int, materialIndex:Int) {
			ab.set(vertices[i2].x - vertices[i1].x, vertices[i2].y - vertices[i1].y, vertices[i2].z - vertices[i1].z);
			ac.set(vertices[i3].x - vertices[i1].x, vertices[i3].y - vertices[i1].y, vertices[i3].z - vertices[i1].z);
			var normal = ab.cross(ac);
			normal.normalize();
			var dot1 = normal.dot(vertexNormals[i1]);
			var dot2 = normal.dot(vertexNormals[i2]);
			var dot3 = normal.dot(vertexNormals[i3]);
			// if (!StringTools.contains(this.dtsPath, 'helicopter.dts') && !StringTools.contains(this.dtsPath, 'tornado.dts'))
			// ^ temp hardcoded fix

			// if (dot1 < 0 && dot2 < 0 && dot3 < 0) {
			if ((dot1 < 0 && dot2 < 0 && dot3 < 0) || StringTools.contains(this.dtsPath, 'helicopter.dts')) {
				var temp = i1;
				i1 = i3;
				i3 = temp;
			}

			// }

			var geometrydata = materialGeometry[materialIndex];

			for (index in [i1, i2, i3]) {
				var vertex = vertices[index];
				geometrydata.vertices.push(new Vector(vertex.x, vertex.y, vertex.z));
				hs.addPoint(vertex.x, vertex.y, vertex.z);

				var uv = dtsMesh.uv[index];
				geometrydata.uvs.push(new UV(uv.x, uv.y));

				var normal = vertexNormals[index];
				geometrydata.normals.push(new Vector(normal.x, normal.y, normal.z));
				hs.addNormal(normal.x, normal.y, normal.z);
			}

			geometrydata.indices.push(i1);
			geometrydata.indices.push(i2);
			geometrydata.indices.push(i3);
			hs.indices.push(hs.indices.length);
			hs.indices.push(hs.indices.length);
			hs.indices.push(hs.indices.length);
		}

		for (primitive in dtsMesh.primitives) {
			var hs = new hrt.collision.CollisionSurface();
			hs.points = [];
			hs.normals = [];
			hs.indices = [];
			hs.transformKeys = [];

			var materialIndex = primitive.matIndex & TSDrawPrimitive.MaterialMask;
			var drawType = primitive.matIndex & TSDrawPrimitive.TypeMask;
			var geometrydata = materialGeometry[materialIndex];

			if (drawType == TSDrawPrimitive.Triangles) {
				var i = primitive.firstElement;
				while (i < primitive.firstElement + primitive.numElements) {
					var i1 = dtsMesh.indices[i];
					var i2 = dtsMesh.indices[i + 1];
					var i3 = dtsMesh.indices[i + 2];

					addTriangleFromIndices(hs, i1, i2, i3, materialIndex);

					i += 3;
				}
			} else if (drawType == TSDrawPrimitive.Strip) {
				var k = 0;
				for (i in primitive.firstElement...(primitive.firstElement + primitive.numElements - 2)) {
					var i1 = dtsMesh.indices[i];
					var i2 = dtsMesh.indices[i + 1];
					var i3 = dtsMesh.indices[i + 2];

					if (k % 2 == 0) {
						// Swap the first and last index to mainting correct winding order
						var temp = i1;
						i1 = i3;
						i3 = temp;
					}

					addTriangleFromIndices(hs, i1, i2, i3, materialIndex);

					k++;
				}
			} else if (drawType == TSDrawPrimitive.Fan) {
				var i = primitive.firstElement;
				while (i < primitive.firstElement + primitive.numElements - 2) {
					var i1 = dtsMesh.indices[primitive.firstElement];
					var i2 = dtsMesh.indices[i + 1];
					var i3 = dtsMesh.indices[i + 2];

					addTriangleFromIndices(hs, i1, i2, i3, materialIndex);

					i++;
				}
			}

			hs.generateBoundingBox();
			col.addSurface(hs);
		}

		return materialGeometry;
	}

	function parseIfl(path:String) {
		var text = hxd.res.Loader.currentInstance.fs.get(path).getText();
		var lines = text.split('\n');
		var keyframes = [];
		for (line in lines) {
			line = StringTools.trim(line);
			if (line.substr(0, 2) == "//")
				continue;
			if (line == "")
				continue;

			var parts = line.split(' ');
			var count = parts.length > 1 ? Std.parseInt(parts[1]) : 1;

			for (i in 0...count) {
				keyframes.push(parts[0]);
			}
		}

		return keyframes;
	}

	function updateNodeTransforms(quaternions:Array<Quat> = null, translations:Array<Vector> = null, bitField = 0xffffffff) {
		for (i in 0...this.graphNodes.length) {
			var translation = this.dts.defaultTranslations[i];
			var rotation = this.dts.defaultRotations[i];
			var mat = Matrix.I();
			var quat = new Quat(-rotation.x, rotation.y, rotation.z, -rotation.w);
			quat.normalize();
			quat.conjugate();
			quat.toMatrix(mat);
			mat.setPosition(new Vector(-translation.x, translation.y, translation.z));
			this.graphNodes[i].setTransform(mat);
			var absTform = this.graphNodes[i].getAbsPos().clone();
		}
	}

	#if editor
	static public function setDebugColor(color:Int, mat:h3d.mat.Material) {
		// mat.color.setColor(color);
		// var opaque = (color >>> 24) == 0xff;
		// mat.shadows = false;

		// if (opaque) {
		// 	var alpha = mat.getPass("debuggeom_alpha");
		// 	if (alpha != null)
		// 		mat.removePass(alpha);
		// 	mat.mainPass.setPassName("default");
		// 	mat.mainPass.setBlendMode(None);
		// 	mat.mainPass.depthWrite = true;
		// 	mat.mainPass.culling = None;
		// } else {
		// 	mat.mainPass.setPassName("debuggeom");
		// 	mat.mainPass.setBlendMode(Alpha);
		// 	mat.mainPass.depthWrite = true;
		// 	mat.mainPass.culling = Front;
		// 	var alpha = mat.allocPass("debuggeom_alpha");
		// 	alpha.setBlendMode(Alpha);
		// 	alpha.culling = Back;
		// 	alpha.depthWrite = false;
		// }
	}

	override function edit(ctx:EditContext) {
		super.edit(ctx);

		// ctx.properties.add(new hide.Element('<div class="group" name="Path">
		// 	<dl>
		// 		<dt>File</dt><dd><input type="text" field="path" /></dd>
		// 	</dl></div>'), this, function(pname) {
		// 	ctx.onChange(this, pname);
		// });
	}

	override function setSelected(ctx:Context, b:Bool):Bool {
		for (inst in meshInstances)
			inst.setSelected(b);
		if (propertyProvider != null)
			propertyProvider.onSelected(b);
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
		var meshCollider = DtsInstanceManager.getManagerForContext(ctx)
			.allocInstancer(this.dtsPath + (this.skin != null ? this.skin : ""))
			.collider; // colliders.length == 1 ? colliders[0] : new h3d.col.Collider.GroupCollider(colliders);
		var collider:h3d.col.Collider = new h3d.col.ObjectCollider(rootObject, bounds);
		var int = new h3d.scene.Interactive(collider, rootObject);
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
			int.preciseShape = DtsInstanceManager.getManagerForContext(ctx).allocInstancer(this.dtsPath + (this.skin != null ? this.skin : "")).collider;
			var collider:h3d.col.ObjectCollider = cast int.shape;
			collider.collider = bounds;
		}
	}

	override function getHideProps():HideProps {
		return {icon: "square", name: "DTS"};
	}
	#end

	public function changeSkin(skin:String, ctx:Context) {
		var local3d = rootObject.parent.parent;
		this.skin = skin;
		for (gnode in graphNodes) {
			rootObject.removeChild(gnode);
		}
		for (inst in meshInstances) {
			inst.remove();
		}
		init(local3d, ctx);
	}

	override function getRenderTransform() {
		return rootObject.getAbsPos();
	}

	override function cleanup() {
		materials = null;
		materialInfos = null;
		rootObject.remove();
		rootObject.removeChildren();
		rootObject = null;
		ctxObject.remove();
		ctxObject.removeChildren();
		ctxObject = null;
		skinMeshData = null;
		for (inst in meshInstances) {
			inst.remove();
			inst.instancer = null;
			inst.mesh = null;
			inst.o = null;
			inst.l3d = null;
		}
		meshInstances = null;
	}

	static var _ = Library.register("dts", DtsMesh);
}
