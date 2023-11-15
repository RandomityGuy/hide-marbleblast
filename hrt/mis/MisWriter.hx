package hrt.mis;

class MisWriter {
	var lines:Array<String> = [];

	var indentLevel = 0;

	public function new() {}

	public function indent() {
		indentLevel++;
	}

	public function unindent() {
		indentLevel--;
	}

	public function writeLine(l:String) {
		var indent = "";
		for (i in 0...indentLevel) {
			indent += "    ";
		}
		lines.push(indent + l);
	}

	public function writePrelude() {
		writeLine("//--- OBJECT WRITE BEGIN ---");
	}

	public function writeEpilogue() {
		writeLine("//--- OBJECT WRITE END ---");
	}

	public function write() {
		return lines.join("\n");
	}
}
