package hrt.mis;

class MisExporter {
	var data:Dynamic;

	var originalFileData:String;
	var isMcs = false;

	public function new(data:Dynamic, originalFileData:String, isMcs:Bool) {
		this.data = data;
		this.originalFileData = originalFileData;
		this.isMcs = isMcs;
	}

	public function convert() {
		var converter = new MisConverter(data);
		var misData = converter.convert();
		var w = new MisWriter();

		if (isMcs) {
			throw new haxe.Exception("MCS exporting is not yet implemented.");
		} else {
			var prelude = originalFileData.substring(0, originalFileData.indexOf("//--- OBJECT WRITE BEGIN ---"));
			var epilogue = originalFileData.substring(originalFileData.indexOf("//--- OBJECT WRITE END ---") + 26);
			w.writePrelude();
			misData.write(w);
			w.writeEpilogue();

			var contents = w.write();

			var fileData = prelude + contents + epilogue;
			return fileData;
		}
	}
}
