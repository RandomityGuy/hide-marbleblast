package hide.comp;

typedef GlobalsDef = haxe.DynamicAccess<{
	var globals : haxe.DynamicAccess<String>;
	var context : String;
	var contexts : Array<String>;
	var events : String;
	var evalTo : String;
	var allowGlobalsDefine : Bool;
	var cdbEnums : Array<String>;
}>;

class ScriptCache {

	var content : Map<String,Bool> = [];
	var configSign : String;
	public var signature : String;

	public function new(configSign:String) {
		this.configSign = configSign;
		var key = js.Browser.window.localStorage.getItem("script_cache_key");
		if( key == configSign ) {
			var values = js.Browser.window.localStorage.getItem("script_cache_val").split(";");
			for( v in values )
				content.set(v,true);
		}
	}

	public function get( hash : String ) {
		return content.get(hash);
	}

	public function set( hash : String, b : Bool ) {
		if( content.get(hash) == b ) return;
		content.set(hash, b);
		var all = [];
		for( key => b in content ) {
			if( b )
				all.push(key);
		}
		js.Browser.window.localStorage.setItem("script_cache_key", configSign);
		js.Browser.window.localStorage.setItem("script_cache_val", all.join(";"));
	}

}

class ScriptChecker {

	static var TYPES_SAVE = new Map();
	static var ERROR_SAVE = new Map();
	static var CONFIG_HASH = null;
	static var CHECK_CACHE : ScriptCache;
	static var TYPE_CHECK_HOOKS : Array<ScriptChecker->Void> = [];
	var ide : hide.Ide;
	var apiFiles : Array<String>;
	var checkEvents : Bool;
	public var config : hide.Config;
	public var documentName : String;
	public var constants : Map<String,Dynamic>;
	public var evalTo : String;
	public var checker(default,null) : hscript.Checker;
	var initDone = false;

	public function new( config : hide.Config, documentName : String, ?constants : Map<String,Dynamic> ) {
		this.config = config;
		this.documentName = documentName;
		this.constants = constants == null ? new Map() : constants;
		ide = hide.Ide.inst;
		apiFiles = config.get("script.api.files");
		reload();
	}

	function hashString( str : String ) {
		return haxe.crypto.Md5.encode(str);
	}

	public function reload() {
		checker = new hscript.Checker();
		checker.allowAsync = true;
		initDone = false;

		var hashes = [];
		if( apiFiles != null && apiFiles.length >= 0 ) {
			var types = TYPES_SAVE.get(apiFiles.join(";"));
			if( types == null ) {
				types = new hscript.Checker.CheckerTypes();
				for( f in apiFiles ) {
					var path = ide.getPath(f);
					var content = try sys.io.File.getContent(path) catch( e : Dynamic ) { error(""+e); continue; };
					hashes.push(path+":"+sys.FileSystem.stat(path).mtime.getTime());
					types.addXmlApi(Xml.parse(content).firstElement());
					ide.fileWatcher.register(f, reloadApi);
				}
				TYPES_SAVE.set(apiFiles.join(";"), types);
			}
			checker.types = types;
		}
		if( CONFIG_HASH == null ) {
			hashes.push(haxe.Json.stringify(config.get("script.api")));
			CONFIG_HASH = hashString(hashes.join(","));
		}
	}

	function init() {
		if( initDone ) return;
		initDone = true;

		var parts = documentName.split(".");
		var apis = [];
		while( parts.length > 0 ) {
			var path = parts.join(".");
			parts.pop();
			var config = config.get("script.api");
			if( config == null ) continue;
			var api = (config : GlobalsDef).get(path);
			if( api == null ) {
				path = ~/\[group=[^\]]+?\]/g.replace(path,"");
				api = (config : GlobalsDef).get(path);
			}
			if( api != null )
				apis.unshift(api);
		}

		var contexts = [];
		var allowGlobalsDefine = false;
		checkEvents = false;

		for( api in apis ) {
			for( f in api.globals.keys() ) {
				var tname = api.globals.get(f);
				if( tname == null ) {
					checker.removeGlobal(f);
					continue;
				}
				var isClass = tname.charCodeAt(0) == '#'.code;
				if( isClass ) tname = tname.substr(1);
				var t = checker.types.resolve(tname);
				if( t == null ) {
					var path = tname.split(".");
					var fields = [];
					while( path.length > 0 ) {
						var name = path.join(".");
						if( constants.exists(name) ) {
							var value : Dynamic = constants.get(name);
							for( f in fields )
								value = Reflect.field(value, f);
							t = typeFromValue(value);
							if( t == null ) t = TAnon([]);
						}
						fields.unshift(path.pop());
					}
				}
				if( t == null ) {
					error('Global type $tname not found in $apiFiles ($f)');
					continue;
				}
				if( isClass ) {
					switch( t ) {
					case TEnum(e,_):
						t = TAnon([for( c in e.constructors ) { name : c.name, opt : false, t : c.args == null ? t : TFun(c.args,t) }]);
					default:
						error('Cannot process class type $tname');
					}
				}
				checker.setGlobal(f, t);
			}

			if( api.context != null )
				contexts = [api.context];

			if( api.contexts != null )
				contexts = api.contexts;

			if( api.allowGlobalsDefine != null )
				allowGlobalsDefine = api.allowGlobalsDefine;

			if( api.events != null ) {
				for( f in getFields(api.events) )
					checker.setEvent(f.name, f.t);
				checkEvents = true;
			}

			if( api.evalTo != null )
				this.evalTo = api.evalTo;
		}
		for( context in contexts ) {
			var ctx = checker.types.resolve(context);
			if( ctx == null )
				error(context+" is not defined");
			else {
				switch( ctx ) {
				case TInst(c,_):
					var cc = c;
					while( true ) {
						for( f in cc.fields ) if( f.t.match(TFun(_)) ) f.isPublic = true; // allow access to private methods
						if( cc.superClass == null ) break;
						cc = switch( cc.superClass ) {
						case TInst(c,_): c;
						default: throw "assert";
						}
					}
					checker.setGlobals(c);
				default: error(context+" is not a class");
				}
			}
		}
		checker.allowUntypedMeta = true;
		checker.allowGlobalsDefine = allowGlobalsDefine;
		for( c in TYPE_CHECK_HOOKS )
			c(this);
	}

	function getFields( tpath : String ) {
		var t = checker.types.resolve(tpath);
		if( t == null )
			error("Missing type "+tpath);
		var fl = checker.getFields(t);
		if( fl == null )
			error(tpath+" is not a class");
		return fl;
	}

	function error( msg : String ) {
		if( !ERROR_SAVE.exists(msg) ) {
			ERROR_SAVE.set(msg,true);
			ide.error(msg);
		}
	}

	function typeFromValue( value : Dynamic ) : hscript.Checker.TType {
		switch( std.Type.typeof(value) ) {
		case TNull:
			return null;
		case TInt:
			return TInt;
		case TFloat:
			return TFloat;
		case TBool:
			return TBool;
		case TObject:
			var fields = [];
			for( f in Reflect.fields(value) ) {
				var t = typeFromValue(Reflect.field(value,f));
				if( t == null ) continue;
				fields.push({ name : f, t : t, opt : false });
			}
			return TAnon(fields);
		case TClass(c):
			return checker.types.resolve(Type.getClassName(c),[]);
		case TEnum(e):
			return checker.types.resolve(Type.getEnumName(e),[]);
		case TFunction, TUnknown:
		}
		return null;
	}

	public function makeParser() {
		var parser = new hscript.Parser();
		parser.allowMetadata = true;
		parser.allowTypes = true;
		parser.allowJSON = true;
		return parser;
	}

	public function getCompletion( script : String ) {
		var parser = makeParser();
		parser.resumeErrors = true;
		var expr = parser.parseString(script,""); // should not error
		try {
			init();
			var et = checker.check(expr,null,true);
			return null;
		} catch( e : hscript.Checker.Completion ) {
			// ignore
			return e.t;
		}
	}

	public function getCache( code : String ) {
		if( CHECK_CACHE == null )
			CHECK_CACHE = new ScriptCache(CONFIG_HASH);
		CHECK_CACHE.signature = hashString(code+":"+documentName+":"+haxe.Json.stringify(constants));
		return CHECK_CACHE;
	}

	public function check( script : String, checkTypes = true ) {
		var parser = makeParser();
		try {
			var expr = parser.parseString(script, "");

			if( checkEvents ) {
				function checkRec(e:hscript.Expr) {
					switch( e.e ) {
					case EFunction(_,_,name,_):
						if( name != null && StringTools.startsWith(name,"on") && name.charCodeAt(2) > 'A'.code && name.charCodeAt(2) < 'Z'.code && @:privateAccess !checker.events.exists(name) )
							@:privateAccess checker.error('Unknown event $name', e);
					default:
						hscript.Tools.iter(e, checkRec);
					}
				}
				checkRec(expr);
			}

			if( checkTypes ) {
				init();
				var et = checker.check(expr);
				if( evalTo != null ) {
					var t = checker.types.resolve(evalTo);
					if( t == null ) {
						error('EvalTo type $evalTo not found');
						return null;
					}
					checker.unify(et, t, expr);
				}
			}
			return null;
		} catch( e : hscript.Expr.Error ) {
			return e;
		}
	}

	public static function reloadApi() {
		TYPES_SAVE = new Map();
		CONFIG_HASH = null;
		CHECK_CACHE = null;
	}

}

class ScriptEditor extends CodeEditor {

	static var INIT_DONE = false;
	var checker : ScriptChecker;
	var checkTypes : Bool;

	public function new( script : String, ?checker : ScriptChecker, ?parent : Element, ?root : Element, ?lang ) {
		if( !INIT_DONE ) {
			INIT_DONE = true;
			(monaco.Languages : Dynamic).typescript.javascriptDefaults.setCompilerOptions({ noLib: true, allowNonTsExtensions: true }); // disable js stdlib completion
			monaco.Languages.registerCompletionItemProvider("javascript", {
				triggerCharacters : ["."],
				provideCompletionItems : function(model,position,_,_) {
					var comp : ScriptEditor = (model : Dynamic).__comp__;
			        var code = model.getValueInRange({startLineNumber: 1, startColumn: 1, endLineNumber: position.lineNumber, endColumn: position.column});
					return comp.getCompletion(code.length);
				}
			});
		}
		super(script, lang, parent,root);
		if( checker == null ) {
			checker = new ScriptChecker(new hide.Config(),"");
			checkTypes = false;
		} else {
			var files = @:privateAccess checker.apiFiles;
			if( files != null ) {
				for( f in files )
					ide.fileWatcher.register(f, function() {
						ScriptChecker.reloadApi();
						haxe.Timer.delay(function() { try checker.reload() catch( e : Dynamic ) {}; doCheckScript(); }, 100);
					}, root);
			}
		}
		this.checker = checker;
		onChanged = doCheckScript;
		haxe.Timer.delay(function() doCheckScript(), 0);
	}

	function getCompletion( position : Int ) : Array<monaco.Languages.CompletionItem> {
		var script = code.substr(0,position);
		var vars = checker.checker.getGlobals();
		if( script.charCodeAt(script.length-1) == ".".code ) {
			vars = [];
			var t = checker.getCompletion(script);
			if( t != null ) {
				var fields = checker.checker.getFields(t);
				for( f in fields )
					vars.set(f.name, f.t);
			}
		}
		var checker = checker.checker;
		return [for( k in vars.keys() ) {
			var t = vars.get(k);
			if( StringTools.startsWith(k,"a_") ) {
				var t2 = checker.unasync(t);
				if( t2 != null ) {
					t = t2;
					k = k.substr(2);
				}
			}
			var isFun = checker.follow(t).match(TFun(_));
			if( isFun ) {
				{
					kind : Method,
					label : k,
					detail : hscript.Checker.typeStr(t),
					commitCharacters: ["("],
				}
			} else {
				{
					kind : Field,
					label : k,
					detail : hscript.Checker.typeStr(t),
				}
			}
		}];
	}

	public function doCheckScript() {
		var script = code;
		var error = checker.check(script, checkTypes);
		if( error == null )
			clearError();
		else
			setError(hscript.Printer.errorToString(error), error.line, error.pmin, error.pmax);
	}

	public static function register( cl : Class<Dynamic> ) : Bool {
		@:privateAccess ScriptChecker.TYPE_CHECK_HOOKS.push(function(checker) {
			Type.createInstance(cl,[checker]);
		});
		return true;
	}

}
