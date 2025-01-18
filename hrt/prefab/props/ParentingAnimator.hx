package hrt.prefab.props;

import h3d.Vector;
import hrt.prefab.l3d.TorqueObject;
import h3d.Matrix;
import hrt.mis.MisParser;

class ParentingAnimator {
	var obj:TorqueObject;
	var ctx:Context;
	var parentObj:TorqueObject;

	var relativeTransform:Matrix;
	var parentSimple:Bool;
	var parentOffset:Vector;
	var noRot:Bool;

	var dirtyProps:Bool;

	public function new(obj:TorqueObject, ctx:Context) {
		this.obj = obj;
		this.ctx = ctx;
		dirtyProps = true;
	}

	public function updateTransform(o:h3d.scene.Object) {
		if (dirtyProps) {
			var parentStr = obj.getDynamicFieldValue("parent");
			if (parentStr == "") {
				dirtyProps = false;
				return;
			}

			var rootObj:Prefab = obj.parent;
			while (rootObj.parent != null)
				rootObj = rootObj.parent;

			parentObj = cast(rootObj.getPrefabByName(parentStr), TorqueObject);
			var parentSimpleStr = obj.getDynamicFieldValue("parentsimple");
			var parentOffsetStr = obj.getDynamicFieldValue("parentoffset");
			var noRotStr = obj.getDynamicFieldValue("parentnorot");
			var parentModTransStr = obj.getDynamicFieldValue("parentmodtrans");
			parentOffset = MisParser.parseVector3(parentOffsetStr);
			parentOffset.x = -parentOffset.x;
			parentOffset.w = 0;

			if (parentModTransStr != "") {
				// Actual relative transform
				var vecValue = MisParser.parseVector3(parentModTransStr);
				vecValue.x = -vecValue.x;

				var rotOff = MisParser.parseNumberList(parentModTransStr);
				rotOff = rotOff.slice(3);
				while (rotOff.length < 4)
					rotOff.push(0);

				relativeTransform = new Matrix();

				var quat = new h3d.Quat();
				quat.initRotateAxis(rotOff[0], rotOff[1], rotOff[2], -rotOff[3] * Math.PI / 180);
				quat.x = -quat.x;
				quat.w = -quat.w;
				quat.toMatrix(relativeTransform);
				relativeTransform.setPosition(vecValue);
			}

			parentSimple = parentSimpleStr == "true" || parentSimpleStr == "1";
			noRot = noRotStr == "true" || noRotStr == "1";

			dirtyProps = false;
		}
		if (parentObj == null)
			return;

		var finalTransform = parentObj.getRenderTransform().clone();
		if (noRot) {
			var newMat = new Matrix();
			newMat.identity();
			newMat.setPosition(finalTransform.getPosition());
			finalTransform = newMat;
		}
		if (!parentSimple) {
			if (relativeTransform == null) {
				relativeTransform = new Matrix();
				var origTform = new Matrix();
				obj.getTransform(origTform);
				relativeTransform.multiply(origTform, parentObj.getTransform().getInverse());
			}
			finalTransform.multiply(relativeTransform, finalTransform);
		}
		var finalPos = finalTransform.getPosition().add(parentOffset);
		finalTransform.setPosition(finalPos);

		var invTform = o.parent.getInvPos();
		finalTransform.multiply(finalTransform, invTform);
		o.setTransform(finalTransform);
	}

	public function updateProps() {
		dirtyProps = true;
	}
}
