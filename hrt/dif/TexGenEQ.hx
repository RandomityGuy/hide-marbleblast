package hrt.dif;

import hrt.dif.io.BytesWriter;
import hrt.dif.io.BytesReader;
import hrt.dif.math.PlaneF;

@:expose
class TexGenEQ {
	public var planeX:PlaneF;
	public var planeY:PlaneF;

	public function new() {
		planeX = new PlaneF();
		planeY = new PlaneF();
	}

	public static function read(io:BytesReader) {
		var ret = new TexGenEQ();
		ret.planeX = PlaneF.read(io);
		ret.planeY = PlaneF.read(io);
		return ret;
	}

	public function write(io:BytesWriter) {
		this.planeX.write(io);
		this.planeY.write(io);
	}
}
