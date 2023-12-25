package hrt.prefab.props;

import hrt.mis.MisParser;

using Lambda;

import hrt.prefab.l3d.TorqueObject;
import h3d.Vector;
import h3d.Matrix;
import h3d.Quat;

@:publicFields
class PathNode {
	var name:String;
	var nextNode:PathNode;
	var prevNode:PathNode;
	var prefab:TorqueObject;

	var usePosition:Bool;
	var useRotation:Bool;
	var useScale:Bool;
	var reverseRotation:Bool;
	var rotationMultiplier:Float;
	var rotationOffset:Matrix;

	var delay:Float;
	var speed:Float;
	var timeToNext:Float;
	var isBezier:Bool;
	var isSpline:Bool;
	var bezierHandle1:TorqueObject;
	var bezierHandle2:TorqueObject;
	var smooth:Bool;
	var smoothStart:Bool;
	var smoothEnd:Bool;

	var dirty:Bool = true;

	var eh:String->Void;

	var outHandler:Void->Void;

	public function new(name:String, prefab:TorqueObject, changeHandler:Void->Void) {
		this.name = name;
		this.prefab = prefab;
		this.outHandler = changeHandler;
		registerEventHandlers();
	}

	public function syncProps() {
		if (!dirty)
			return;

		var rootObj:Prefab = prefab.parent;
		while (rootObj.parent != null)
			rootObj = rootObj.parent;

		var usePositionStr = prefab.getCustomFieldValue('useposition');
		var useRotationStr = prefab.getCustomFieldValue('userotation');
		var useScaleStr = prefab.getCustomFieldValue('usescale');
		usePosition = usePositionStr == "true" || usePositionStr == "1" || usePositionStr == "";
		useRotation = useRotationStr == "true" || useRotationStr == "1" || useRotationStr == "";
		useScale = useScaleStr == "true" || useScaleStr == "1" || useScaleStr == "";

		var reverseRotStr = prefab.getCustomFieldValue('reverserotation');
		reverseRotation = reverseRotStr == "true" || reverseRotStr == "1";

		var rotationMultiplierStr = prefab.getCustomFieldValue('rotationmultiplier');
		rotationMultiplier = 1.0;
		if (rotationMultiplierStr != "") {
			rotationMultiplier = Std.parseFloat(rotationMultiplierStr);
		}

		var rotOffsetStr = prefab.getCustomFieldValue('rotationoffset');
		if (rotOffsetStr != "") {
			var rotOffset = MisParser.parseNumberList(rotOffsetStr);
			if (rotOffset.length == 3) {
				// euler
				var rotEul = new Matrix();
				rotEul.initRotation(rotOffset[0] * Math.PI / 180, rotOffset[1] * Math.PI / 180, rotOffset[2] * Math.PI / 180);
				rotationOffset = rotEul;
			}
			if (rotOffset.length == 4) {
				// axis angle
				var m1 = new Matrix();
				m1.initRotationAxis(new Vector(rotOffset[0], rotOffset[1], rotOffset[2]), rotOffset[3] * Math.PI / 180);
				rotationOffset = m1;
			}
		}

		var smoothStr = prefab.getCustomFieldValue('smooth');
		var smoothStartStr = prefab.getCustomFieldValue('smoothstart');
		var smoothEndStr = prefab.getCustomFieldValue('smoothend');

		smooth = smoothStr == "true" || smoothStr == "1";
		smoothStart = smoothStartStr == "true" || smoothStartStr == "1";
		smoothEnd = smoothEndStr == "true" || smoothEndStr == "1";

		var speedStr = prefab.getCustomFieldValue('speed');
		speed = speedStr == "" ? 0.0 : Std.parseFloat(speedStr);
		var delayStr = prefab.getCustomFieldValue('delay');
		delay = delayStr == "" ? 0.0 : (Std.parseFloat(delayStr) / 1000.0);

		var timeToNextStr = prefab.getCustomFieldValue('timetonext');
		timeToNext = timeToNextStr == "" ? 5.0 : (Std.parseFloat(timeToNextStr) / 1000.0);

		var nodeSpline = prefab.getCustomFieldValue('spline');
		var nodeBezier = prefab.getCustomFieldValue('bezier');

		isBezier = nodeBezier.toLowerCase() == "true" || nodeBezier == "1";
		isSpline = nodeSpline.toLowerCase() == "true" || nodeSpline == "1";

		if (isBezier) {
			var bezierHandleName = prefab.getCustomFieldValue('bezierhandle2');
			if (bezierHandleName != null && bezierHandleName != "") {
				var bezierHandle1Prefab = rootObj.getPrefabByName(bezierHandleName);
				if (bezierHandle1Prefab != null && bezierHandle1Prefab is TorqueObject) {
					var bto = cast(bezierHandle1Prefab, TorqueObject);
					bezierHandle2 = bto;
				}
			}

			bezierHandleName = prefab.getCustomFieldValue('bezierhandle1');
			if (bezierHandleName != null && bezierHandleName != "") {
				var bezierHandle2Prefab = rootObj.getPrefabByName(bezierHandleName);
				if (bezierHandle2Prefab != null && bezierHandle2Prefab is TorqueObject) {
					var bto = cast(bezierHandle2Prefab, TorqueObject);
					bezierHandle1 = bto;
				}
			}
		}
		dirty = false;
	}

	public function registerEventHandlers() {
		eh = (prop:String) -> {
			if (prop == "nextnode") { // We modified the path links itself, need to regenerate
				outHandler();
				return;
			}
			dirty = true;
			syncProps();
		};
		var pnpp:PathNodePropertyProvider = @:privateAccess cast prefab.propertyProvider;
		pnpp.addEventListener(eh);
	}

	public function unregisterEventHandlers() {
		var pnpp:PathNodePropertyProvider = @:privateAccess cast prefab.propertyProvider;
		pnpp.removeEventListener(eh);
	}
}

class PathNodeAnimator {
	var obj:TorqueObject;
	var ctx:Context;

	var pathBegin:PathNode;
	var path:Map<String, PathNode>;

	public function new(obj:TorqueObject, ctx:Context) {
		this.obj = obj;
		this.ctx = ctx;
	}

	function buildPath() {
		var rootObj:Prefab = obj.parent;
		while (rootObj.parent != null)
			rootObj = rootObj.parent;

		var field = obj.dynamicFields.find(x -> x.field == "path");
		if (field != null) {
			var startNodeName = field.value;
			if (startNodeName != "") {
				var nextNodePrefab = cast(rootObj.getPrefabByName(startNodeName), TorqueObject);
				if (nextNodePrefab != null) {
					path = [];
					pathBegin = new PathNode(startNodeName, nextNodePrefab, () -> regeneratePath());
					path[startNodeName] = pathBegin;
					var prevNode = pathBegin;
					while (true) {
						var nextNodeField = nextNodePrefab.getCustomFieldValue("nextnode");
						if (nextNodeField == "")
							break;
						var nextNodeName = nextNodeField;
						if (nextNodeName == "")
							break;
						var nextNodePrefab2 = cast(rootObj.getPrefabByName(nextNodeName), TorqueObject);
						if (nextNodePrefab2 == null)
							break;
						if (path.exists(nextNodeName)) { // End the loop
							prevNode.nextNode = path[nextNodeName];
							path[nextNodeName].prevNode = prevNode;
							break;
						}
						path[nextNodeName] = new PathNode(nextNodeName, nextNodePrefab2, () -> regeneratePath());
						prevNode.nextNode = path[nextNodeName];
						path[nextNodeName].prevNode = prevNode;
						nextNodePrefab = nextNodePrefab2;
						prevNode = prevNode.nextNode;
					}
					for (_ => node in path) {
						node.syncProps();
					}
				}
			} else {
				// Reset the transforms
			}
		}
	}

	public function regeneratePath() {
		// Unregister everything
		if (path != null) {
			for (_ => node in path) {
				node.unregisterEventHandlers();
			}
		}
		path = [];
		pathBegin = null;
		// Build path
		buildPath();
	}

	function getAdjustedProgress(node:PathNode, t:Float) {
		if (node.smooth || (t <= 0.50 && node.smoothStart) || (t > 0.50 && node.smoothEnd))
			t = -0.5 * Math.cos(t * Math.PI) + 0.5;

		return t;
	}

	function getPathPosition(node:PathNode, t:Float) {
		return interpolate(getPointList(node), getAdjustedProgress(node, t));
	}

	function getPathRotation(node:PathNode, t:Float) {
		var next = node.nextNode ?? node;
		var nodeCtx = ctx.shared.getContexts(node.prefab)[0];
		var nextCtx = ctx.shared.getContexts(next.prefab)[0];
		if (next == node) {
			var rotMat = new Matrix();
			nodeCtx.local3d.getRotationQuat().toMatrix(rotMat);
			/// rotMat.initRotation(node.prefab.rotationX * Math.PI / 180, node.prefab.rotationY * Math.PI / 180, node.prefab.rotationZ * Math.PI / 180);
			return rotMat;
		}

		var startRot = nodeCtx.local3d.getRotationQuat(); // new Vector(node.prefab.rotationX * Math.PI / 180, node.prefab.rotationY * Math.PI / 180, node.prefab.rotationZ * Math.PI / 180);
		var endRot = nextCtx.local3d.getRotationQuat(); // new Vector(next.prefab.rotationX * Math.PI / 180, next.prefab.rotationY * Math.PI / 180, next.prefab.rotationZ * Math.PI / 180);

		if (node.reverseRotation)
			t = 1.0 - t;

		var rot = rotInterpolate(startRot, endRot, getAdjustedProgress(node, t), node.rotationMultiplier);

		var rotOffset = node.rotationOffset;
		if (rotOffset != null) {
			rot.multiply(rot, rotOffset);
		}

		return rot;
	}

	function rotInterpolate(rot1:Quat, rot2:Quat, t:Float, multiplier:Float = 1.0) {
		var mat1 = new Matrix();
		var mat2 = new Matrix();
		rot1.toMatrix(mat1);
		rot2.toMatrix(mat2);

		var matSub = new Matrix(); // rot2 relative to rot1
		matSub.multiply(mat2, mat1.getInverse());

		var q = new Quat();
		q.initRotateMatrix(matSub);
		if (q.w > 1)
			q.normalize();
		var angle = 2 * Math.acos(q.w);
		angle *= t * multiplier;

		// var sq = new Quat();
		// sq.identity();
		// q.slerp(sq, q, t * multiplier);

		var s = Math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z);
		var x, y, z;
		if (s == 0.0) {
			x = 1.0;
			y = 0.0;
			z = 0.0;
		} else {
			x = q.x / s;
			y = q.y / s;
			z = q.z / s;
		}

		var retMat = new Matrix();
		// q.toMatrix(retMat);
		retMat.initRotationAxis(new Vector(x, y, z), angle);
		retMat.multiply(retMat, mat1);
		return retMat;
	}

	function getPathScale(node:PathNode, t:Float) {
		var next = node.nextNode ?? node;
		if (next == node) {
			return new Vector(node.prefab.scaleX, node.prefab.scaleY, node.prefab.scaleZ);
		}

		var startScale = new Vector(node.prefab.scaleX, node.prefab.scaleY, node.prefab.scaleZ);
		var endScale = new Vector(next.prefab.scaleX, next.prefab.scaleY, next.prefab.scaleZ);

		return lerp(startScale, endScale, getAdjustedProgress(node, t));
	}

	function getPathTransform(node:PathNode, t:Float) {
		var pos = null;
		var rot = new Matrix();
		rot.initRotation(node.prefab.rotationX * Math.PI / 180, node.prefab.rotationY * Math.PI / 180, node.prefab.rotationZ * Math.PI / 180);
		var scale = null;
		if (node.usePosition) {
			pos = getPathPosition(node, t);
		}
		if (node.useRotation) {
			rot = getPathRotation(node, t);
		}
		if (node.useScale) {
			scale = getPathScale(node, t);
		}
		return {
			pos: pos,
			rot: rot,
			scale: scale
		}
	}

	function getPathTime(node:PathNode) {
		var speed = node.speed;
		var delay = node.delay;
		if (speed > 0) {
			var next = node.nextNode ?? node;
			var nextPos = new Vector(next.prefab.x, next.prefab.y, next.prefab.z);
			var nodePos = new Vector(node.prefab.x, node.prefab.y, node.prefab.z);
			var distance = nextPos.sub(nodePos).length();
			return delay + (distance / speed);
		}
		var timeToNext = node.timeToNext;
		return delay + timeToNext;
	}

	function getPointList(node:PathNode) {
		var rootObj:Prefab = node.prefab.parent;
		while (rootObj.parent != null)
			rootObj = rootObj.parent;

		var nextNode = node.nextNode ?? node;
		var nextNode2 = nextNode.nextNode ?? node;
		var prevNode = node.prevNode ?? node;

		var startPos = new Vector(node.prefab.x, node.prefab.y, node.prefab.z);
		var endPos = new Vector(nextNode.prefab.x, nextNode.prefab.y, nextNode.prefab.z);

		var pointList = [];
		pointList.push(startPos);

		var nodeSpline = node.isSpline;
		var nodeBezier = node.isBezier;
		var bezierHandle1 = null;
		if (nodeBezier) {
			if (node.bezierHandle2 != null) {
				bezierHandle1 = node.bezierHandle2.getRenderTransform().getPosition();
			}
		}

		if (bezierHandle1 != null) {
			pointList.push(bezierHandle1);
		} else if (nodeSpline) {
			var time = getPathTime(node);
			var prevtime = getPathTime(prevNode);
			var prevPos = new Vector(prevNode.prefab.x, prevNode.prefab.y, prevNode.prefab.z);
			var dist = (startPos.distance(prevPos) / 3.0) * (Math.max(time, 1) / Math.max(prevtime, 1));
			var sub = endPos.sub(prevPos);
			sub.normalize();
			var splinePos = startPos.add(sub.multiply(dist));
			pointList.push(splinePos);
		}

		var nextSpline = nextNode.isSpline;
		var nextBezier = nextNode.isBezier;
		var bezierHandle2 = null;
		if (nextBezier) {
			if (nextNode.bezierHandle1 != null) {
				bezierHandle2 = nextNode.bezierHandle1.getRenderTransform().getPosition();
			}
		}
		if (bezierHandle2 != null) {
			pointList.push(bezierHandle2);
		} else if (nextSpline) {
			var futurePos = new Vector(nextNode2.prefab.x, nextNode2.prefab.y, nextNode2.prefab.z);
			var dist = endPos.distance(startPos) / 3.0;
			var sub = futurePos.sub(startPos);
			sub.normalize();
			var splinePos = endPos.sub(sub.multiply(dist));
			pointList.push(splinePos);
		}
		pointList.push(endPos);

		return pointList;
	}

	function updatePath(node:PathNode, position:Float) {
		var nodeDelay = node.delay;
		var t = 0.0;
		if (nodeDelay != 0 && position < nodeDelay) {
			t = 0;
		} else {
			position -= nodeDelay;
			t = hxd.Math.clamp(position / (getPathTime(node) - nodeDelay), 0, 1);
		}
		var trs = getPathTransform(node, t);
		return trs;
	}

	public function updateObjPosition(obj:h3d.scene.Object, totalElapsedTime:Float) {
		if (pathBegin == null)
			buildPath();
		if (pathBegin == null)
			return;
		var node = pathBegin;
		var prevNode = node;
		var pathTime = getPathTime(node);
		while (pathTime < totalElapsedTime) {
			totalElapsedTime -= pathTime;
			prevNode = node;
			node = node.nextNode ?? node;
			if (prevNode == node)
				break;

			pathTime = getPathTime(node);
		}
		var trs = updatePath(node, totalElapsedTime);
		if (trs.pos == null)
			trs.pos = obj.getAbsPos().getPosition();

		if (trs.scale == null)
			trs.scale = obj.getAbsPos().getScale();

		var invTform = obj.parent.getInvPos();

		var tform = new Matrix();
		var scaleMat = new Matrix();
		scaleMat.initScale(trs.scale.x, trs.scale.y, trs.scale.z);
		var rotMat = trs.rot;
		var posMat = new Matrix();
		posMat.initTranslation(trs.pos.x, trs.pos.y, trs.pos.z);
		tform.multiply(scaleMat, rotMat);
		tform.multiply(tform, posMat);
		tform.multiply(tform, invTform);

		obj.setTransform(tform);
	}

	function interpolate(pointList:Array<Vector>, t:Float) {
		if (pointList.length == 2)
			return lerp(pointList[0], pointList[1], t);
		if (pointList.length == 3)
			return quadraticBezier(pointList[0], pointList[1], pointList[2], t);
		if (pointList.length == 4)
			return cubicBezier(pointList[0], pointList[1], pointList[2], pointList[3], t);
		return pointList[0];
	}

	function fact(n:Int) {
		var result = 1;
		while (n > 0) {
			result = result * n;
			n--;
		}
		return result;
	}

	function bez(n:Int, i:Int, u:Float) {
		return (fact(n) / (fact(i) * fact(n - i))) * Math.pow(u, i) * Math.pow((1 - u), (n - i));
	}

	function bezier(u:Float, pointList:Array<Vector>) {
		var n = pointList.length - 1;
		var ret = new Vector(0, 0, 0);
		for (i in 0...(n + 1)) {
			var p = pointList[i];
			ret = ret.add(p.multiply(bez(n, i, u)));
		}
		return ret;
	}

	function lerp(a:Vector, b:Vector, t:Float) {
		return a.multiply(1 - t).add(b.multiply(t));
	}

	function quadraticBezier(p0:Vector, p1:Vector, p2:Vector, t:Float) {
		return p0.multiply((1 - t) * (1 - t)).add(p1.multiply(t * 2 * (1 - t))).add(p2.multiply(t * t));
	}

	function cubicBezier(p0:Vector, p1:Vector, p2:Vector, p3:Vector, t:Float) {
		return p0.multiply((1 - t) * (1 - t) * (1 - t))
			.add(p1.multiply(t * 3 * (1 - t) * (1 - t)))
			.add(p2.multiply(t * t * 3 * (1 - t)))
			.add(p3.multiply(t * t * t));
	}
}
