package hrt.prefab.props;

import h3d.Vector;
import h3d.Quat;
import h3d.Matrix;
import hrt.mis.MisParser;

class LapsTriggerPropertyProvider extends PropertyProvider {
	var g1:h3d.scene.Sphere;
	var g2:h3d.scene.Graphics;

	var selected:Bool = false;

	#if editor
	override function onSelected(s:Bool) {
		selected = s;
		if (g1 != null)
			g1.visible = s;
		if (g2 != null)
			g2.visible = s;
	}
	#end

	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);
		if (g1 == null) {
			g1 = new h3d.scene.Sphere(0xFFFF0000, 1, true, ctx.local3d);
			g1.ignoreParentTransform = true;
			g1.material.mainPass.setPassName("overlay");
			g1.material.mainPass.depth(false, LessEqual);
			g1.visible = selected;
			g1.ignoreBounds = true;
		}
		if (g2 == null) {
			g2 = new h3d.scene.Graphics(ctx.local3d);
			g2.ignoreParentTransform = true;
			g2.material.mainPass.setPassName("overlay");
			g2.material.mainPass.depth(false, LessEqual);
			g2.visible = selected;
			g2.lineStyle(2, 0xFFFF0000);
			g2.ignoreBounds = true;
		}
		updateGraphics(ctx);

		// drawCannonTrajectory();
	}

	override function onPropertyChanged(ctx:EditContext, p:String) {
		super.onPropertyChanged(ctx, p);
		if (p == 'spawnpoint') {
			updateGraphics(ctx.getContext(obj));
		}
	}

	override function onTransformApplied() {
		super.onTransformApplied();
	}

	function updateGraphics(ctx:Context) {
		var spawnPointStr = obj.getCustomFieldValue('spawnpoint');
		var spawnPoint = null;
		var spawnRot = null;
		if (spawnPointStr == "") {
			spawnPoint = ctx.local3d.getBounds().getCenter().toVector();
			spawnRot = ctx.local3d.getRotationQuat();
		} else {
			var vecValue = MisParser.parseVector3(spawnPointStr);
			vecValue.x = -vecValue.x;

			var rotOff = MisParser.parseNumberList(spawnPointStr);
			rotOff = rotOff.slice(3);
			while (rotOff.length < 4)
				rotOff.push(0);

			var quat = new Quat();
			quat.initRotateAxis(rotOff[0], rotOff[1], rotOff[2], -rotOff[3] * Math.PI / 180);
			quat.x = -quat.x;
			quat.w = -quat.w;
			spawnPoint = vecValue;
			spawnRot = quat;
		}

		g1.setPosition(spawnPoint.x, spawnPoint.y, spawnPoint.z);

		var dir = new Vector(0, 3, 0);
		var dir2 = new Vector(0.2, 2.8, 0);
		var dir3 = new Vector(-0.2, 2.8, 0);
		var mat = new Matrix();
		spawnRot.toMatrix(mat);
		dir.transform3x3(mat);
		dir2.transform3x3(mat);
		dir3.transform3x3(mat);

		g2.clear();
		g2.moveTo(spawnPoint.x, spawnPoint.y, spawnPoint.z);
		g2.lineTo(spawnPoint.x + dir.x, spawnPoint.y + dir.y, spawnPoint.z + dir.z);
		g2.moveTo(spawnPoint.x + dir.x, spawnPoint.y + dir.y, spawnPoint.z + dir.z);
		g2.lineTo(spawnPoint.x + dir2.x, spawnPoint.y + dir2.y, spawnPoint.z + dir2.z);
		g2.moveTo(spawnPoint.x + dir.x, spawnPoint.y + dir.y, spawnPoint.z + dir.z);
		g2.lineTo(spawnPoint.x + dir3.x, spawnPoint.y + dir3.y, spawnPoint.z + dir3.z);
	}

	static var _ = PropertyProvider.registerPropertyProvider("LapsCheckpoint", LapsTriggerPropertyProvider);
	static var _2 = PropertyProvider.registerPropertyProvider("LapsCounterTrigger", LapsTriggerPropertyProvider);
}
