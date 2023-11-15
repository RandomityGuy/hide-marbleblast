package hrt.prefab.props;

import h3d.Vector;
import h3d.Quat;
import h3d.Matrix;
import hrt.mis.MisParser;

class GravityTriggerPropertyProvider extends PropertyProvider {
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
		if (['simrotation'].contains(p)) {
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
		var simRotationStr = obj.getCustomFieldValue("simrotation");
		var simRotation = MisParser.parseRotation(simRotationStr);
		simRotation.x = -simRotation.x;
		simRotation.w = -simRotation.w;

		var bounds = ctx.local3d.getBounds();

		g.clear();

		var qmat = new Matrix();
		simRotation.toMatrix(qmat);

		var dir = new Vector(0, 0, 1);
		dir.transform3x3(qmat);

		var x = bounds.xMin;
		while (x <= bounds.xMax) {
			var y = bounds.yMin;
			while (y <= bounds.yMax) {
				var z = bounds.zMin;
				while (z <= bounds.zMax) {
					var pt = new Vector(x, y, z);

					var end = pt.add(dir);

					var q = new Quat();
					q.initDirection(dir);

					var p1 = new Vector(0.8, 0.2, 0);
					var p2 = new Vector(0.8, -0.2, 0);

					var qmat2 = new Matrix();
					q.toMatrix(qmat2);
					p1.transform3x3(qmat2);
					p2.transform3x3(qmat2);

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

	static var _ = PropertyProvider.registerPropertyProvider("GravityTrigger", GravityTriggerPropertyProvider);
}
