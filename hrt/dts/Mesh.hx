package hrt.dts;

import hxsl.Types.Matrix;
import haxe.Exception;
import hrt.dif.math.Point2F;
import hrt.dif.math.Point3F;
import hrt.dif.math.Box3F;

@:publicFields
class Cluster {
	var startPrimitive:Int;
	var endPrimitive:Int;
	var normal:Point3F;
	var k:Float;
	var frontCluster:Int;
	var backCluster:Int;

	public function new() {}
}

@:publicFields
class Mesh {
	var meshType:Int;
	var numFrames:Int;
	var numMatFrames:Int;
	var parent:Int;
	var bounds:Box3F;
	var center:Point3F;
	var radius:Float;
	var vertices:Array<Point3F>;
	var uv:Array<Point2F>;
	var normals:Array<Point3F>;
	var enormals:Array<Int>;
	var primitives:Array<Primitive>;
	var indices:Array<Int>;
	var mindices:Array<Int>;
	var vertsPerFrame:Int;
	var type:Int;
	var shape:DtsFile;
	var initialTransforms:Array<Matrix>;
	var vertexIndices:Array<Int>;
	var boneIndices:Array<Int>;
	var weights:Array<Float>;
	var nodeIndices:Array<Int>;
	var clusters:Array<Cluster>;
	var startCluster:Int;
	var firstVert:Int;
	var numVerts:Int;
	var firstTVert:Int;

	public function new() {}

	function readStandard(reader:DtsAlloc, version:Int) {
		reader.guard();

		numFrames = reader.readU32();
		numMatFrames = reader.readU32();
		parent = reader.readS32();
		bounds = reader.readBoxF();
		center = reader.readPoint3F();
		radius = reader.readF32();

		var numVerts = reader.readU32();
		vertices = [];
		if (this.parent < 0) {
			for (i in 0...numVerts) {
				vertices.push(reader.readPoint3F());
			}
		} else {
			vertices = shape.meshes[this.parent].vertices;
		}

		var tVerts = reader.readU32();
		uv = [];
		if (this.parent < 0) {
			for (i in 0...tVerts) {
				uv.push(reader.readPoint2F());
			}
		} else {
			uv = shape.meshes[this.parent].uv;
		}

		normals = [];
		if (this.parent < 0) {
			for (i in 0...numVerts) {
				normals.push(reader.readPoint3F());
			}
		} else {
			normals = shape.meshes[this.parent].normals;
		}

		enormals = [];
		if (this.parent < 0 && version > 21) {
			for (i in 0...numVerts) {
				enormals.push(reader.readU8());
			}
		}

		primitives = [];
		var numPrimitives = reader.readU32();
		for (i in 0...numPrimitives) {
			primitives.push(Primitive.read(reader));
		}

		indices = [];
		var numIndices = reader.readU32();
		for (i in 0...numIndices) {
			indices.push(reader.readU16());
		}

		mindices = [];
		var numMIndices = reader.readU32();
		for (i in 0...numMIndices) {
			mindices.push(reader.readS16());
		}

		vertsPerFrame = reader.readS32();
		type = reader.readS32();

		reader.guard();
	}

	function readSorted(reader:DtsAlloc, version:Int) {
		readStandard(reader, version);
		clusters = [];
		var numClusters = reader.readS32();
		for (i in 0...numClusters) {
			var cluster = new Cluster();
			cluster.startPrimitive = reader.readS32();
			cluster.endPrimitive = reader.readS32();
			cluster.normal = reader.readPoint3F();
			cluster.k = reader.readF32();
			cluster.frontCluster = reader.readS32();
			cluster.backCluster = reader.readS32();
			clusters.push(cluster);
		}
		var sz = reader.readS32();

		function readS32s(s:Int) {
			var its = [];
			for (i in 0...s) {
				its.push(reader.readS32());
			}
			return its;
		}

		var ints = readS32s(sz);
		startCluster = sz != 0 ? ints[0] : -1;
		sz = reader.readS32();
		ints = readS32s(sz);
		firstVert = sz != 0 ? ints[0] : -1;
		sz = reader.readS32();
		ints = readS32s(sz);
		numVerts = sz != 0 ? ints[0] : -1;
		sz = reader.readS32();
		ints = readS32s(sz);
		firstTVert = sz != 0 ? ints[0] : -1;
		reader.readS32();
		reader.guard();
	}

	function readSkinned(reader:DtsAlloc, version:Int) {
		readStandard(reader, version);

		var numVerts = reader.readS32();
		if (parent < 0) {
			vertices = [];
			for (i in 0...numVerts) {
				vertices.push(reader.readPoint3F());
			}
			normals = [];
			for (i in 0...numVerts) {
				normals.push(reader.readPoint3F());
			}
			if (parent < 0) {
				for (i in 0...numVerts) {
					reader.readU8();
				}
			}
			var sz = reader.readS32();
			initialTransforms = [];
			for (i in 0...sz) {
				initialTransforms.push(reader.readMatrixF());
			}

			sz = reader.readS32();
			vertexIndices = [];
			for (i in 0...sz) {
				vertexIndices.push(reader.readS32());
			}
			boneIndices = [];
			for (i in 0...sz) {
				boneIndices.push(reader.readS32());
			}
			weights = [];
			for (i in 0...sz) {
				weights.push(reader.readF32());
			}
			sz = reader.readS32();
			nodeIndices = [];
			for (i in 0...sz) {
				nodeIndices.push(reader.readS32());
			}
		} else {
			var other = this.shape.meshes[parent];
			if (other == null) {
				return;
			}
			vertices = other.vertices;
			normals = other.normals;
			if (parent < 0) {
				for (i in 0...numVerts) {
					reader.readU8();
				}
			}
			reader.readS32();
			initialTransforms = other.initialTransforms;
			reader.readS32();
			vertexIndices = other.vertexIndices;
			boneIndices = other.boneIndices;
			weights = other.weights;
			reader.readS32();
			nodeIndices = other.nodeIndices;
		}
		reader.guard();
	}

	public static function read(shape:DtsFile, reader:DtsAlloc, version:Int) {
		var mesh = new Mesh();
		mesh.shape = shape;
		mesh.meshType = reader.readS32() & 7;

		if (mesh.meshType == 0)
			mesh.readStandard(reader, version);
		else if (mesh.meshType == 1)
			mesh.readSkinned(reader, version);
		else if (mesh.meshType == 3)
			mesh.readSorted(reader, version);
		else if (mesh.meshType == 4)
			return null;
		else
			throw new Exception("idk how to read this");

		return mesh;
	}
}
