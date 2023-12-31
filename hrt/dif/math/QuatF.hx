package hrt.dif.math;

import hrt.dif.io.BytesWriter;
import hrt.dif.io.BytesReader;

@:expose
class QuatF {
	public var x:Float;
	public var y:Float;
	public var z:Float;
	public var w:Float;

	public function new() {
		this.x = 0;
		this.y = 0;
		this.z = 0;
		this.w = 0;
	}

	public static function read(io:BytesReader) {
		var ret = new QuatF();
		ret.x = io.readFloat();
		ret.y = io.readFloat();
		ret.z = io.readFloat();
		ret.w = io.readFloat();
		return ret;
	}

	public function write(io:BytesWriter) {
		io.writeFloat(this.x);
		io.writeFloat(this.y);
		io.writeFloat(this.z);
		io.writeFloat(this.w);
	}
}
