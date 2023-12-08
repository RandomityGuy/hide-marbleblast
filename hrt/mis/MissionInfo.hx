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
	@:missionInfoProperty("Game", game = ["PQ"])
	var game:String;
	@:missionInfoProperty("Game Mode", game = ["PQ"])
	var gameMode:String = "";
	@:missionInfoProperty(serialize)
	var level:Int = 1000;
	@:missionInfoProperty("Music", game = ["PQ"])
	var music:String = "";
	@:missionInfoProperty("Start Help Text", textarea)
	var startHelpText:String = "Change this";
	@:missionInfoProperty("Persist Start Help Text Time", dependency = "startHelpText", dependencyval = "", inverseDependency = true, game = ["PQ"])
	var persistStartHelpTextTime:Int = 0;
	@:missionInfoProperty(serialize)
	var type:String = "Custom";

	// Targets
	@:missionInfoProperty("Targets", separator = true)
	var separator:Int;
	@:missionInfoProperty("Qualify/Par Time")
	var time:Int;
	@:missionInfoProperty("Time Limit Warning", dependency = "time", dependencyval = 0, inverseDependency = true, game = ["PQ"])
	var alarmStartTime:Int;
	@:missionInfoProperty("Platinum Time", game = ["PQ"])
	var platinumTime:Int;
	@:missionInfoProperty("Gold Time", game = ["MBG"])
	var goldTime:Int;
	@:missionInfoProperty("Ultimate Time", game = ["PQ"])
	var ultimateTime:Int;
	@:missionInfoProperty("Awesome Time", game = ["PQ"])
	var awesometime:Int;
	@:missionInfoProperty("Hint", textarea, game = ["PQ"])
	var generalHint:String = "Hint goes here";
	@:missionInfoProperty("Hint for Ultimate Time/Score", textarea, game = ["PQ"])
	var ultimateHint:String = "";
	@:missionInfoProperty("Hint for Awesome Time/Score", textarea, game = ["PQ"])
	var awesomeHint:String = "";
	@:missionInfoProperty("Hint for Easter/Nest Egg", textarea, game = ["PQ"])
	var eggHint:String = "";

	// Gem Hunt
	@:missionInfoProperty("Gem Hunt", contains = true, dependency = "gameMode", dependencyval = "hunt", separator = true, game = ["PQ"])
	var separator2:Int;
	@:missionInfoProperty("Gem Madness", contains = true, dependency = "gameMode", dependencyval = "GemMadness", separator = true, game = ["PQ"])
	var separator12:Int;
	@:missionInfoProperty("Par score", contains = true, dependency = "gameMode", dependencyval = "hunt" | "GemMadness", game = ["PQ"]) // Also in Madness
	var score:Int;
	@:missionInfoProperty("Platinum score", contains = true, dependency = "gameMode", dependencyval = "hunt" | "GemMadness", game = ["PQ"]) // Also in Madness
	var platinumScore:Int;
	@:missionInfoProperty("Ultimate score", contains = true, dependency = "gameMode", dependencyval = "hunt" | "GemMadness", game = ["PQ"]) // Also in Madness
	var ultimateScore:Int;
	@:missionInfoProperty("Awesome score", contains = true, dependency = "gameMode", dependencyval = "hunt" | "GemMadness", game = ["PQ"]) // Also in Madness
	var awesomeScore:Int;
	@:missionInfoProperty("Gem hunt radius", contains = true, dependency = "gameMode", dependencyval = "hunt", game = ["PQ"])
	var radiusFromGem:Int;
	@:missionInfoProperty("Max gems per spawn", contains = true, dependency = "gameMode", dependencyval = "hunt", game = ["PQ"])
	var maxGemsPerSpawn:Int;
	@:missionInfoProperty("Gem Groups", contains = true, dependency = "gameMode", dependencyval = "hunt", game = ["PQ"])
	var gemGroups:Int;
	@:missionInfoProperty("Min next spawn distance", contains = true, dependency = "gameMode", dependencyval = "hunt", game = ["PQ"])
	var spawnBlock:Int;
	@:missionInfoProperty("Red spawn chance", contains = true, dependency = "gameMode", dependencyval = "hunt", game = ["PQ"])
	var redSpawnChance:Float;
	@:missionInfoProperty("Yellow spawn chance", contains = true, dependency = "gameMode", dependencyval = "hunt", game = ["PQ"])
	var yellowSpawnChance:Float;
	@:missionInfoProperty("Blue spawn chance", contains = true, dependency = "gameMode", dependencyval = "hunt", game = ["PQ"])
	var blueSpawnChance:Float;
	@:missionInfoProperty("Platinum spawn chance", contains = true, dependency = "gameMode", dependencyval = "hunt", game = ["PQ"])
	var platinumSpawnChance:Float;

	// Quota
	@:missionInfoProperty("Gem Quota", contains = true, dependency = "gameMode", dependencyval = "quota", separator = true, game = ["PQ"])
	var separator3:Int;
	@:missionInfoProperty("Minimum gems", contains = true, dependency = "gameMode", dependencyval = "quota", game = ["PQ"])
	var gemQuota:Int;

	// 2D
	@:missionInfoProperty("2D", contains = true, dependency = "gameMode", dependencyval = "2D", separator = true, game = ["PQ"])
	var separator4:Int;

	@:missionInfoProperty("Camera plane", contains = true, dependency = "gameMode", dependencyval = "2D", game = ["PQ"])
	public var cameraPlane:String = "xy,yz or camera angle";
	@:missionInfoProperty("Invert Plane?", contains = true, dependency = "gameMode", dependencyval = "2D", game = ["PQ"])
	public var invertCameraPlane:Bool;

	// Consistency
	@:missionInfoProperty("Consistency", contains = true, dependency = "gameMode", dependencyval = "Consistency", separator = true, game = ["PQ"])
	var separator5:Int;
	@:missionInfoProperty("Minimum speed", contains = true, dependency = "gameMode", dependencyval = "Consistency", game = ["PQ"])
	var minimumSpeed:Int;
	@:missionInfoProperty("Grace period", contains = true, dependency = "gameMode", dependencyval = "Consistency", game = ["PQ"])
	var gracePeriod:Int;
	@:missionInfoProperty("Penalty delay", contains = true, dependency = "gameMode", dependencyval = "Consistency", game = ["PQ"])
	var penaltyDelay:Int;

	// Haste
	@:missionInfoProperty("Haste", contains = true, dependency = "gameMode", dependencyval = "Haste", separator = true, game = ["PQ"])
	var separator6:Int;
	@:missionInfoProperty("Speed to qualify", contains = true, dependency = "gameMode", dependencyval = "Haste", game = ["PQ"])
	var speedToQualify:Int;

	// Laps
	@:missionInfoProperty("Laps", contains = true, dependency = "gameMode", dependencyval = "Laps", separator = true, game = ["PQ"])
	var separator7:Int;
	@:missionInfoProperty("Total Laps", contains = true, dependency = "gameMode", dependencyval = "Laps", game = ["PQ"])
	var lapsNumber:Int;
	@:missionInfoProperty("Disable Trigger Checkpoints", contains = true, dependency = "gameMode", dependencyval = "Laps", game = ["PQ"])
	var noLapsCheckpoints:Bool;

	// Radar
	@:missionInfoProperty("Radar", separator = true, game = ["PQ"])
	var separator8:Int;
	@:missionInfoProperty("Show Radar", game = ["PQ"])
	var radar:Bool = true;
	@:missionInfoProperty("Hide Radar", game = ["PQ"])
	var hideRadar:Bool = false;
	@:missionInfoProperty("Force Radar", dependency = "hideRadar", dependencyval = false, game = ["PQ"])
	var forceRadar:Bool = false;
	@:missionInfoProperty("Custom Radar Rule", dependency = "hideRadar", dependencyval = false, game = ["PQ"])
	var customRadarRule:String;
	@:missionInfoProperty("Radar Radius", dependency = "hideRadar", dependencyval = false, game = ["PQ"])
	var radarDistance:Float;
	@:missionInfoProperty("Radar Radius To Gem", dependency = "hideRadar", dependencyval = false, game = ["PQ"])
	var radarGemDistance:Float;

	// Ultra
	@:missionInfoProperty("Ultra Features", separator = true, game = ["PQ"])
	var separator9:Int;
	@:missionInfoProperty("Allow Blast?", game = ["PQ"])
	var blast:Bool;
	@:missionInfoProperty("Disable Blast?", game = ["PQ"])
	var noBlast:Bool;
	@:missionInfoProperty("Marble Radius", game = ["PQ"])
	var marbleRadius:Float;
	@:missionInfoProperty("Permanent Mega Marble", game = ["PQ"])
	var mega:Bool;
	@:missionInfoProperty("Ultra marble", game = ["PQ"])
	var useUltraMarble:Bool;

	// Camera
	@:missionInfoProperty("Camera", separator = true, game = ["PQ"])
	var separator10:Int;
	@:missionInfoProperty("Initial Camera Distance", game = ["PQ"])
	var initialCameraDistance:Float;
	@:missionInfoProperty("Preview Camera FOV", game = ["PQ"])
	var menuCameraFov:Float;
	@:missionInfoProperty("Camera FOV", game = ["PQ"])
	var cameraFov:Float;
	@:missionInfoProperty("Camera Pitch", game = ["PQ"])
	var cameraPitch:Float;

	// Advanced
	@:missionInfoProperty("Advanced", separator = true, game = ["PQ"])
	var separator11:Int;
	@:missionInfoProperty("Disable Resuming of Time Travels on Checkpoint", game = ["PQ"])
	var noAntiCheckpoint:Bool;
	@:missionInfoProperty("Global fan strength", game = ["PQ"])
	var fanStrength:Float;
	@:missionInfoProperty("Default jump impulse", game = ["PQ"])
	var jumpImpulse:Float;
	@:missionInfoProperty("Global gravity", game = ["PQ"])
	var gravity:Float;

	var so:hrt.prefab.l3d.ScriptObject;
	var exportFields:Map<String, Bool> = [];

	var gameType:String = "PQ";

	public function new() {}
}
