package hrt.prefab.props;

import hrt.mis.TorqueConfig;
import hrt.prefab.l3d.StaticShape;
import h3d.Vector;
import hrt.prefab.l3d.TorqueObject;

using Lambda;

class PathNodePropertyProvider extends PropertyProvider {
	var g:h3d.scene.Graphics;

	var propertyChangeEventHandlers:Array<String->Void> = [];

	override function edit(ctx:EditContext) {
		super.edit(ctx);
		var def = new hide.Element('
			<div>
				<dt></dt>
				<dd><input type="button" value="Make Bezier Handles" id="add-handles"></input></dd>
			</div>
		');
		var bezierField = ctx.properties.element.find("#field-bezier");
		var addHandlesBtn = def.find("#add-handles");
		addHandlesBtn.on('click', (e) -> {
			addBezierHandles(ctx);
		});
		def.insertAfter(bezierField.parent().parent().parent());
	}

	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);
		if (g == null) {
			g = new h3d.scene.Graphics(ctx.local3d);
			g.ignoreParentTransform = true;
			g.lineStyle(2, 0xFFFF0000);
			g.material.mainPass.setPassName("overlay");
			g.material.mainPass.depth(false, LessEqual);
			g.ignoreBounds = true;
		}
		drawPath();
		propagateDrawPaths();
		// update path of those referring to this node as well
	}

	override function onTransformApplied() {
		drawPath();
		propagateDrawPaths();
	}

	override function onPropertyChanged(ctx:EditContext, p:String) {
		if (p == "spline" || p == "bezier" || p == "nextnode" || p == "bezierhandle1" || p == "bezierhandle2") {
			drawPath();
			propagateDrawPaths();
		}
		for (eh in propertyChangeEventHandlers) {
			eh(p);
		}
	}

	public function addEventListener(eh:String->Void) {
		propertyChangeEventHandlers.push(eh);
	}

	public function removeEventListener(eh:String->Void) {
		propertyChangeEventHandlers.remove(eh);
	}

	function propagateDrawPaths() {
		var rootObj:Prefab = obj.parent;
		while (rootObj.parent != null)
			rootObj = rootObj.parent;
		var relatives = rootObj.findAll(x -> {
			if (x is TorqueObject) {
				var xto = cast(x, TorqueObject);
				var found = xto.customFields.find(x -> x.field == 'nextnode' && x.value == obj.name);
				if (found != null)
					return x;
			}
			return null;
		});
		for (r in relatives) {
			var rto = cast(r, TorqueObject);
			if (rto.customFieldProvider == 'pathnode' && @:privateAccess rto.propertyProvider != null)
				@:privateAccess cast(rto.propertyProvider, PathNodePropertyProvider).drawPath();
		}
	}

	function drawPath() {
		if (g == null)
			return;
		var nextNode = obj.customFields.find(x -> x.field == 'nextnode')?.value;
		if (nextNode == null)
			return;
		var rootObj:Prefab = obj.parent;
		while (rootObj.parent != null)
			rootObj = rootObj.parent;
		var nextNodePrefab = rootObj.getPrefabByName(nextNode);

		g.clear();
		g.lineStyle(2, 0xFFFF0000);
		if (nextNodePrefab != null && nextNodePrefab is TorqueObject) {
			var to = cast(nextNodePrefab, TorqueObject);
			var ptList = getPointList();
			if (ptList.length == 2) {
				g.moveTo(obj.x, obj.y, obj.z);
				g.lineTo(to.x, to.y, to.z);
			} else {
				for (i in 0...20) {
					var p1 = bezier(i / 20.0, ptList);
					var p2 = bezier((i + 1) / 20.0, ptList);
					g.moveTo(p1.x, p1.y, p1.z);
					g.lineTo(p2.x, p2.y, p2.z);
				}

				g.lineStyle(2, 0xFF0000FF);
				for (i in 0...(ptList.length - 1)) {
					var p1 = ptList[i];
					var p2 = ptList[i + 1];
					g.moveTo(p1.x, p1.y, p1.z);
					g.lineTo(p2.x, p2.y, p2.z);
				}
			}
		}
	}

	function addBezierHandles(ectx:EditContext) {
		var rootObj:Prefab = obj.parent;
		while (rootObj.parent != null)
			rootObj = rootObj.parent;

		// Next Node
		var nextNodeName = obj.getCustomFieldValue('nextnode');

		var nextNode = obj;
		var nextNodePrefab = rootObj.getPrefabByName(nextNodeName);
		if (nextNodePrefab != null && nextNodePrefab is TorqueObject) {
			nextNode = cast nextNodePrefab;
		}
		// Next Node 2
		var nextNode2Name = nextNode.getCustomFieldValue('nextnode');

		var nextNode2 = obj;
		var nextNodePrefab2 = rootObj.getPrefabByName(nextNode2Name);
		if (nextNodePrefab2 != null && nextNodePrefab2 is TorqueObject) {
			nextNode2 = cast nextNodePrefab2;
		}
		// Previous Node
		var prevNode = obj;
		var prevNodePrefab = rootObj.find(x -> {
			if (x is TorqueObject) {
				var xto = cast(x, TorqueObject);
				var found = xto.customFields.find(x -> x.field == 'nextnode' && x.value == obj.name);
				if (found != null)
					return x;
			}
			return null;
		});
		if (prevNodePrefab != null) {
			prevNode = cast prevNodePrefab;
		}

		var startPos = new Vector(obj.x, obj.y, obj.z);
		var endPos = new Vector(nextNode.x, nextNode.y, nextNode.z);

		var dbData = TorqueConfig.getDataBlock("BezierHandle");
		var dtsPath = StringTools.replace(StringTools.replace(dbData.shapefile.toLowerCase(), "marble/", ""), "platinum/", "");

		var nodeBezier = obj.getCustomFieldValue('bezier');

		var els:Array<hrt.prefab.Prefab> = [];

		if (nodeBezier == "1" || nodeBezier.toLowerCase() == "true") {
			var b1 = obj.getCustomFieldValue('bezierhandle1');
			var b2 = obj.getCustomFieldValue('bezierhandle1');
			if (b1 == "") {
				var futurePos = new Vector(nextNode2.x, nextNode2.y, nextNode2.z);
				var dist = endPos.distance(startPos) / 3.0;
				var sub = futurePos.sub(startPos);
				sub.normalize();
				var splinePos = endPos.sub(sub.multiply(dist));

				var suffix = "";
				var inc = 0;
				while (rootObj.getPrefabByName(obj.name + "_Bezierhandle1" + suffix) != null) {
					suffix = '${inc}';
					inc++;
				}

				var sp = new StaticShape(obj.parent);
				sp.path = dtsPath;
				sp.skin = null;
				sp.name = obj.name + "_Bezierhandle1" + suffix;
				sp.x = splinePos.x;
				sp.y = splinePos.y;
				sp.z = splinePos.z;
				// obj.parent.children.push(sp);

				sp.dynamicFields = [];
				sp.customFieldProvider = "BezierHandle";
				sp.customFields = [];

				obj.setCustomFieldValue('bezierhandle1', obj.name + "_Bezierhandle1" + suffix);

				els.push(sp);
			}
			if (b2 == "") {
				var time = Std.parseFloat(obj.getCustomFieldValue("timetonext"));
				var prevtime = Std.parseFloat(prevNode.getCustomFieldValue("timetonext"));
				var prevPos = new Vector(prevNode.x, prevNode.y, prevNode.z);
				var dist = (startPos.distance(prevPos) / 3.0) * (Math.max(time, 1) / Math.max(prevtime, 1));
				var sub = endPos.sub(prevPos);
				sub.normalize();
				var splinePos = startPos.add(sub.multiply(dist));

				var suffix = "";
				var inc = 0;
				while (rootObj.getPrefabByName(obj.name + "_Bezierhandle2" + suffix) != null) {
					suffix = '${inc}';
					inc++;
				}

				var sp = new StaticShape(obj.parent);
				sp.path = dtsPath;
				sp.skin = null;
				sp.name = obj.name + "_Bezierhandle2" + suffix;
				sp.x = splinePos.x;
				sp.y = splinePos.y;
				sp.z = splinePos.z;

				sp.dynamicFields = [];
				sp.customFieldProvider = "BezierHandle";
				sp.customFields = [];

				obj.setCustomFieldValue('bezierhandle2', obj.name + "_Bezierhandle2" + suffix);
				els.push(sp);
			}
		}
		if (els.length != 0) {
			ectx.scene.editor.addElements(els, false, true, false);
			ectx.rebuildProperties();
		}
	}

	function getPointList() {
		var rootObj:Prefab = obj.parent;
		while (rootObj.parent != null)
			rootObj = rootObj.parent;

		// Next Node
		var nextNodeName = obj.getCustomFieldValue('nextnode');

		var nextNode = obj;
		var nextNodePrefab = rootObj.getPrefabByName(nextNodeName);
		if (nextNodePrefab != null && nextNodePrefab is TorqueObject) {
			nextNode = cast nextNodePrefab;
		}
		// Next Node 2
		var nextNode2Name = nextNode.getCustomFieldValue('nextnode');

		var nextNode2 = obj;
		var nextNodePrefab2 = rootObj.getPrefabByName(nextNode2Name);
		if (nextNodePrefab2 != null && nextNodePrefab2 is TorqueObject) {
			nextNode2 = cast nextNodePrefab2;
		}
		// Previous Node
		var prevNode = obj;
		var prevNodePrefab = rootObj.find(x -> {
			if (x is TorqueObject) {
				var xto = cast(x, TorqueObject);
				var found = xto.customFields.find(x -> obj.name != null
					&& x.field == 'nextnode'
					&& x.value.toLowerCase() == obj.name.toLowerCase());
				if (found != null)
					return x;
			}
			return null;
		});
		if (prevNodePrefab != null) {
			prevNode = cast prevNodePrefab;
		}

		var startPos = new Vector(obj.x, obj.y, obj.z);
		var endPos = new Vector(nextNode.x, nextNode.y, nextNode.z);

		var pointList = [];
		pointList.push(startPos);

		var nodeSpline = obj.getCustomFieldValue('spline');
		var nodeBezier = obj.getCustomFieldValue('bezier');
		var bezierHandle1 = null;
		if (nodeBezier.toLowerCase() == "true" || nodeBezier == "1") {
			var bezierHandleName = obj.getCustomFieldValue('bezierhandle2');
			if (bezierHandleName != null && bezierHandleName != "") {
				var bezierHandle1Prefab = rootObj.getPrefabByName(bezierHandleName);
				if (bezierHandle1Prefab != null && bezierHandle1Prefab is TorqueObject) {
					var bto = cast(bezierHandle1Prefab, TorqueObject);
					bezierHandle1 = new Vector(bto.x, bto.y, bto.z);
				}
			}
		}

		if (bezierHandle1 != null) {
			pointList.push(bezierHandle1);
		} else if (nodeSpline.toLowerCase() == "true" || nodeSpline == "1") {
			var time = Std.parseFloat(obj.getCustomFieldValue("timetonext"));
			var prevtime = Std.parseFloat(prevNode.getCustomFieldValue("timetonext"));
			var prevPos = new Vector(prevNode.x, prevNode.y, prevNode.z);
			var dist = (startPos.distance(prevPos) / 3.0) * (Math.max(time, 1) / Math.max(prevtime, 1));
			var sub = endPos.sub(prevPos);
			sub.normalize();
			var splinePos = startPos.add(sub.multiply(dist));
			pointList.push(splinePos);
		}

		var nextSpline = nextNode.getCustomFieldValue('spline');
		var nextBezier = nextNode.getCustomFieldValue('bezier');
		var bezierHandle2 = null;
		if (nextBezier.toLowerCase() == "true" || nextBezier == "1") {
			var bezierHandleName = nextNode.getCustomFieldValue('bezierhandle1');
			if (bezierHandleName != null && bezierHandleName != "") {
				var bezierHandle2Prefab = rootObj.getPrefabByName(bezierHandleName);
				if (bezierHandle2Prefab != null && bezierHandle2Prefab is TorqueObject) {
					var bto = cast(bezierHandle2Prefab, TorqueObject);
					bezierHandle2 = new Vector(bto.x, bto.y, bto.z);
				}
			}
		}
		if (bezierHandle2 != null) {
			pointList.push(bezierHandle2);
		} else if (nextSpline.toLowerCase() == "true" || nextSpline == "1") {
			var futurePos = new Vector(nextNode2.x, nextNode2.y, nextNode2.z);
			var dist = endPos.distance(startPos) / 3.0;
			var sub = futurePos.sub(startPos);
			sub.normalize();
			var splinePos = endPos.sub(sub.multiply(dist));
			pointList.push(splinePos);
		}
		pointList.push(endPos);

		return pointList;
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

	static var _ = PropertyProvider.registerPropertyProvider("PathNode", PathNodePropertyProvider);
}
