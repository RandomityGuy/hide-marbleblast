package hrt.prefab.props;

import h3d.Vector;
import h3d.Quat;
import h3d.Matrix;
import hrt.mis.MisParser;

class GravityPointTriggerPropertyProvider extends PropertyProvider {
	var g:h3d.scene.Graphics;
	var gsphere:h3d.scene.Sphere;

	var selected:Bool = false;

	#if editor
	override function onSelected(s:Bool) {
		selected = s;
		if (g != null)
			g.visible = s;
		if (gsphere != null)
			gsphere.visible = s;
	}
	#end

	override function onPropertyChanged(ctx:EditContext, p:String) {
		super.onPropertyChanged(ctx, p);
		if (['custompoint', 'useradius', 'radiussize', 'invert'].contains(p)) {
			updateGraphics(ctx.getContext(obj));
		}
	}

	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);
		if (gsphere == null) {
			gsphere = new h3d.scene.Sphere(0xFFFF0000, 1, true, ctx.local3d);
			gsphere.ignoreParentTransform = true;
			gsphere.material.mainPass.setPassName("overlay");
			gsphere.material.mainPass.depth(false, LessEqual);
			gsphere.visible = selected;
			gsphere.ignoreBounds = true;
		}
		updateGraphics(ctx);

		// drawCannonTrajectory();
	}

	function updateGraphics(ctx:Context) {
		var spawnPointStr = obj.getCustomFieldValue('custompoint');
		var spawnPoint = null;
		if (spawnPointStr == "") {
			spawnPoint = ctx.local3d.getBounds().getCenter().toVector();
		} else {
			var vecValue = MisParser.parseVector3(spawnPointStr);
			vecValue.x = -vecValue.x;
			spawnPoint = vecValue;
		}

		gsphere.setPosition(spawnPoint.x, spawnPoint.y, spawnPoint.z);

		var gravityRadiusHas = obj.getCustomFieldValue("useradius");
		var gravityRadiusStr = "-1";
		if (gravityRadiusHas == "true" || gravityRadiusHas == "1")
			gravityRadiusStr = obj.getCustomFieldValue("radiussize");

		var gravityRadius = Std.parseFloat(gravityRadiusStr);
		if (gravityRadius == -1)
			gravityRadius = 9999;

		var invertStr = obj.getCustomFieldValue("invert");
		var invert = invertStr == "true" || invertStr == "1";

		gsphere.radius = gravityRadius;

		if (g == null) {
			g = new h3d.scene.Graphics(ctx.local3d);
			g.ignoreParentTransform = true;
			g.material.mainPass.setPassName("overlay");
			g.material.mainPass.depth(false, LessEqual);
			g.visible = selected;
			g.lineStyle(2, 0xFFFF0000);
			g.ignoreBounds = true;
		}

		var bounds = ctx.local3d.getBounds();

		g.clear();

		var x = bounds.xMin;
		while (x <= bounds.xMax) {
			var y = bounds.yMin;
			while (y <= bounds.yMax) {
				var z = bounds.zMin;
				while (z <= bounds.zMax) {
					var pt = new Vector(x, y, z);
					if (pt.distance(spawnPoint) > gravityRadius) {
						z += (bounds.zSize / 5) - 0.001;
						continue;
					}

					var dist = pt.sub(spawnPoint);
					dist.normalize();
					if (!invert)
						dist.scale(-1);

					var end = pt.add(dist);

					var q = new Quat();
					q.initDirection(dist);

					var p1 = new Vector(0.8, 0.2, 0);
					var p2 = new Vector(0.8, -0.2, 0);

					var qmat = new Matrix();
					q.toMatrix(qmat);
					p1.transform3x3(qmat);
					p2.transform3x3(qmat);

					g.moveTo(pt.x, pt.y, pt.z);
					g.lineTo(end.x, end.y, end.z);
					g.moveTo(end.x, end.y, end.z);
					g.lineTo(pt.x + p1.x, pt.y + p1.y, pt.z + p1.z);
					g.moveTo(end.x, end.y, end.z);
					g.lineTo(pt.x + p2.x, pt.y + p2.y, pt.z + p2.z);

					z += (bounds.zSize / 5) - 0.001;
				}

				y += (bounds.ySize / 5) - 0.001;
			}

			x += (bounds.xSize / 5) - 0.001;
		}
	}

	static var _ = PropertyProvider.registerPropertyProvider("GravityPointTrigger", GravityPointTriggerPropertyProvider);
}
