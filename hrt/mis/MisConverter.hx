package hrt.mis;

class MisConverter {
	var data:Dynamic;

	public function new(data:Dynamic) {
		this.data = data;
	}

	public function convert() {
		if (data.type == "prefab")
			return convertPrefab(data.children[0]);
		return null;
	}

	function convertPrefab(data:Dynamic) {
		switch (data.type) {
			case "simgroup":
				return convertSimGroup(data);

			case "scriptobject":
				return convertScriptObject(data);

			case "staticshape":
				return convertStaticShape(data);

			case 'spawnsphere':
				return convertSpawnSphere(data);

			case "tsstatic":
				return convertTSStatic(data);

			case "sun":
				return convertSun(data);

			case "sky":
				return convertSky(data);

			case "item":
				return convertItem(data);
			case "trigger":
				return convertTrigger(data);

			case "interiorinstance":
				return convertInteriorInstance(data);

			case "path":
				return convertPath(data);

			case "pathedinterior":
				return convertPathedInterior(data);
		}

		return null;
	}

	function convertSimGroup(data:Dynamic) {
		var sg = new hrt.mis.MissionElement.MissionElementSimGroup();
		sg._name = data.name;
		sg.elements = [];
		var itr = new haxe.iterators.DynamicAccessIterator(data.children);
		for (ch in itr) {
			var obj = convertPrefab(ch);
			sg.elements.push(obj);
		}
		return sg;
	}

	function convertScriptObject(data:Dynamic) {
		var so = new hrt.mis.MissionElement.MissionElementScriptObject();
		so._name = data.name;
		convertDynFields(data, so);
		return so;
	}

	function convertSun(data:Dynamic) {
		var so = new hrt.mis.MissionElement.MissionElementSun();
		so._name = data.name;
		so.direction = '${- data.directionX} ${data.directionY} ${data.directionZ}';
		var ambientVec = h3d.Vector.fromColor(data.ambient);
		so.ambient = '${ambientVec.r} ${ambientVec.g} ${ambientVec.b} ${ambientVec.a}';
		var colorVec = h3d.Vector.fromColor(data.diffuse);
		so.color = '${colorVec.r} ${colorVec.g} ${colorVec.b} ${colorVec.a}';
		convertDynFields(data, so);
		return so;
	}

	function convertSky(data:Dynamic) {
		var so = new hrt.mis.MissionElement.MissionElementSky();
		so._name = data.name;
		var fogVec = h3d.Vector.fromColor(data.fogColor);
		so.fogcolor = '${fogVec.r} ${fogVec.g} ${fogVec.b} ${fogVec.a}';
		var skySolidColorVec = h3d.Vector.fromColor(data.skySolidColor);
		so.skysolidcolor = '${skySolidColorVec.r} ${skySolidColorVec.g} ${skySolidColorVec.b} ${skySolidColorVec.a}';
		so.useskytextures = '${data.useSkyTextures ?? true}';
		so.materiallist = '~/' + data.materialList;
		convertDynFields(data, so);
		return so;
	}

	function convertStaticShape(data:Dynamic) {
		var ss = new hrt.mis.MissionElement.MissionElementStaticShape();
		ss._name = data.name;
		ss.datablock = data.customFieldProvider;
		ss.position = '${- (data.x ?? 0.0)} ${data.y ?? 0.0} ${data.z ?? 0.0}';
		ss.scale = '${data.scaleX ?? 1.0} ${data.scaleY ?? 1.0} ${data.scaleZ ?? 1.0}';
		var quat = new h3d.Quat(data.rotationX ?? 0.0, data.rotationY ?? 0.0, data.rotationZ ?? 0.0, data.rotationW ?? 1.0);
		quat.x = -quat.x;
		quat.w = -quat.w;
		var angle = 2 * Math.acos(quat.w);
		var s = Math.sqrt(1 - quat.w * quat.w);
		var x, y, z;
		if (s < 0.001) {
			x = quat.x;
			y = quat.y;
			z = quat.z;
		} else {
			x = quat.x / s;
			y = quat.y / s;
			z = quat.z / s;
		}
		angle = (angle * -180.0 / Math.PI) % 360.0;
		ss.rotation = '${x} ${y} ${z} ${angle}';
		convertDynFields(data, ss);

		return ss;
	}

	function convertSpawnSphere(data:Dynamic) {
		var ss = new hrt.mis.MissionElement.MissionElementSpawnSphere();
		ss._name = data.name;
		ss.datablock = data.customFieldProvider;
		ss.position = '${- (data.x ?? 0.0)} ${data.y ?? 0.0} ${data.z ?? 0.0}';
		ss.scale = '${data.scaleX ?? 1.0} ${data.scaleY ?? 1.0} ${data.scaleZ ?? 1.0}';
		var quat = new h3d.Quat(data.rotationX ?? 0.0, data.rotationY ?? 0.0, data.rotationZ ?? 0.0, data.rotationW ?? 1.0);
		quat.x = -quat.x;
		quat.w = -quat.w;
		var angle = 2 * Math.acos(quat.w);
		var s = Math.sqrt(1 - quat.w * quat.w);
		var x, y, z;
		if (s < 0.001) {
			x = quat.x;
			y = quat.y;
			z = quat.z;
		} else {
			x = quat.x / s;
			y = quat.y / s;
			z = quat.z / s;
		}
		angle = (angle * -180.0 / Math.PI) % 360.0;
		ss.rotation = '${x} ${y} ${z} ${angle}';
		convertDynFields(data, ss);

		return ss;
	}

	function convertTSStatic(data:Dynamic) {
		var ss = new hrt.mis.MissionElement.MissionElementTSStatic();
		ss._name = data.name;
		ss.position = '${- (data.x ?? 0.0)} ${data.y ?? 0.0} ${data.z ?? 0.0}';
		ss.scale = '${data.scaleX ?? 1.0} ${data.scaleY ?? 1.0} ${data.scaleZ ?? 1.0}';
		var quat = new h3d.Quat(data.rotationX ?? 0.0, data.rotationY ?? 0.0, data.rotationZ ?? 0.0, data.rotationW ?? 1.0);
		quat.x = -quat.x;
		quat.w = -quat.w;
		var angle = 2 * Math.acos(quat.w);
		var s = Math.sqrt(1 - quat.w * quat.w);
		var x, y, z;
		if (s < 0.001) {
			x = quat.x;
			y = quat.y;
			z = quat.z;
		} else {
			x = quat.x / s;
			y = quat.y / s;
			z = quat.z / s;
		}
		angle = (angle * -180.0 / Math.PI) % 360.0;
		ss.rotation = '${x} ${y} ${z} ${angle}';
		ss.shapename = '~/' + data.shapePath;
		convertDynFields(data, ss);

		return ss;
	}

	function convertItem(data:Dynamic) {
		var ss = new hrt.mis.MissionElement.MissionElementItem();
		ss._name = data.name;
		ss.datablock = data.customFieldProvider;
		ss.position = '${- (data.x ?? 0.0)} ${data.y ?? 0.0} ${data.z ?? 0.0}';
		ss.scale = '${data.scaleX ?? 1.0} ${data.scaleY ?? 1.0} ${data.scaleZ ?? 1.0}';
		var quat = new h3d.Quat(data.rotationX ?? 0.0, data.rotationY ?? 0.0, data.rotationZ ?? 0.0, data.rotationW ?? 1.0);
		quat.x = -quat.x;
		quat.w = -quat.w;
		var angle = 2 * Math.acos(quat.w);
		var s = Math.sqrt(1 - quat.w * quat.w);
		var x, y, z;
		if (s < 0.001) {
			x = quat.x;
			y = quat.y;
			z = quat.z;
		} else {
			x = quat.x / s;
			y = quat.y / s;
			z = quat.z / s;
		}
		angle = (angle * -180.0 / Math.PI) % 360.0;
		ss.rotation = '${x} ${y} ${z} ${angle}';

		ss.isStatic = '${data.isStatic ?? true}';
		ss.rotate = '${data.rotate ?? true}';
		ss.collideable = '${data.collideable ?? "true"}';

		convertDynFields(data, ss);

		return ss;
	}

	function convertTrigger(data:Dynamic) {
		var t = new hrt.mis.MissionElement.MissionElementTrigger();
		t._name = data.name;
		t.datablock = data.customFieldProvider;
		t.position = '${- (data.x ?? 0.0)} ${data.y ?? 0.0} ${data.z ?? 0.0}';
		t.scale = '${data.scaleX ?? 1.0} ${data.scaleY ?? 1.0} ${data.scaleZ ?? 1.0}';
		var quat = new h3d.Quat(data.rotationX ?? 0.0, data.rotationY ?? 0.0, data.rotationZ ?? 0.0, data.rotationW ?? 1.0);
		quat.x = -quat.x;
		quat.w = -quat.w;
		var angle = 2 * Math.acos(quat.w);
		var s = Math.sqrt(1 - quat.w * quat.w);
		var x, y, z;
		if (s < 0.001) {
			x = quat.x;
			y = quat.y;
			z = quat.z;
		} else {
			x = quat.x / s;
			y = quat.y / s;
			z = quat.z / s;
		}
		angle = (angle * -180.0 / Math.PI) % 360.0;
		t.rotation = '${x} ${y} ${z} ${angle}';
		t.polyhedron = '${- data.origin.x} ${data.origin.y} ${data.origin.z} ${- data.e1.x} ${data.e1.y} ${data.e1.z} ${- data.e2.x} ${data.e2.y} ${data.e2.z} ${- data.e3.x} ${data.e3.y} ${data.e3.z}';

		convertDynFields(data, t);

		return t;
	}

	function convertInteriorInstance(data:Dynamic) {
		var ss = new hrt.mis.MissionElement.MissionElementInteriorInstance();
		ss._name = data.name;
		ss.position = '${- (data.x ?? 0.0)} ${data.y ?? 0.0} ${data.z ?? 0.0}';
		ss.scale = '${data.scaleX ?? 1.0} ${data.scaleY ?? 1.0} ${data.scaleZ ?? 1.0}';
		var quat = new h3d.Quat(data.rotationX ?? 0.0, data.rotationY ?? 0.0, data.rotationZ ?? 0.0, data.rotationW ?? 1.0);
		quat.x = -quat.x;
		quat.w = -quat.w;
		var angle = 2 * Math.acos(quat.w);
		var s = Math.sqrt(1 - quat.w * quat.w);
		var x, y, z;
		if (s < 0.001) {
			x = quat.x;
			y = quat.y;
			z = quat.z;
		} else {
			x = quat.x / s;
			y = quat.y / s;
			z = quat.z / s;
		}
		angle = (angle * -180.0 / Math.PI) % 360.0;
		ss.rotation = '${x} ${y} ${z} ${angle}';
		ss.interiorfile = '~/' + data.path;

		convertDynFields(data, ss);

		return ss;
	}

	function convertPath(data:Dynamic) {
		var p = new hrt.mis.MissionElement.MissionElementPath();
		p._name = data.name;
		p.markers = [];
		var itr = new haxe.iterators.DynamicAccessIterator(data.children);
		for (ch in itr) {
			var marker = new hrt.mis.MissionElement.MissionElementMarker();
			marker._name = ch.name;
			marker.position = '${- (ch.x ?? 0.0)} ${ch.y ?? 0.0} ${ch.z ?? 0.0}';
			marker.scale = '${ch.scaleX ?? 1.0} ${ch.scaleY ?? 1.0} ${ch.scaleZ ?? 1.0}';
			var quat = new h3d.Quat(data.rotationX ?? 0.0, data.rotationY ?? 0.0, data.rotationZ ?? 0.0, data.rotationW ?? 1.0);
			quat.x = -quat.x;
			quat.w = -quat.w;
			var angle = 2 * Math.acos(quat.w);
			var s = Math.sqrt(1 - quat.w * quat.w);
			var x, y, z;
			if (s < 0.001) {
				x = 1.0;
				y = 0.0;
				z = 0.0;
			} else {
				x = quat.x / s;
				y = quat.y / s;
				z = quat.z / s;
			}
			angle = (angle * -180.0 / Math.PI) % 360.0;
			marker.rotation = '${x} ${y} ${z} ${angle}';
			marker.seqnum = '${ch.seqNum ?? 0}';
			marker.mstonext = '${ch.msToNext ?? 0}';
			marker.smoothingtype = '${ch.smoothingType ?? 0}';

			convertDynFields(ch, marker);

			p.markers.push(marker);
		}
		convertDynFields(data, p);

		return p;
	}

	function convertPathedInterior(data:Dynamic) {
		var ss = new hrt.mis.MissionElement.MissionElementPathedInterior();
		ss._name = data.name;
		ss.position = '0 0 0';
		ss.rotation = '1 0 0 0';
		ss.scale = '1 1 1';
		ss.baseposition = '${- (data.x ?? 0.0)} ${data.y ?? 0.0} ${data.z ?? 0.0}';
		ss.basescale = '${data.scaleX ?? 1.0} ${data.scaleY ?? 1.0} ${data.scaleZ ?? 1.0}';
		var quat = new h3d.Quat(data.rotationX ?? 0.0, data.rotationY ?? 0.0, data.rotationZ ?? 0.0, data.rotationW ?? 1.0);
		quat.x = -quat.x;
		quat.w = -quat.w;
		var angle = 2 * Math.acos(quat.w);
		var s = Math.sqrt(1 - quat.w * quat.w);
		var x, y, z;
		if (s < 0.001) {
			x = quat.x;
			y = quat.y;
			z = quat.z;
		} else {
			x = quat.x / s;
			y = quat.y / s;
			z = quat.z / s;
		}
		angle = (angle * -180.0 / Math.PI) % 360.0;
		ss.baserotation = '${x} ${y} ${z} ${angle}';
		ss.interiorresource = 'marble/' + data.path; // Need to fix???
		ss.initialpathposition = '${data.initialPathPosition ?? 0}';
		ss.initialtargetposition = '${data.initialTargetPosition ?? 0}';
		ss.interiorindex = '${data.so ?? 0}';

		convertDynFields(data, ss);

		return ss;
	}

	function convertDynFields(data:Dynamic, obj:hrt.mis.MissionElement.MissionElementBase) {
		if (data.dynamicFields != null) {
			var itr = new haxe.iterators.DynamicAccessIterator(data.dynamicFields);
			for (ch in itr) {
				obj._dynamicFields.set(ch.field, ch.value);
			}
		}
		if (data.customFields != null) {
			var itr = new haxe.iterators.DynamicAccessIterator(data.customFields);
			for (ch in itr) {
				obj._dynamicFields.set(ch.field, ch.value);
			}
		}
	}
}
