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

class McsParser {
	var text:String;
	var misParser:MisParser;
	var path:String;

	public function new(text:String, path:String) {
		this.text = text;
		this.path = path;
	}

	public function parse() {
		var indexOfMissionGroup = this.text.indexOf('new SimGroup(MissionGroup)');
		var missionEnd = this.text.indexOf('//--- MISSION END ---');
		var misData = this.text.substring(indexOfMissionGroup, missionEnd);

		misData = "//--- OBJECT WRITE BEGIN ---\n" + misData + "//--- OBJECT WRITE END ---\n";

		var minfo = getMissionInfo();
		minfo.root._name = 'MissionInfo';

		misParser = new MisParser(misData, path);
		var mdata = misParser.parse();
		mdata.root.elements.insert(0, minfo.root);
		return mdata;
	}

	function getMissionInfo() {
		var indexOfGMI = this.text.indexOf('_GetMissionInfo()');
		var indexOfMIStart = this.text.indexOf('new ScriptObject()', indexOfGMI);
		var infoEnd = this.text.indexOf('};');
		var miData = this.text.substring(indexOfMIStart, infoEnd + 2);
		var miParser = new MisParser("//--- OBJECT WRITE BEGIN ---\n" + miData + "//--- OBJECT WRITE END ---\n", path);
		var miRoot = miParser.parse();
		return miRoot;
	}
}
