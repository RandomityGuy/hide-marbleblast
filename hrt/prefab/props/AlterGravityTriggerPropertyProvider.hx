package hrt.prefab.props;

import h3d.Vector;
import h3d.Quat;
import h3d.Matrix;
import hrt.mis.MisParser;

class AlterGravityTriggerPropertyProvider extends PropertyProvider {
	var g:h3d.scene.Graphics;

	var selected:Bool = false;

	#if editor
	override function onSelected(s:Bool) {
		selected = s;
		if (g != null)
			g.visible = s;
	}
	#end

	override function onPropertyChanged(ctx:EditContext, p:String) {
		super.onPropertyChanged(ctx, p);
		if ([
			'measureaxis',
			'gravityaxis',
			'flipmeasure',
			'startinggravityrot',
			'endinggravityrot'
		].contains(p)) {
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
		updateGraphics(ctx);

		// drawCannonTrajectory();
	}

	function updateGraphics(ctx:Context) {
		var bounds = ctx.local3d.getBounds();

		g.clear();

		var x0 = bounds.getCenter().x;
		var y0 = bounds.getCenter().y;
		var z0 = bounds.getCenter().z;
		var x1 = bounds.xMax;
		var y1 = bounds.yMax;
		var z1 = bounds.zMax;
		var dx = bounds.xSize;
		var dy = bounds.ySize;
		var dz = bounds.zSize;

		var measureAxis = obj.getCustomFieldValue('measureaxis');
		if (measureAxis == 'x')
			x0 = bounds.xMin;
		if (measureAxis == 'y')
			y0 = bounds.yMin;
		if (measureAxis == 'z')
			z0 = bounds.zMin;

		var gravityAxis = obj.getCustomFieldValue('gravityaxis');
		if (gravityAxis == 'x')
			dx = (bounds.xMax / 50) - 0.001;
		if (gravityAxis == 'y')
			dy = (bounds.yMax / 50) - 0.001;
		if (gravityAxis == 'z')
			dz = (bounds.zMax / 50) - 0.001;

		var flipMeasure = false;
		var flipMeasureStr = obj.getCustomFieldValue('flipmeasure');
		flipMeasure = flipMeasureStr == '1' || flipMeasureStr == 'true';

		var startingGravityRot = MisParser.parseNumber(obj.getCustomFieldValue('startinggravityrot'));
		var endingGravityRot = MisParser.parseNumber(obj.getCustomFieldValue('endinggravityrot'));

		var lowbound = switch (measureAxis) {
			case "x":
				obj.x;
			case "y":
				obj.y;
			case "z":
				obj.z;
			case _:
				obj.z;
		};
		if (flipMeasure) {
			lowbound -= switch (measureAxis) {
				case "x":
					bounds.xSize;
				case "y":
					bounds.ySize;
				case "z":
					bounds.zSize;
				case _:
					bounds.xSize;
			};
		}

		var totalDist = lowbound -= switch (measureAxis) {
			case "x":
				bounds.xSize;
			case "y":
				bounds.ySize;
			case "z":
				bounds.zSize;
			case _:
				bounds.xSize;
		};

		var x = x0;
		while (x <= x1) {
			var y = y0;
			while (y <= y1) {
				var z = z0;
				while (z <= z1) {
					var pt = new Vector(x, y, z);

					var m = switch (measureAxis) {
						case "x":
							pt.x;
						case "y":
							pt.y;
						case "z":
							pt.z;
						case _:
							pt.x;
					}

					var diff = m - lowbound;
					var fraction = diff / totalDist;
					if (flipMeasure)
						fraction -= 1;
					fraction = Math.abs(fraction);

					var closestRot = (endingGravityRot - startingGravityRot) * Math.round(fraction) + startingGravityRot;
					var rot;

					if (fraction <= 1.0 && fraction >= 0) { // don't allow extra values outside marble center in trig
						rot = (endingGravityRot - startingGravityRot) * fraction + startingGravityRot;
					} else {
						rot = closestRot;
					}

					var axis = switch (gravityAxis) {
						case "x":
							new Vector(1, 0, 0);
						case "y":
							new Vector(0, 1, 0);
						case "z":
							new Vector(0, 0, 1);
						case _:
							new Vector(0, 0, 0);
					};

					var qrot = new Quat();
					qrot.initRotateAxis(axis.x, axis.y, axis.z, Math.PI * -rot / 180);

					var p1 = new Vector(0.8, 0.2, 0);
					var p2 = new Vector(0.8, -0.2, 0);

					var qmat = new Matrix();
					qrot.toMatrix(qmat);

					var dir = new Vector(0, 0, 1);
					dir.transform3x3(qmat);

					var q = new Quat();
					q.initDirection(dir);
					var qmat2 = new Matrix();
					q.toMatrix(qmat2);

					p1.transform3x3(qmat2);
					p2.transform3x3(qmat2);

					var end = pt.add(dir);

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

	static var _ = PropertyProvider.registerPropertyProvider("AlterGravityTrigger", AlterGravityTriggerPropertyProvider);
}
