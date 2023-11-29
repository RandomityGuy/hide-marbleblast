package hrt.collision;

import hrt.collision.BVHTree.IBVHObject;
import h3d.col.Plane;
import hrt.octree.Octree;
import h3d.col.Ray;
import h3d.Vector;
import hrt.octree.IOctreeObject;
import h3d.Matrix;
import h3d.col.Bounds;

class CollisionEntity implements IOctreeObject implements IBVHObject {
	public var boundingBox:Bounds;

	// public var octree:Octree;
	public var bvh:BVHTree<CollisionSurface>;

	public var surfaces:Array<CollisionSurface>;

	public var priority:Int;
	public var position:Int;
	public var velocity:Vector = new Vector();

	public var transform:Matrix;

	var invTransform:Matrix;

	public var userData:Int;
	public var fastTransform:Bool = false;

	var _transformKey:Int = 0;

	public function new() {
		this.surfaces = [];
		this.transform = Matrix.I();
		this.invTransform = Matrix.I();
	}

	public function addSurface(surface:CollisionSurface) {
		if (surface.points.length > 0) {
			this.surfaces.push(surface);
		}
	}

	// Generates the bvh
	public function finalize() {
		this.generateBoundingBox();
		this.bvh = new BVHTree();
		for (surface in this.surfaces) {
			this.bvh.add(surface);
		}
		// this.bvh.build();
	}

	public function dispose() {
		for (s in this.surfaces)
			s.dispose();
		surfaces = null;
		bvh = null;
	}

	public function setTransform(transform:Matrix) {
		if (this.transform.equal(transform))
			return;
		// Speedup
		this.transform.load(transform);
		this.invTransform = transform.getInverse();
		generateBoundingBox();
		_transformKey++;
	}

	public function generateBoundingBox() {
		var boundingBox = new Bounds();
		for (surface in this.surfaces) {
			var tform = surface.boundingBox.clone();
			tform.transform(transform);
			boundingBox.add(tform);
		}
		this.boundingBox = boundingBox;
	}

	public function rayCast(rayOrigin:Vector, rayDirection:Vector):Array<RayIntersectionData> {
		var invMatrix = invTransform;
		var invTPos = invMatrix.clone();
		invTPos.transpose();
		var rStart = rayOrigin.clone();
		rStart.transform(invMatrix);
		var rDir = rayDirection.transformed3x3(invMatrix);
		var intersections = this.bvh.rayCast(rStart, rDir);
		for (i in intersections) {
			i.point.transform(transform);
			i.normal.transform3x3(invTPos);
			i.normal.normalize();
		}

		return intersections;
	}

	public function getElementType() {
		return 2;
	}

	public function setPriority(priority:Int) {
		this.priority = priority;
	}
}
