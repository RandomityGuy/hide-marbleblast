package hrt.dif;

import hrt.dif.io.BytesWriter;
import hrt.dif.io.BytesReader;
import hrt.dif.math.Point3F;
import haxe.ds.StringMap;

using hrt.dif.ReaderExtensions;
using hrt.dif.WriterExtensions;

@:expose
class Trigger {
	public var name:String;
	public var datablock:String;
	public var properties:StringMap<String>;
	public var polyhedron:Polyhedron;
	public var offset:Point3F;

	public function new() {
		this.name = "";
		this.datablock = "";
		this.offset = new Point3F();
		this.properties = new StringMap<String>();
		this.polyhedron = new Polyhedron();
	}

	public static function read(io:BytesReader) {
		var ret = new Trigger();
		ret.name = io.readStr();
		ret.datablock = io.readStr();
		ret.properties = io.readDictionary();
		ret.polyhedron = Polyhedron.read(io);
		ret.offset = Point3F.read(io);
		return ret;
	}

	public function write(io:BytesWriter) {
		io.writeStr(this.name);
		io.writeStr(this.datablock);
		io.writeDictionary(this.properties);
		this.polyhedron.write(io);
		this.offset.write(io);
	}
}
