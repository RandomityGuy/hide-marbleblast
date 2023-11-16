package hrt.prefab.l3d;
using Lambda;

class Instance extends Object3D {

	public function new(?parent) {
		super(parent);
		type = "instance";
		props = {};
	}

	#if editor
	override function makeInstance(ctx:Context):Context {
		var ctx = super.makeInstance(ctx);
		return ctx;
	}

	override function makeInteractive(ctx:Context):hxd.SceneEvents.Interactive {
		var int = super.makeInteractive(ctx);
		if( int == null ) {
			// no meshes ? do we have an icon instead...
			var follow = Std.downcast(ctx.local2d, h2d.ObjectFollower);
			if( follow != null ) {
				var bmp = Std.downcast(follow.getChildAt(0), h2d.Bitmap);
				if( bmp != null ) {
					var i = new h2d.Interactive(bmp.tile.width, bmp.tile.height, bmp);
					i.x = bmp.tile.dx;
					i.y = bmp.tile.dy;
					int = i;
				}
			}
		}
		return int;
	}

	override function removeInstance(ctx:Context):Bool {
		if(!super.removeInstance(ctx))
			return false;
		if(ctx.local2d != null ) {
			var p = parent;
			var pctx = null;
			while( p != null ) {
				pctx = ctx.shared.getContexts(p)[0];
				if( pctx != null ) break;
				p = p.parent;
			}
			if( ctx.local2d != (pctx == null ? ctx.shared.root2d : pctx.local2d) ) ctx.local2d.remove();
		}
		return true;
	}

	// ---- statics

	public static function getRefSheet(p: Prefab) {
		return null;
	}

	override function getHideProps() : HideProps {
		return { icon : "circle", name : "Instance" };
	}

	static function getDefaultTile() : h2d.Tile {
		var engine = h3d.Engine.getCurrent();
		var t = @:privateAccess engine.resCache.get(Instance);
		if( t == null ) {
			t = hxd.res.Any.fromBytes("",sys.io.File.getBytes(hide.Ide.inst.getPath("${HIDE}/res/icons/unknown.png"))).toTile();
			@:privateAccess engine.resCache.set(Instance, t);
		}
		return t.clone();
	}
	#end

	static var _ = Library.register("instance", Instance);
}