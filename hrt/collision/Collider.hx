package hrt.collision;

class Collider extends h3d.col.Collider {
	var collisionEntity:CollisionEntity;

	public function new() {
		collisionEntity = new CollisionEntity();
	}

	public function addSurface(s:CollisionSurface) {
		collisionEntity.addSurface(s);
	}

	public function finalize() {
		collisionEntity.finalize();
	}

	public function rayIntersection(r:h3d.col.Ray, bestMatch:Bool):Float {
		var pt = r.getPos().toVector();
		var res = collisionEntity.rayCast(pt, r.getDir().toVector());
		if (res.length == 0)
			return -1;
		var bestMatchIdx = 0;
		var bestMatch = res[0].point.distanceSq(pt);
		for (i in 1...res.length) {
			if (res[i].point.distanceSq(pt) < bestMatch) {
				bestMatch = res[i].point.distanceSq(pt);
				bestMatchIdx = i;
			}
		}
		var isecF = Math.sqrt(bestMatch) / r.getDir().length();
		return isecF;
	}

	public function contains(p:h3d.col.Point):Bool {
		throw new haxe.exceptions.NotImplementedException();
	}

	public function inFrustum(f:h3d.col.Frustum, ?localMatrix:h3d.Matrix):Bool {
		throw new haxe.exceptions.NotImplementedException();
	}

	public function inSphere(s:h3d.col.Sphere):Bool {
		throw new haxe.exceptions.NotImplementedException();
	}

	public function makeDebugObj():h3d.scene.Object {
		throw new haxe.exceptions.NotImplementedException();
	}
}
