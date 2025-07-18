package hrt.mis;

enum MissionElementType {
	SimGroup;
	ScriptObject;
	MissionArea;
	Sky;
	Sun;
	InteriorInstance;
	StaticShape;
	SpawnSphere;
	Item;
	Path;
	Marker;
	PathedInterior;
	Trigger;
	AudioProfile;
	MessageVector;
	TSStatic;
	ParticleEmitterNode;
}

@:publicFields
abstract class MissionElementBase {
	// Underscore prefix to avoid name clashes

	/** The general type of the element. */
	var _type:MissionElementType; /** The object name; specified in the () of the "constructor". */

	var _name:String;

	/** Is unique for every element in the mission file. */
	var _id:Int;

	var _dynamicFields:Map<String, String> = [];

	public abstract function write(mw:MisWriter):Void;

	public function writeDynFields(mw:MisWriter) {
		for (k => v in _dynamicFields) {
			if (v.toLowerCase() == "true" || v.toLowerCase() == "false") {
				mw.writeLine('${k} = ${v == "true" ? 1 : 0};');
			} else {
				var escaped = escape(v);
				mw.writeLine('${k} = "${escaped}";');
			}
		}
	}

	public static function escape(s:String) {
		// var escapeMap = [
		// 	"\t" => "\\t", "\n" => "\\n", "\r" => "\\r", "\"" => "\\\"", "'" => "\\'", "\\" => "\\\\", "\x01" => "\\c0", "\x02" => "\\c1", "\x03" => "\\c2",
		// 	"\x04" => "\\c3", "\x05" => "\\c4", "\x06" => "\\c5", "\x07" => "\\c6", "\x0B" => "\\c7", "\x0C" => "\\c8", "\x0E" => "\\c9", "\x0F" => "\\cr",
		// 	"\x10" => "\\cp", "\x11" => "\\co", "\x08" => "\\x08", "\x12" => "\\x12", "\x13" => "\\x13", "\x14" => "\\x14", "\x15" => "\\x15",
		// 	"\x16" => "\\x16", "\x17" => "\\x17", "\x18" => "\\x18", "\x19" => "\\x19", "\x1A" => "\\x1A", "\x1B" => "\\x1B", "\x1C" => "\\x1C",
		// 	"\x1D" => "\\x1D", "\x1E" => "\\x1E", "\x1F" => "\\x1F"
		// ];
		var escapeFrom = [
			"\\", "'", "\"", "\x1F", "\x1E", "\x1D", "\x1C", "\x1B", "\x1A", "\x19", "\x18", "\x17", "\x16", "\x15", "\x14", "\x13", "\x12", "\x11", "\x10",
			"\x0F", "\x0E", "\r", "\x0C", "\x0B", "\n", "\t", "\x08", "\x07", "\x06", "\x05", "\x04", "\x03", "\x02", "\x01"
		];

		var escapeTo = [
			"\\\\", "\\'", "\\\"", "\\x1F", "\\x1E", "\\x1D", "\\x1C", "\\x1B", "\\x1A", "\\x19", "\\x18", "\\x17", "\\x16", "\\x15", "\\x14", "\\x13",
			"\\x12", "\\co", "\\cp", "\\cr", "\\c9", "\\r", "\\c8", "\\c7", "\\n", "\\t", "\\x08", "\\c6", "\\c5", "\\c4", "\\c3", "\\c2", "\\c1", "\\c0"
		];
		var tagged = false;

		if (s.charCodeAt(0) == 0x02 && s.charCodeAt(1) == 0x01) {
			s = s.substr(1);
			tagged = true;
		}
		for (i in 0...escapeFrom.length) {
			s = StringTools.replace(s, escapeFrom[i], escapeTo[i]);
		}
		if (tagged) {
			s = "\x01" + s.substr(3);
		}
		return s;
	}
}

@:publicFields
class MissionElementSimGroup extends MissionElementBase {
	var elements:Array<MissionElementBase>;

	public function new() {
		_type = MissionElementType.SimGroup;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new SimGroup(${this._name != null ? this._name : ""}) {');
		mw.indent();
		for (el in elements) {
			el.write(mw);
		}
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Stores metadata about the mission. */
class MissionElementScriptObject extends MissionElementBase {
	public function new() {
		_type = MissionElementType.ScriptObject;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new ScriptObject(${this._name != null ? this._name : ""}) {');
		mw.indent();
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
class MissionElementMissionArea extends MissionElementBase {
	var area:String;
	var flightceiling:String;
	var flightceilingRange:String;
	var locked:String;

	public function new() {
		_type = MissionElementType.MissionArea;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new MissionArea(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('area = "${this.area}";');
		mw.writeLine('flightCeiling = ${this.flightceiling};');
		mw.writeLine('flightCeilingRange = ${this.flightceilingRange};');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
class MissionElementSky extends MissionElementBase {
	var useskytextures:String;
	var skysolidcolor:String;
	var fogcolor:String;
	var materiallist:String;

	public function new() {
		_type = MissionElementType.Sky;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new Sky(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('useSkyTextures = ${this.useskytextures};');
		mw.writeLine('skySolidColor = "${this.skysolidcolor}";');
		mw.writeLine('fogColor = "${this.fogcolor}";');
		mw.writeLine('materialList = "${this.materiallist}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Stores information about the lighting direction and color. */
class MissionElementSun extends MissionElementBase {
	var direction:String;
	var color:String;
	var ambient:String;

	public function new() {
		_type = MissionElementType.Sun;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new Sun(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('direction = "${this.direction}";');
		mw.writeLine('color = "${this.color}";');
		mw.writeLine('ambient = "${this.ambient}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Represents a static (non-moving) interior instance. */
class MissionElementInteriorInstance extends MissionElementBase {
	var position:String;
	var rotation:String;
	var scale:String;
	var interiorfile:String;

	public function new() {
		_type = MissionElementType.InteriorInstance;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new InteriorInstance(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('interiorFile = "${this.interiorfile}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Represents a static shape. */
class MissionElementStaticShape extends MissionElementBase {
	var position:String;
	var rotation:String;
	var scale:String;
	var datablock:String;

	public function new() {
		_type = MissionElementType.StaticShape;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new StaticShape(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('datablock = "${this.datablock}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
class MissionElementSpawnSphere extends MissionElementBase {
	var position:String;
	var rotation:String;
	var scale:String;
	var datablock:String;

	public function new() {
		_type = MissionElementType.SpawnSphere;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new SpawnSphere(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('datablock = "${this.datablock}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Represents an item. */
class MissionElementItem extends MissionElementBase {
	var position:String;
	var rotation:String;
	var scale:String;
	var datablock:String;
	var collideable:String;
	var isStatic:String;
	var rotate:String;

	public function new() {
		_type = MissionElementType.Item;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new Item(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('datablock = "${this.datablock}";');
		mw.writeLine('collideable = ${this.collideable};');
		mw.writeLine('static = ${this.isStatic};');
		mw.writeLine('rotate = ${this.rotate};');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Holds the markers used for the path of a pathed interior. */
class MissionElementPath extends MissionElementBase {
	var markers:Array<MissionElementMarker>;

	public function new() {
		_type = MissionElementType.Path;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new Path(${this._name != null ? this._name : ""}) {');
		mw.indent();
		for (m in markers) {
			m.write(mw);
		}
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** One keyframe in a pathed interior path. */
class MissionElementMarker extends MissionElementBase {
	var position:String;
	var rotation:String;
	var scale:String;
	var seqnum:String;
	var mstonext:String;

	/** Either Linear; Accelerate or Spline. */
	var smoothingtype:String;

	public function new() {
		_type = MissionElementType.Marker;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new Marker(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('seqNum = ${this.seqnum};');
		mw.writeLine('msToNext = ${this.mstonext};');
		mw.writeLine('smoothingType = "${this.smoothingtype}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Represents a moving interior. */
class MissionElementPathedInterior extends MissionElementBase {
	var position:String;
	var rotation:String;
	var scale:String;
	var datablock:String;
	var interiorresource:String;
	var interiorindex:String;
	var baseposition:String;
	var baserotation:String;
	var basescale:String;

	var initialtargetposition:String;
	var initialpathposition:String;

	public function new() {
		_type = MissionElementType.PathedInterior;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new PathedInterior(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('interiorResource = "${this.interiorresource}";');
		mw.writeLine('interiorIndex = ${this.interiorindex};');
		mw.writeLine('basePosition = "${this.baseposition}";');
		mw.writeLine('baseRotation = "${this.baserotation}";');
		mw.writeLine('baseScale = "${this.basescale}";');
		mw.writeLine('initialTargetPosition = "${this.initialtargetposition}";');
		mw.writeLine('initialPathPosition = "${this.initialpathposition}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Represents a trigger area used for out-of-bounds and help. */
class MissionElementTrigger extends MissionElementBase {
	var position:String;
	var rotation:String;
	var scale:String;
	var datablock:String;

	/** A list of 12 Strings representing 4 vectors. The first vector corresponds to the origin point of the cuboid; the other three are the side vectors. */
	var polyhedron:String;

	public function new() {
		_type = MissionElementType.Trigger;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new Trigger(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('datablock = "${this.datablock}";');
		mw.writeLine('polyhedron = "${this.polyhedron}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Represents the song choice. */
class MissionElementAudioProfile extends MissionElementBase {
	var filename:String;
	var description:String;
	var preload:String;

	public function new() {
		_type = MissionElementType.AudioProfile;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new AudioProfile(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('filename = "${this.filename}";');
		mw.writeLine('description = "${this.description}";');
		mw.writeLine('preload = ${this.preload};');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
class MissionElementMessageVector extends MissionElementBase {
	public function new() {
		_type = MissionElementType.MessageVector;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new MessageVector(${this._name != null ? this._name : ""}) {');
		mw.indent();
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Represents a static; unmoving; unanimated DTS shape. They're pretty dumb; tbh. */
class MissionElementTSStatic extends MissionElementBase {
	var position:String;
	var rotation:String;
	var scale:String;
	var shapename:String;

	public function new() {
		_type = MissionElementType.TSStatic;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new TSStatic(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('shapeName = "${this.shapename}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}

@:publicFields
/** Represents a particle emitter. Currently unused by this port (these are really niche). */
class MissionElementParticleEmitterNode extends MissionElementBase {
	var position:String;
	var rotation:String;
	var scale:String;
	var datablock:String;
	var emitter:String;
	var velocity:String;

	public function new() {
		_type = MissionElementType.ParticleEmitterNode;
		_dynamicFields = [];
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new ParticleEmitterNode(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('datablock = "${this.datablock}";');
		mw.writeLine('emitter = "${this.emitter}";');
		mw.writeLine('velocity = "${this.velocity}";');
		writeDynFields(mw);
		mw.unindent();
		mw.writeLine('};');
	}
}
