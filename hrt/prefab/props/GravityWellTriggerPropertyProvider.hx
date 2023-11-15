package hrt.prefab.props;

import h3d.Vector;
import h3d.Quat;
import h3d.Matrix;
import hrt.mis.MisParser;

class GravityWellTriggerPropertyProvider extends PropertyProvider {
	var g:h3d.scene.Graphics;
	var gcircle:h3d.scene.Mesh;

	var selected:Bool = false;

	#if editor
	override function onSelected(s:Bool) {
		selected = s;
		if (g != null)
			g.visible = s;
		if (gcircle != null)
			gcircle.visible = s;
	}
	#end

	override function onPropertyChanged(ctx:EditContext, p:String) {
		super.onPropertyChanged(ctx, p);
		if (['custompoint', 'useradius', 'radiussize', 'flipmeasure', 'invert', 'axis'].contains(p)) {
			updateGraphics(ctx.getContext(obj));
		}
	}

	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);

		if (g == null) {
			g = new h3d.scene.Graphics(ctx.local3d);
			g.ignoreParentTransform = true;
			g.material.mainPass.setPassName("overlay");
			g.material.mainPass.depth(false, LessEqual);
			g.visible = selected;
			g.lineStyle(2, 0xFFFF0000);
			g.ignoreBounds = true;
		}

		if (gcircle == null) {
			var p = new h3d.prim.Disc();
			p.addUVs();
			p.addNormals();
			gcircle = new h3d.scene.Mesh(p, h3d.mat.Material.create(), ctx.local3d);
			gcircle.ignoreParentTransform = true;
			gcircle.material.mainPass.setPassName("overlay");
			gcircle.material.mainPass.depth(false, LessEqual);
			gcircle.visible = selected;
			gcircle.ignoreBounds = true;
			gcircle.material.mainPass.wireframe = true;
		}
		updateGraphics(ctx);

		// drawCannonTrajectory();
	}

	function updateGraphics(ctx:Context) {
		var spawnPointStr = obj.getCustomFieldValue('custompoint');
		var axis = obj.getCustomFieldValue('axis');
		var spawnPoint = null;
		if (spawnPointStr == "") {
			spawnPoint = ctx.local3d.getBounds().getCenter().toVector();
		} else {
			var vecValue = MisParser.parseVector3(spawnPointStr);
			vecValue.x = -vecValue.x;
			spawnPoint = vecValue;
		}

		var gravityRadiusHas = obj.getCustomFieldValue("useradius");
		var gravityRadiusStr = "-1";
		if (gravityRadiusHas == "true" || gravityRadiusHas == "1")
			gravityRadiusStr = obj.getCustomFieldValue("radiussize");

		var gravityRadius = Std.parseFloat(gravityRadiusStr);
		if (gravityRadius == -1)
			gravityRadius = 9999;

		switch (axis) {
			case "z":
				gcircle.setRotation(0, 0, Math.PI / 2);
			case "y":
				gcircle.setRotation(Math.PI / 2, 0, 0);
			case _:
				gcircle.setRotation(0, Math.PI / 2, 0);
		};
		gcircle.scaleX = gcircle.scaleY = gcircle.scaleZ = gravityRadius;

		var bounds = ctx.local3d.getBounds();
		gcircle.setPosition(spawnPoint.x, spawnPoint.y, spawnPoint.z);

		g.clear();

		var x0 = bounds.xMin;
		var y0 = bounds.yMin;
		var z0 = bounds.zMin;
		var x1 = bounds.xMax;
		var y1 = bounds.yMax;
		var z1 = bounds.zMax;
		var dx = (bounds.xSize / 10) - 0.001;
		var dy = (bounds.ySize / 10) - 0.001;
		var dz = (bounds.zSize / 10) - 0.001;

		switch (axis) {
			case "z":
				dz = bounds.zSize;
				z0 = z1 = bounds.getCenter().z;
			case "y":
				dy = bounds.ySize;
				y0 = y1 = bounds.getCenter().y;
			case _:
				dx = bounds.zSize;
				x0 = x1 = bounds.getCenter().x;
		}

		var flipMeasure = false;
		var flipMeasureStr = obj.getCustomFieldValue('flipmeasure');
		flipMeasure = flipMeasureStr == '1' || flipMeasureStr == 'true';

		var invertStr = obj.getCustomFieldValue("invert");
		var invert = invertStr == "true" || invertStr == "1";

		var x = x0;
		while (x <= x1) {
			var y = y0;
			while (y <= y1) {
				var z = z0;
				while (z <= z1) {
					var pt = new Vector(x, y, z);

					if (pt.distance(spawnPoint) > gravityRadius) {
						z += (bounds.zSize / 5) - 0.001;
						continue;
					}

					var dist = pt.sub(spawnPoint);
					dist.normalize();
					if (!invert)
						dist.scale(-1);

					switch (axis) {
						case "x":
							dist.x = 0;
						case "y":
							dist.y = 0;
						case "z":
							dist.z = 0;
						case _:
							dist.x = dist.y = dist.z = 0;
					};

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

	static var _ = PropertyProvider.registerPropertyProvider("GravityWellTrigger", GravityWellTriggerPropertyProvider);
}
