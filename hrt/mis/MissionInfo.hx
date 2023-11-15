package hrt.mis;

@:build(hrt.mis.MissionInfoMacro.buildMissionInfo())
@:publicFields
class MissionInfo {
	// Main
	@:missionInfoProperty("Level Name")
	var name:String = "My Custom Level";
	@:missionInfoProperty("Artist")
	var artist:String = "Your name here";
	@:missionInfoProperty("Description", textarea)
	var desc:String = "Simply Indescribable";
	@:missionInfoProperty("Game")
	var game:String;
	@:missionInfoProperty("Game Mode")
	var gameMode:String = "";
	@:missionInfoProperty(serialize)
	var level:Int = 1000;
	@:missionInfoProperty("Music")
	var music:String = "";
	@:missionInfoProperty("Start Help Text", textarea)
	var startHelpText:String = "Change this";
	@:missionInfoProperty("Persist Start Help Text Time", dependency = "startHelpText", dependencyval = "", inverseDependency = true)
	var persistStartHelpTextTime:Int = 0;
	@:missionInfoProperty(serialize)
	var type:String = "Custom";

	// Targets
	@:missionInfoProperty("Targets", separator = true)
	var separator:Int;
	@:missionInfoProperty("Qualify/Par Time")
	var time:Int;
	@:missionInfoProperty("Time Limit Warning", dependency = "time", dependencyval = 0, inverseDependency = true)
	var alarmStartTime:Int;
	@:missionInfoProperty("Platinum Time")
	var platinumTime:Int;
	@:missionInfoProperty("Ultimate Time")
	var ultimateTime:Int;
	@:missionInfoProperty("Awesome Time")
	var awesometime:Int;
	@:missionInfoProperty("Hint", textarea)
	var generalHint:String = "Hint goes here";
	@:missionInfoProperty("Hint for Ultimate Time/Score", textarea)
	var ultimateHint:String = "";
	@:missionInfoProperty("Hint for Awesome Time/Score", textarea)
	var awesomeHint:String = "";
	@:missionInfoProperty("Hint for Easter/Nest Egg", textarea)
	var eggHint:String = "";

	// Gem Hunt
	@:missionInfoProperty("Gem Hunt", contains = true, dependency = "gameMode", dependencyval = "hunt", separator = true)
	var separator2:Int;
	@:missionInfoProperty("Gem Madness", contains = true, dependency = "gameMode", dependencyval = "GemMadness", separator = true)
	var separator12:Int;
	@:missionInfoProperty("Par score", contains = true, dependency = "gameMode", dependencyval = "hunt" | "GemMadness") // Also in Madness
	var score:Int;
	@:missionInfoProperty("Platinum score", contains = true, dependency = "gameMode", dependencyval = "hunt" | "GemMadness") // Also in Madness
	var platinumScore:Int;
	@:missionInfoProperty("Ultimate score", contains = true, dependency = "gameMode", dependencyval = "hunt" | "GemMadness") // Also in Madness
	var ultimateScore:Int;
	@:missionInfoProperty("Awesome score", contains = true, dependency = "gameMode", dependencyval = "hunt" | "GemMadness") // Also in Madness
	var awesomeScore:Int;
	@:missionInfoProperty("Gem hunt radius", contains = true, dependency = "gameMode", dependencyval = "hunt")
	var radiusFromGem:Int;
	@:missionInfoProperty("Max gems per spawn", contains = true, dependency = "gameMode", dependencyval = "hunt")
	var maxGemsPerSpawn:Int;
	@:missionInfoProperty("Gem Groups", contains = true, dependency = "gameMode", dependencyval = "hunt")
	var gemGroups:Int;
	@:missionInfoProperty("Min next spawn distance", contains = true, dependency = "gameMode", dependencyval = "hunt")
	var spawnBlock:Int;
	@:missionInfoProperty("Red spawn chance", contains = true, dependency = "gameMode", dependencyval = "hunt")
	var redSpawnChance:Float;
	@:missionInfoProperty("Yellow spawn chance", contains = true, dependency = "gameMode", dependencyval = "hunt")
	var yellowSpawnChance:Float;
	@:missionInfoProperty("Blue spawn chance", contains = true, dependency = "gameMode", dependencyval = "hunt")
	var blueSpawnChance:Float;
	@:missionInfoProperty("Platinum spawn chance", contains = true, dependency = "gameMode", dependencyval = "hunt")
	var platinumSpawnChance:Float;

	// Quota
	@:missionInfoProperty("Gem Quota", contains = true, dependency = "gameMode", dependencyval = "quota", separator = true)
	var separator3:Int;
	@:missionInfoProperty("Minimum gems", contains = true, dependency = "gameMode", dependencyval = "quota")
	var gemQuota:Int;

	// 2D
	@:missionInfoProperty("2D", contains = true, dependency = "gameMode", dependencyval = "2D", separator = true)
	var separator4:Int;

	@:missionInfoProperty("Camera plane", contains = true, dependency = "gameMode", dependencyval = "2D")
	public var cameraPlane:String = "xy,yz or camera angle";
	@:missionInfoProperty("Invert Plane?", contains = true, dependency = "gameMode", dependencyval = "2D")
	public var invertCameraPlane:Bool;

	// Consistency
	@:missionInfoProperty("Consistency", contains = true, dependency = "gameMode", dependencyval = "Consistency", separator = true)
	var separator5:Int;
	@:missionInfoProperty("Minimum speed", contains = true, dependency = "gameMode", dependencyval = "Consistency")
	var minimumSpeed:Int;
	@:missionInfoProperty("Grace period", contains = true, dependency = "gameMode", dependencyval = "Consistency")
	var gracePeriod:Int;
	@:missionInfoProperty("Penalty delay", contains = true, dependency = "gameMode", dependencyval = "Consistency")
	var penaltyDelay:Int;

	// Haste
	@:missionInfoProperty("Haste", contains = true, dependency = "gameMode", dependencyval = "Haste", separator = true)
	var separator6:Int;
	@:missionInfoProperty("Speed to qualify", contains = true, dependency = "gameMode", dependencyval = "Haste")
	var speedToQualify:Int;

	// Laps
	@:missionInfoProperty("Laps", contains = true, dependency = "gameMode", dependencyval = "Laps", separator = true)
	var separator7:Int;
	@:missionInfoProperty("Total Laps", contains = true, dependency = "gameMode", dependencyval = "Laps")
	var lapsNumber:Int;
	@:missionInfoProperty("Disable Trigger Checkpoints", contains = true, dependency = "gameMode", dependencyval = "Laps")
	var noLapsCheckpoints:Bool;

	// Radar
	@:missionInfoProperty("Radar", separator = true)
	var separator8:Int;
	@:missionInfoProperty("Show Radar")
	var radar:Bool = true;
	@:missionInfoProperty("Hide Radar")
	var hideRadar:Bool = false;
	@:missionInfoProperty("Force Radar", dependency = "hideRadar", dependencyval = false)
	var forceRadar:Bool = false;
	@:missionInfoProperty("Custom Radar Rule", dependency = "hideRadar", dependencyval = false)
	var customRadarRule:String;
	@:missionInfoProperty("Radar Radius", dependency = "hideRadar", dependencyval = false)
	var radarDistance:Float;
	@:missionInfoProperty("Radar Radius To Gem", dependency = "hideRadar", dependencyval = false)
	var radarGemDistance:Float;

	// Ultra
	@:missionInfoProperty("Ultra Features", separator = true)
	var separator9:Int;
	@:missionInfoProperty("Allow Blast?")
	var blast:Bool;
	@:missionInfoProperty("Disable Blast?")
	var noBlast:Bool;
	@:missionInfoProperty("Marble Radius")
	var marbleRadius:Float;
	@:missionInfoProperty("Permanent Mega Marble")
	var mega:Bool;
	@:missionInfoProperty("Ultra marble")
	var useUltraMarble:Bool;

	// Camera
	@:missionInfoProperty("Camera", separator = true)
	var separator10:Int;
	@:missionInfoProperty("Initial Camera Distance")
	var initialCameraDistance:Float;
	@:missionInfoProperty("Preview Camera FOV")
	var menuCameraFov:Float;
	@:missionInfoProperty("Camera FOV")
	var cameraFov:Float;
	@:missionInfoProperty("Camera Pitch")
	var cameraPitch:Float;

	// Advanced
	@:missionInfoProperty("Advanced", separator = true)
	var separator11:Int;
	@:missionInfoProperty("Disable Resuming of Time Travels on Checkpoint")
	var noAntiCheckpoint:Bool;
	@:missionInfoProperty("Global fan strength")
	var fanStrength:Float;
	@:missionInfoProperty("Default jump impulse")
	var jumpImpulse:Float;
	@:missionInfoProperty("Global gravity")
	var gravity:Float;

	var so:hrt.prefab.l3d.ScriptObject;
	var exportFields:Map<String, Bool> = [];

	public function new() {}
}
