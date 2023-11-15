package hrt.mis;

import h3d.Vector;
import h3d.Matrix;
import hrt.mis.MissionElement.MissionElementSimGroup;
import hrt.mis.MissionElement.MissionElementPathedInterior;
import hrt.mis.MissionElement.MissionElementPath;
import hrt.mis.MissionElement.MissionElementBase;
import hrt.mis.MissionElement.MissionElementParticleEmitterNode;
import hrt.mis.MissionElement.MissionElementTSStatic;
import hrt.mis.MissionElement.MissionElementMessageVector;
import hrt.mis.MissionElement.MissionElementAudioProfile;
import hrt.mis.MissionElement.MissionElementTrigger;
import hrt.mis.MissionElement.MissionElementMarker;
import hrt.mis.MissionElement.MissionElementItem;
import hrt.mis.MissionElement.MissionElementStaticShape;
import hrt.mis.MissionElement.MissionElementInteriorInstance;
import hrt.mis.MissionElement.MissionElementSun;
import hrt.mis.MissionElement.MissionElementSky;
import hrt.mis.MissionElement.MissionElementMissionArea;
import hrt.mis.MissionElement.MissionElementType;
import hrt.mis.MissionElement.MissionElementScriptObject;

@:publicFields
class MisFile {
	var root:MissionElementSimGroup;

	/** The custom marble attributes overrides specified in the file. */
	var marbleAttributes:Map<String, String>;

	var activatedPackages:Array<String>;

	public function new() {}

	public function toHeapsJSON() {
		var _jsonDynamic = [];
		addSimGroup(root, _jsonDynamic);
		var finalJsonObj = {
			type: "prefab",
			children: _jsonDynamic
		};
		return finalJsonObj;
	}

	function addSimGroup(sg:MissionElementSimGroup, _jsonDynamic:Array<Dynamic>) {
		var childrenDynamic:Array<Dynamic> = [];

		for (element in sg.elements) {
			switch (element._type) {
				case MissionElementType.SimGroup:
					this.addSimGroup(cast element, childrenDynamic);
				case MissionElementType.InteriorInstance:
					this.addInteriorFromMis(cast element, childrenDynamic);
				case MissionElementType.PathedInterior:
					this.addPathedInterior(cast element, childrenDynamic);
				case MissionElementType.Path:
					this.addPath(cast element, childrenDynamic);
				case MissionElementType.StaticShape:
					this.addStaticShape(cast element, childrenDynamic);
				case MissionElementType.Item:
					this.addItem(cast element, childrenDynamic);
				case MissionElementType.Trigger:
					this.addTrigger(cast element, childrenDynamic);
				case MissionElementType.TSStatic:
					this.addTSStatic(cast element, childrenDynamic);
				case MissionElementType.Sun:
					this.addSun(cast element, childrenDynamic);
				case MissionElementType.Sky:
					this.addSky(cast element, childrenDynamic);
				case MissionElementType.ScriptObject:
					this.addScriptObject(cast element, childrenDynamic);
				default:
			}
		}

		var sgObject = {
			type: "simgroup",
			name: sg._name != null && sg._name != "" ? sg._name : "SimGroup",
			children: childrenDynamic,
			dynamicFields: []
		};

		for (f => v in sg._dynamicFields) {
			sgObject.dynamicFields.push({field: f, value: v});
		}

		_jsonDynamic.push(sgObject);
	}

	static function unescape(str:String) {
		var specialCases = [
			'\\t' => '\t',
			'\\v' => '\x0B',
			'\\0' => '\x00',
			'\\f' => '\x0C',
			'\\n' => '\n',
			'\\r' => '\r',
			"\\'" => "'"
		];

		for (obj => esc in specialCases) {
			str = StringTools.replace(str, obj, esc);
		}

		return str;
	}

	function getDifPath(rawElementPath:String) {
		if (StringTools.contains(rawElementPath, "$usermods")) {
			rawElementPath = rawElementPath.split("@").slice(1).map(x -> {
				var a = StringTools.trim(x);
				a = unescape(a.substr(1, a.length - 2));
				return a;
			}).join('');
		}
		var fname = rawElementPath.substring(rawElementPath.lastIndexOf('/') + 1);
		rawElementPath = rawElementPath.toLowerCase();
		var path = StringTools.replace(rawElementPath.substring(rawElementPath.indexOf('data/')), "\"", "");
		if (!StringTools.endsWith(path, ".dif"))
			path += ".dif";
		if (StringTools.contains(path, 'interiors_mbg/'))
			path = StringTools.replace(path, 'interiors_mbg/', 'interiors/');
		var dirpath = path.substring(0, path.lastIndexOf('/') + 1);
		if (hxd.res.Loader.currentInstance.fs.exists(path))
			return path;
		if (hxd.res.Loader.currentInstance.fs.exists(dirpath + fname))
			return dirpath + fname;
		var goldpath = StringTools.replace(path, 'interiors/', 'interiors_mbg/');
		if (hxd.res.Loader.currentInstance.fs.exists(goldpath))
			return goldpath;
		path = StringTools.replace(path, "lbinteriors", "interiors");
		if (hxd.res.Loader.currentInstance.fs.exists(path))
			return path;
		return "";
	}

	function addInteriorFromMis(element:MissionElementInteriorInstance, _jsonDynamic:Array<Dynamic>) {
		var difPath = getDifPath(element.interiorfile);
		if (difPath == "") {
			return;
		}

		var interiorPosition = MisParser.parseVector3(element.position);
		interiorPosition.x = -interiorPosition.x;
		var interiorRotation = MisParser.parseRotation(element.rotation);
		interiorRotation.x = -interiorRotation.x;
		interiorRotation.w = -interiorRotation.w;
		var interiorScale = MisParser.parseVector3(element.scale);
		var trueScale = interiorScale.clone();
		// var hasCollision = interiorScale.x != = 0 && interiorScale.y != = 0 && interiorScale.z != = 0; // Don't want to add buggy geometry

		var zeroScale = interiorScale.x == 0 || interiorScale.y == 0 || interiorScale.z == 0;
		if (interiorScale.x == 0)
			interiorScale.x = 0.0015;
		if (interiorScale.y == 0)
			interiorScale.y = 0.0015;
		if (interiorScale.z == 0)
			interiorScale.z = 0.0015;

		var mat = Matrix.S(interiorScale.x, interiorScale.y, interiorScale.z);
		var tmp = new Matrix();
		interiorRotation.toMatrix(tmp);
		mat.multiply3x4(mat, tmp);
		var tmat = Matrix.T(interiorPosition.x, interiorPosition.y, interiorPosition.z);
		mat.multiply(mat, tmat);
		// itr.loadFromPath(difPath);

		var rot = mat.getEulerAngles();
		var s = trueScale;

		var obj:Dynamic = {
			type: "interiorinstance",
			name: element._name != null ? element._name : "",
			path: difPath,
			x: mat.tx,
			y: mat.ty,
			z: mat.tz,
			scaleX: s.x,
			scaleY: s.y,
			scaleZ: s.z,
			rotationX: rot.x * 180.0 / Math.PI,
			rotationY: rot.y * 180.0 / Math.PI,
			rotationZ: rot.z * 180.0 / Math.PI,
			dynamicFields: []
		};

		for (f => v in element._dynamicFields) {
			obj.dynamicFields.push({field: f, value: v});
		}

		_jsonDynamic.push(obj);
	}

	function addPathedInterior(element:MissionElementPathedInterior, _jsonDynamic:Array<Dynamic>) {
		var difPath = getDifPath(element.interiorresource);
		if (difPath == "") {
			return;
		}

		var interiorPosition = MisParser.parseVector3(element.baseposition);
		interiorPosition.x = -interiorPosition.x;
		var interiorRotation = MisParser.parseRotation(element.baserotation);
		interiorRotation.x = -interiorRotation.x;
		interiorRotation.w = -interiorRotation.w;
		var interiorScale = MisParser.parseVector3(element.basescale);
		var trueScale = interiorScale.clone();

		var mat = Matrix.S(interiorScale.x, interiorScale.y, interiorScale.z);
		var tmp = new Matrix();
		interiorRotation.toMatrix(tmp);
		mat.multiply3x4(mat, tmp);
		var tmat = Matrix.T(interiorPosition.x, interiorPosition.y, interiorPosition.z);
		mat.multiply(mat, tmat);

		var rot = mat.getEulerAngles();
		var s = trueScale;

		var targetPos = element.initialtargetposition != ""
			&& element.initialtargetposition != null ? MisParser.parseNumber(element.initialtargetposition) : 0;

		var pathPos = element.initialpathposition != ""
			&& element.initialpathposition != null ? MisParser.parseNumber(element.initialpathposition) : 0;

		var obj:Dynamic = {
			type: "pathedinterior",
			name: element._name != null ? element._name : "",
			path: difPath,
			so: MisParser.parseNumber(element.interiorindex),
			x: mat.tx,
			y: mat.ty,
			z: mat.tz,
			scaleX: s.x,
			scaleY: s.y,
			scaleZ: s.z,
			rotationX: rot.x * 180.0 / Math.PI,
			rotationY: rot.y * 180.0 / Math.PI,
			rotationZ: rot.z * 180.0 / Math.PI,
			initialTargetPosition: targetPos,
			initialPathPosition: pathPos,
			pathType: switch (targetPos) {
				case -1:
					1;
				case -2:
					2;
				default:
					0;
			},
			dynamicFields: []
		};

		for (f => v in element._dynamicFields) {
			obj.dynamicFields.push({field: f, value: v});
		}

		_jsonDynamic.push(obj);
	}

	function addPath(element:MissionElementPath, _jsonDynamic:Array<Dynamic>) {
		var markerObjs:Array<Dynamic> = [];

		for (marker in element.markers) {
			var shapePosition = MisParser.parseVector3(marker.position);
			shapePosition.x = -shapePosition.x;
			var shapeRotation = MisParser.parseRotation(marker.rotation);
			shapeRotation.x = -shapeRotation.x;
			shapeRotation.w = -shapeRotation.w;
			var shapeScale = MisParser.parseVector3(marker.scale);
			var trueScale = shapeScale.clone();

			var zeroScale = shapeScale.x == 0 || shapeScale.y == 0 || shapeScale.z == 0;
			if (shapeScale.x == 0)
				shapeScale.x = 0.0015;
			if (shapeScale.y == 0)
				shapeScale.y = 0.0015;
			if (shapeScale.z == 0)
				shapeScale.z = 0.0015;

			var mat = Matrix.S(shapeScale.x, shapeScale.y, shapeScale.z);
			var tmp = new Matrix();
			shapeRotation.toMatrix(tmp);
			mat.multiply3x4(mat, tmp);
			var tmat = Matrix.T(shapePosition.x, shapePosition.y, shapePosition.z);
			mat.multiply(mat, tmat);

			var rot = mat.getEulerAngles();
			var s = trueScale;

			var obj:Dynamic = {
				type: "marker",
				name: marker._name != null ? marker._name : "",
				x: mat.tx,
				y: mat.ty,
				z: mat.tz,
				scaleX: s.x,
				scaleY: s.y,
				scaleZ: s.z,
				rotationX: rot.x * 180.0 / Math.PI,
				rotationY: rot.y * 180.0 / Math.PI,
				rotationZ: rot.z * 180.0 / Math.PI,
				seqNum: MisParser.parseNumber(marker.seqnum),
				msToNext: MisParser.parseNumber(marker.mstonext),
				smoothingType: switch (marker.smoothingtype) {
					case "Accelerate":
						1;
					case "Spline":
						2;
					default:
						0;
				}
			}

			markerObjs.push(obj);
		}

		_jsonDynamic.push({
			type: "path",
			name: element._name != null ? element._name : "",
			children: markerObjs,
		});
	}

	function addStaticShape(element:MissionElementStaticShape, _jsonDynamic:Array<Dynamic>) {
		var dataBlockLowerCase = element.datablock.toLowerCase();

		if (TorqueConfig.getDataBlock(dataBlockLowerCase) == null)
			return;

		var shapePosition = MisParser.parseVector3(element.position);
		shapePosition.x = -shapePosition.x;
		var shapeRotation = MisParser.parseRotation(element.rotation);
		shapeRotation.x = -shapeRotation.x;
		shapeRotation.w = -shapeRotation.w;
		var shapeScale = MisParser.parseVector3(element.scale);
		var trueScale = shapeScale.clone();

		var zeroScale = shapeScale.x == 0 || shapeScale.y == 0 || shapeScale.z == 0;
		if (shapeScale.x == 0)
			shapeScale.x = 0.0015;
		if (shapeScale.y == 0)
			shapeScale.y = 0.0015;
		if (shapeScale.z == 0)
			shapeScale.z = 0.0015;

		var mat = Matrix.S(shapeScale.x, shapeScale.y, shapeScale.z);
		var tmp = new Matrix();
		shapeRotation.toMatrix(tmp);
		mat.multiply3x4(mat, tmp);
		var tmat = Matrix.T(shapePosition.x, shapePosition.y, shapePosition.z);
		mat.multiply(mat, tmat);

		var obj = addDTS(dataBlockLowerCase, "staticshape", mat, _jsonDynamic, element._name != null ? element._name : "", trueScale);
		obj.dynamicFields = [];
		obj.customFieldProvider = dataBlockLowerCase;
		obj.customFields = [];

		var dbDef = TorqueConfig.getDataBlock(dataBlockLowerCase);

		for (f => v in element._dynamicFields) {
			if (!dbDef.fieldMap.exists(f.toLowerCase())) {
				obj.dynamicFields.push({field: f, value: v});
			} else {
				obj.customFields.push({field: f, value: v});
			}
			if (f == "skin")
				obj.skin = v;
		}
	}

	function addItem(element:MissionElementItem, _jsonDynamic:Array<Dynamic>) {
		var dataBlockLowerCase = element.datablock.toLowerCase();

		if (TorqueConfig.getDataBlock(dataBlockLowerCase) == null)
			return;

		var shapePosition = MisParser.parseVector3(element.position);
		shapePosition.x = -shapePosition.x;
		var shapeRotation = MisParser.parseRotation(element.rotation);
		shapeRotation.x = -shapeRotation.x;
		shapeRotation.w = -shapeRotation.w;
		var shapeScale = MisParser.parseVector3(element.scale);
		var trueScale = shapeScale.clone();

		var zeroScale = shapeScale.x == 0 || shapeScale.y == 0 || shapeScale.z == 0;
		if (shapeScale.x == 0)
			shapeScale.x = 0.0015;
		if (shapeScale.y == 0)
			shapeScale.y = 0.0015;
		if (shapeScale.z == 0)
			shapeScale.z = 0.0015;

		var mat = Matrix.S(shapeScale.x, shapeScale.y, shapeScale.z);
		var tmp = new Matrix();
		shapeRotation.toMatrix(tmp);
		mat.multiply3x4(mat, tmp);
		var tmat = Matrix.T(shapePosition.x, shapePosition.y, shapePosition.z);
		mat.multiply(mat, tmat);

		var itemObj = addDTS(dataBlockLowerCase, "item", mat, _jsonDynamic, element._name != null ? element._name : "", trueScale);
		itemObj.isStatic = element.isStatic;
		itemObj.rotate = element.rotate;
		itemObj.collideable = element.collideable;
		itemObj.dynamicFields = [];
		itemObj.customFields = [];
		itemObj.customFieldProvider = dataBlockLowerCase;

		var dbDef = TorqueConfig.getDataBlock(dataBlockLowerCase);

		for (f => v in element._dynamicFields) {
			if (!dbDef.fieldMap.exists(f.toLowerCase())) {
				itemObj.dynamicFields.push({field: f, value: v});
			} else {
				itemObj.customFields.push({field: f, value: v});
			}
		}
	}

	function addTrigger(element:MissionElementTrigger, _jsonDynamic:Array<Dynamic>) {
		var coordinates = MisParser.parseNumberList(element.polyhedron);

		var origin = new Vector(-coordinates[0], coordinates[1], coordinates[2]);
		var d1 = new Vector(-coordinates[3], coordinates[4], coordinates[5]);
		var d2 = new Vector(-coordinates[6], coordinates[7], coordinates[8]);
		var d3 = new Vector(-coordinates[9], coordinates[10], coordinates[11]);

		var mat = new Matrix();
		var quat = MisParser.parseRotation(element.rotation);
		quat.x = -quat.x;
		quat.w = -quat.w;
		quat.toMatrix(mat);
		var scale = MisParser.parseVector3(element.scale);
		mat.scale(scale.x, scale.y, scale.z);
		var pos = MisParser.parseVector3(element.position);
		pos.x = -pos.x;

		var rot = mat.getEulerAngles();
		var s = mat.getScale();

		var obj:Dynamic = {
			type: "trigger",
			name: element._name != null ? element._name : "",
			x: pos.x,
			y: pos.y,
			z: pos.z,
			scaleX: s.x,
			scaleY: s.y,
			scaleZ: s.z,
			rotationX: rot.x * 180.0 / Math.PI,
			rotationY: rot.y * 180.0 / Math.PI,
			rotationZ: rot.z * 180.0 / Math.PI,
			origin: {
				x: origin.x,
				y: origin.y,
				z: origin.z
			},
			e1: {
				x: d1.x,
				y: d1.y,
				z: d1.z
			},
			e2: {
				x: d2.x,
				y: d2.y,
				z: d2.z
			},
			e3: {
				x: d3.x,
				y: d3.y,
				z: d3.z
			},
			dynamicFields: [],
			customFields: [],
			customFieldProvider: element.datablock.toLowerCase()
		};

		var dbDef = TorqueConfig.getDataBlock(element.datablock.toLowerCase());

		for (f => v in element._dynamicFields) {
			if (!dbDef.fieldMap.exists(f.toLowerCase())) {
				obj.dynamicFields.push({field: f, value: v});
			} else {
				obj.customFields.push({field: f, value: v});
			}
		}

		_jsonDynamic.push(obj);
	}

	function addTSStatic(element:MissionElementTSStatic, _jsonDynamic:Array<Dynamic>) {
		var shapePosition = MisParser.parseVector3(element.position);
		shapePosition.x = -shapePosition.x;
		var shapeRotation = MisParser.parseRotation(element.rotation);
		shapeRotation.x = -shapeRotation.x;
		shapeRotation.w = -shapeRotation.w;
		var shapeScale = MisParser.parseVector3(element.scale);
		var trueScale = shapeScale.clone();

		var zeroScale = shapeScale.x == 0 || shapeScale.y == 0 || shapeScale.z == 0;
		if (shapeScale.x == 0)
			shapeScale.x = 0.0015;
		if (shapeScale.y == 0)
			shapeScale.y = 0.0015;
		if (shapeScale.z == 0)
			shapeScale.z = 0.0015;

		var mat = Matrix.S(shapeScale.x, shapeScale.y, shapeScale.z);
		var tmp = new Matrix();
		shapeRotation.toMatrix(tmp);
		mat.multiply3x4(mat, tmp);
		var tmat = Matrix.T(shapePosition.x, shapePosition.y, shapePosition.z);
		mat.multiply(mat, tmat);

		var dtsPath = StringTools.replace(StringTools.replace(getProperFilepath(element.shapename), "marble/", ""), "platinum/", "");
		var rot = mat.getEulerAngles();

		var obj:Dynamic = {
			type: 'tsstatic',
			name: element._name != null ? element._name : "",
			path: dtsPath,
			shapePath: dtsPath,
			skin: null,
			x: mat.tx,
			y: mat.ty,
			z: mat.tz,
			scaleX: trueScale.x,
			scaleY: trueScale.y,
			scaleZ: trueScale.z,
			rotationX: rot.x * 180.0 / Math.PI,
			rotationY: rot.y * 180.0 / Math.PI,
			rotationZ: rot.z * 180.0 / Math.PI,
		}
		_jsonDynamic.push(obj);
		obj.dynamicFields = [];

		for (f => v in element._dynamicFields) {
			obj.dynamicFields.push({field: f, value: v});
		}
	}

	function addDTS(datablock:String, type:String, mat:Matrix, _jsonDynamic:Array<Dynamic>, name:String, actualScale:Vector):Dynamic {
		var dbData = TorqueConfig.getDataBlock(datablock);
		var dtsPath = StringTools.replace(StringTools.replace(dbData.shapefile.toLowerCase(), "marble/", ""), "platinum/", "");

		var rot = mat.getEulerAngles();

		var obj:Dynamic = {
			type: type,
			name: name,
			path: dtsPath,
			skin: dbData.skin == "" ? null : dbData.skin,
			x: mat.tx,
			y: mat.ty,
			z: mat.tz,
			scaleX: actualScale.x,
			scaleY: actualScale.y,
			scaleZ: actualScale.z,
			rotationX: rot.x * 180.0 / Math.PI,
			rotationY: rot.y * 180.0 / Math.PI,
			rotationZ: rot.z * 180.0 / Math.PI,
		}
		_jsonDynamic.push(obj);
		return obj;
	}

	function addSun(sunElement:MissionElementSun, _jsonDynamic:Array<Dynamic>) {
		var directionalColor = MisParser.parseVector4(sunElement.color);
		var ambientColor = MisParser.parseVector4(sunElement.ambient);
		var sunDirection = MisParser.parseVector3(sunElement.direction);
		sunDirection.x = -sunDirection.x;

		var obj:Dynamic = {
			type: "sun",
			name: sunElement._name != null ? sunElement._name : "",
			directionX: sunDirection.x,
			directionY: sunDirection.y,
			directionZ: sunDirection.z,
			ambient: ambientColor.toColor(),
			diffuse: directionalColor.toColor(),
			dynamicFields: [],
		};

		for (f => v in sunElement._dynamicFields) {
			obj.dynamicFields.push({field: f, value: v});
		}

		_jsonDynamic.push(obj);
	}

	function addSky(element:MissionElementSky, _jsonDynamic:Array<Dynamic>) {
		var fogColor = MisParser.parseVector4(element.fogcolor);
		var skySolidColor = MisParser.parseVector4(element.skysolidcolor);

		var obj:Dynamic = {
			type: "sky",
			name: element._name != null ? element._name : "",
			materialList: getProperFilepath(element.materiallist),
			skySolidColor: skySolidColor.toColor(),
			fogColor: fogColor.toColor(),
			useSkyTextures: element.useskytextures != "0",
			dynamicFields: [],
		};

		_jsonDynamic.push(obj);

		for (f => v in element._dynamicFields) {
			obj.dynamicFields.push({field: f, value: v});
		}
	}

	function addScriptObject(scriptObject:MissionElementScriptObject, _jsonDynamic:Array<Dynamic>) {
		var obj:Dynamic = {
			type: "scriptobject",
			name: scriptObject._name != null ? scriptObject._name : "",
			dynamicFields: [],
		};

		for (f => v in scriptObject._dynamicFields) {
			obj.dynamicFields.push({field: f, value: v});
		}

		_jsonDynamic.push(obj);
	}

	function getProperFilepath(rawElementPath:String) {
		var fname = rawElementPath.substring(rawElementPath.lastIndexOf('/') + 1);
		rawElementPath = rawElementPath.toLowerCase();
		var path = StringTools.replace(rawElementPath.substring(rawElementPath.indexOf('data/')), "\"", "");
		if (StringTools.contains(path, 'interiors_mbg/'))
			path = StringTools.replace(path, 'interiors_mbg/', 'interiors/');
		var dirpath = path.substring(0, path.lastIndexOf('/') + 1);
		if (hxd.res.Loader.currentInstance.fs.exists(path))
			return path;
		if (hxd.res.Loader.currentInstance.fs.exists(dirpath + fname))
			return dirpath + fname;
		return "";
	}
}
