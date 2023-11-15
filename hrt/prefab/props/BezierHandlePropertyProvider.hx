package hrt.prefab.props;

import hrt.prefab.l3d.TorqueObject;

using Lambda;

class BezierHandlePropertyProvider extends PropertyProvider {
	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);
		propagateDrawPaths();
	}

	function propagateDrawPaths() {
		var rootObj:Prefab = obj.parent;
		while (rootObj.parent != null)
			rootObj = rootObj.parent;
		var relatives = rootObj.findAll(x -> {
			if (x is TorqueObject) {
				var xto = cast(x, TorqueObject);
				var found = xto.customFields.find(x -> (x.field == 'bezierhandle1' || x.field == 'bezierhandle2') && x.value == obj.name);
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

	override function onTransformApplied() {
		propagateDrawPaths();
	}

	static var _ = PropertyProvider.registerPropertyProvider("BezierHandle", BezierHandlePropertyProvider);
}
