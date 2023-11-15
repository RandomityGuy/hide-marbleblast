package hrt.prefab.l3d;

import h3d.Matrix;
import hrt.mis.MissionElement.MissionElementPathedInterior;
import hrt.mis.MissionElement.MissionElementPath;
import hrt.mis.MissionElement.MissionElementSimGroup;
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
import hrt.mis.*;

class Mis extends Prefab {
	var path:String;

	static var dataBlockToPath:Map<String, String> = [
		"waypointmarker" => "data/shapes/markers/octahedron.dts",
		"spawnspheremarker" => "data/shapes/markers/octahedron.dts",
		"defaultmarble" => "data/shapes/balls/ball-superball.dts",
		"gemitem" => "data/shapes/items/gem.dts",
		"gemitemblue" => "data/shapes/items/gem.dts",
		"gemitemred" => "data/shapes/items/gem.dts",
		"gemitemyellow" => "data/shapes/items/gem.dts",
		"gemitempurple" => "data/shapes/items/gem.dts",
		"gemitemgreen" => "data/shapes/items/gem.dts",
		"gemitemturquoise" => "data/shapes/items/gem.dts",
		"gemitemorange" => "data/shapes/items/gem.dts",
		"gemitemblack" => "data/shapes/items/gem.dts",
		"superjumpitem" => "data/shapes/items/superjump.dts",
		"superbounceitem" => "data/shapes/items/superbounce.dts",
		"superbounceimage" => "data/shapes/images/glow_bounce.dts",
		"superspeeditem" => "data/shapes/items/superspeed.dts",
		"shockabsorberitem" => "data/shapes/items/shockabsorber.dts",
		"shockabsorberimage" => "data/shapes/images/glow_bounce.dts",
		"helicopteritem" => "data/shapes/images/helicopter.dts",
		"helicopterimage" => "data/shapes/images/helicopter.dts",
		"timetravelitem" => "data/shapes/items/timetravel.dts",
		"antigravityitem" => "data/shapes/items/antigravity.dts",
		"pushbutton" => "data/shapes/buttons/pushButton.dts",
		"trapdoor" => "data/shapes/hazards/trapdoor.dts",
		"ductfan" => "data/shapes/hazards/ductfan.dts",
		"smallductfan" => "data/shapes/hazards/ductfan.dts",
		"oilslick" => "data/shapes/hazards/oilslick.dts",
		"tornado" => "data/shapes/hazards/tornado.dts",
		"landmine" => "data/shapes/hazards/landmine.dts",
		"startpad" => "data/shapes/pads/startarea.dts",
		"endpad" => "data/shapes/pads/endarea.dts",
		"trianglebumper" => "data/shapes/bumpers/pball_tri.dts",
		"roundbumper" => "data/shapes/bumpers/pball_round.dts",
		"signplain" => "data/shapes/signs/plainsign.dts",
		"signplainup" => "data/shapes/signs/plainsign.dts",
		"signplaindown" => "data/shapes/signs/plainsign.dts",
		"signplainleft" => "data/shapes/signs/plainsign.dts",
		"signplainright" => "data/shapes/signs/plainsign.dts",
		"signcaution" => "data/shapes/signs/cautionsign.dts",
		"signcautioncaution" => "data/shapes/signs/cautionsign.dts",
		"signcautiondanger" => "data/shapes/signs/cautionsign.dts",
		"signfinish" => "data/shapes/signs/finishlinesign.dts"
	];

	public function setColor(ctx:Context, color:Int) {
		// #if editor
		// if (ctx.local3d == null)
		// 	return;
		// var mesh = Std.downcast(ctx.local3d, h3d.scene.Mesh);
		// if (mesh != null) {
		// 	setDebugColor(color, mesh.material);
		// }
		// #end
	}

	public override function loadFromPath(p:String) {
		path = p;
		return true;
	}

	override function makeInstance(ctx:Context):Context {
		var parser = new MisParser(hxd.res.Loader.currentInstance.fs.get(path).getText());
		var misfile = parser.parse();

		addSimGroup(misfile.root, ctx);

		return super.makeInstance(ctx);
	}

	function addSimGroup(sg:MissionElementSimGroup, ctx:Context) {
		for (element in sg.elements) {
			switch (element._type) {
				case MissionElementType.SimGroup:
					this.addSimGroup(cast element, ctx);
				case MissionElementType.InteriorInstance:
					this.addInteriorFromMis(cast element, ctx);
				case MissionElementType.StaticShape:
					this.addStaticShape(cast element, ctx);
				case MissionElementType.Item:
					this.addItem(cast element, ctx);
				case MissionElementType.Trigger:
					this.addTrigger(cast element, ctx);
				case MissionElementType.TSStatic:
					this.addTSStatic(cast element, ctx);
				default:
			}
		}
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
		if (StringTools.contains(path, 'interiors_mbg/'))
			path = StringTools.replace(path, 'interiors_mbg/', 'interiors/');
		if (!StringTools.endsWith(path, ".dif"))
			path += ".dif";
		if (hxd.res.Loader.currentInstance.fs.exists(path))
			return path;
		return "";
	}

	function addInteriorFromMis(element:MissionElementInteriorInstance, ctx:Context) {
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
		// var hasCollision = interiorScale.x != = 0 && interiorScale.y != = 0 && interiorScale.z != = 0; // Don't want to add buggy geometry

		// Fix zero-volume interiors so they receive correct lighting
		if (interiorScale.x == 0)
			interiorScale.x = 0.0001;
		if (interiorScale.y == 0)
			interiorScale.y = 0.0001;
		if (interiorScale.z == 0)
			interiorScale.z = 0.0001;

		var mat = Matrix.S(interiorScale.x, interiorScale.y, interiorScale.z);
		var tmp = new Matrix();
		interiorRotation.toMatrix(tmp);
		mat.multiply3x4(mat, tmp);
		var tmat = Matrix.T(interiorPosition.x, interiorPosition.y, interiorPosition.z);
		mat.multiply(mat, tmat);

		var ref = new hrt.prefab.Reference(parent);
		ref.setTransform(mat);
		ref.source = difPath;
		ref.name = new haxe.io.Path(difPath).file;
		ref.makeInstance(ctx);
		// itr.loadFromPath(difPath);
	}

	function addStaticShape(element:MissionElementStaticShape, ctx:Context) {
		var dataBlockLowerCase = element.datablock.toLowerCase();

		if (!dataBlockToPath.exists(dataBlockLowerCase))
			return;

		var shapePosition = MisParser.parseVector3(element.position);
		shapePosition.x = -shapePosition.x;
		var shapeRotation = MisParser.parseRotation(element.rotation);
		shapeRotation.x = -shapeRotation.x;
		shapeRotation.w = -shapeRotation.w;
		var shapeScale = MisParser.parseVector3(element.scale);

		// Apparently we still do collide with zero-volume shapes
		if (shapeScale.x == 0)
			shapeScale.x = 0.0001;
		if (shapeScale.y == 0)
			shapeScale.y = 0.0001;
		if (shapeScale.z == 0)
			shapeScale.z = 0.0001;

		var mat = Matrix.S(shapeScale.x, shapeScale.y, shapeScale.z);
		var tmp = new Matrix();
		shapeRotation.toMatrix(tmp);
		mat.multiply3x4(mat, tmp);
		var tmat = Matrix.T(shapePosition.x, shapePosition.y, shapePosition.z);
		mat.multiply(mat, tmat);

		addDTS(dataBlockLowerCase, "StaticShape", mat, ctx);
	}

	function addItem(element:MissionElementItem, ctx:Context) {
		var dataBlockLowerCase = element.datablock.toLowerCase();

		if (!dataBlockToPath.exists(dataBlockLowerCase))
			return;

		var shapePosition = MisParser.parseVector3(element.position);
		shapePosition.x = -shapePosition.x;
		var shapeRotation = MisParser.parseRotation(element.rotation);
		shapeRotation.x = -shapeRotation.x;
		shapeRotation.w = -shapeRotation.w;
		var shapeScale = MisParser.parseVector3(element.scale);

		// Apparently we still do collide with zero-volume shapes
		if (shapeScale.x == 0)
			shapeScale.x = 0.0001;
		if (shapeScale.y == 0)
			shapeScale.y = 0.0001;
		if (shapeScale.z == 0)
			shapeScale.z = 0.0001;

		var mat = Matrix.S(shapeScale.x, shapeScale.y, shapeScale.z);
		var tmp = new Matrix();
		shapeRotation.toMatrix(tmp);
		mat.multiply3x4(mat, tmp);
		var tmat = Matrix.T(shapePosition.x, shapePosition.y, shapePosition.z);
		mat.multiply(mat, tmat);

		addDTS(dataBlockLowerCase, "Item", mat, ctx);
	}

	function addTrigger(sg:MissionElementTrigger, ctx:Context) {}

	function addTSStatic(sg:MissionElementTSStatic, ctx:Context) {}

	function addDTS(datablock:String, type:String, transformMat:Matrix, ctx:Context) {
		var dtsPath = dataBlockToPath.get(datablock);

		var ref = new hrt.prefab.Reference(parent);
		ref.setTransform(transformMat);
		ref.source = dtsPath;
		ref.name = new haxe.io.Path(dtsPath).file;
		ref.makeInstance(ctx);
	}

	#if editor
	static public function setDebugColor(color:Int, mat:h3d.mat.Material) {
		// mat.color.setColor(color);
		// var opaque = (color >>> 24) == 0xff;
		// mat.shadows = false;

		// if (opaque) {
		// 	var alpha = mat.getPass("debuggeom_alpha");
		// 	if (alpha != null)
		// 		mat.removePass(alpha);
		// 	mat.mainPass.setPassName("default");
		// 	mat.mainPass.setBlendMode(None);
		// 	mat.mainPass.depthWrite = true;
		// 	mat.mainPass.culling = None;
		// } else {
		// 	mat.mainPass.setPassName("debuggeom");
		// 	mat.mainPass.setBlendMode(Alpha);
		// 	mat.mainPass.depthWrite = true;
		// 	mat.mainPass.culling = Front;
		// 	var alpha = mat.allocPass("debuggeom_alpha");
		// 	alpha.setBlendMode(Alpha);
		// 	alpha.culling = Back;
		// 	alpha.depthWrite = false;
		// }
	}

	override function getHideProps():HideProps {
		return {icon: "square", name: "mis"};
	}
	#end

	static var _ = Library.register("mission", Mis, "mis");
}
