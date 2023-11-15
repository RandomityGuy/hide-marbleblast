package hrt.mis;

enum MissionElementType {
	SimGroup;
	ScriptObject;
	MissionArea;
	Sky;
	Sun;
	InteriorInstance;
	StaticShape;
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
			mw.writeLine('${k} = "${v}";');
		}
	}
}

@:publicFields
class MissionElementSimGroup extends MissionElementBase {
	var elements:Array<MissionElementBase>;

	public function new() {
		_type = MissionElementType.SimGroup;
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
	}

	public function write(mw:MisWriter) {
		mw.writeLine('new PathedInterior(${this._name != null ? this._name : ""}) {');
		mw.indent();
		mw.writeLine('position = "${this.position}";');
		mw.writeLine('rotation = "${this.rotation}";');
		mw.writeLine('scale = "${this.scale}";');
		mw.writeLine('datablock = "${this.datablock}";');
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
