package hide.comp;

import hrt.prefab.l3d.SimGroup;
import hrt.prefab.l3d.ScriptObject;
import hrt.prefab.l3d.InteriorPath;
import hrt.prefab.l3d.TorqueObject;
import hrt.prefab.Reference;
import h3d.scene.Mesh;
import h3d.col.FPoint;
import h3d.col.Ray;
import h3d.col.PolygonBuffer;
import h3d.prim.HMDModel;
import h3d.col.Collider.OptimizedCollider;
import h3d.Vector;
import hxd.Key as K;
import hxd.Math as M;
import h3d.shader.pbr.Slides.DebugMode;
import h3d.scene.pbr.Renderer.DisplayMode;
import hrt.prefab.Prefab as PrefabElement;
import hrt.prefab.Object2D;
import hrt.prefab.Object3D;
import h3d.scene.Object;
import hide.view.CameraController;

using hide.tools.Extensions.ArrayExtensions;

enum SelectMode {
	/**
		Update tree, add undo command
	**/
	Default;

	/**
		Update tree only
	**/
	NoHistory;

	/**
		Add undo but don't update tree
	**/
	NoTree;

	/**
		Don't refresh tree and don't undo command
	**/
	Nothing;
}

@:access(hide.comp.SceneEditor)
class SceneEditorContext extends hide.prefab.EditContext {
	public var editor(default, null):SceneEditor;
	public var elements:Array<PrefabElement>;
	public var rootObjects(default, null):Array<Object>;
	public var rootObjects2D(default, null):Array<h2d.Object>;
	public var rootElements(default, null):Array<PrefabElement>;

	public function new(ctx, elts, editor) {
		super(ctx);
		this.editor = editor;
		this.updates = editor.updates;
		this.elements = elts;
		rootObjects = [];
		rootObjects2D = [];
		rootElements = [];
		cleanups = [];
		for (elt in elements) {
			// var obj3d = elt.to(Object3D);
			// if(obj3d == null) continue;
			if (!SceneEditor.hasParent(elt, elements)) {
				rootElements.push(elt);
				var ctx = getContext(elt);
				if (ctx != null) {
					var pobj = elt.parent == editor.sceneData ? ctx.shared.root3d : getContextRec(elt.parent).local3d;
					var pobj2d = elt.parent == editor.sceneData ? ctx.shared.root2d : getContextRec(elt.parent).local2d;
					if (ctx.local3d != pobj && ctx.local3d != null)
						rootObjects.push(ctx.local3d);
					if (ctx.local2d != pobj2d && ctx.local2d != null)
						rootObjects2D.push(ctx.local2d);
				}
			}
		}
	}

	override function screenToGround(x:Float, y:Float, ?forPrefab:hrt.prefab.Prefab) {
		return editor.screenToGround(x, y, forPrefab);
	}

	override function positionToGroundZ(x:Float, y:Float, ?forPrefab:hrt.prefab.Prefab):Float {
		return editor.getZ(x, y, forPrefab);
	}

	override function getCurrentProps(p:hrt.prefab.Prefab) {
		var cur = editor.curEdit;
		return cur != null && cur.elements[0] == p ? editor.properties.element : new Element();
	}

	function getContextRec(p:hrt.prefab.Prefab) {
		if (p == null)
			return editor.context;
		var c = editor.context.shared.contexts.get(p);
		if (c == null)
			return getContextRec(p.parent);
		return c;
	}

	override function rebuildProperties() {
		editor.scene.setCurrent();
		editor.selectElements(elements, NoHistory);
	}

	override function rebuildPrefab(p:hrt.prefab.Prefab, ?sceneOnly:Bool) {
		if (sceneOnly)
			editor.refreshScene();
		else
			editor.refresh();
	}

	public function cleanup() {
		for (c in cleanups.copy())
			c();
		cleanups = [];
	}

	override function onChange(p:PrefabElement, pname:String) {
		super.onChange(p, pname);
		editor.onPrefabChange(p, pname);
	}
}

enum RefreshMode {
	Partial;
	Full;
}

typedef CustomPivot = {elt:PrefabElement, mesh:Mesh, locPos:Vector};

class ViewModePopup extends hide.comp.Popup {
	static var viewFilter:Array<{name:String, inf:{display:DisplayMode, debug:DebugMode}}> = [
		{
			name: "LIT",
			inf: {
				display: Pbr,
				debug: Normal
			},
		},
		{
			name: "Full",
			inf: {
				display: Debug,
				debug: Full
			}
		},
		{
			name: "Albedo",
			inf: {
				display: Debug,
				debug: Albedo
			}
		},
		{
			name: "Normal",
			inf: {
				display: Debug,
				debug: Normal
			}
		},
		{
			name: "Roughness",
			inf: {
				display: Debug,
				debug: Roughness
			}
		},
		{
			name: "Metalness",
			inf: {
				display: Debug,
				debug: Metalness
			}
		},
		{
			name: "Emissive",
			inf: {
				display: Debug,
				debug: Emmissive
			}
		},
		{
			name: "AO",
			inf: {
				display: Debug,
				debug: AO
			}
		},
		{
			name: "Shadows",
			inf: {
				display: Debug,
				debug: Shadow
			}
		},
		{
			name: "Performance",
			inf: {
				display: Performance,
				debug: Normal
			}
		}
	];

	var renderer:h3d.scene.pbr.Renderer;

	public function new(?parent:Element, ?root:Element, engineRenderer:h3d.scene.pbr.Renderer) {
		super(parent, root);
		this.renderer = engineRenderer;
		popup.addClass("settings-popup");
		popup.css("max-width", "300px");

		if (renderer == null)
			return;

		var form_div = new Element("<div>").addClass("form-grid").appendTo(popup);

		{
			var initDone = false;
			{
				var slides = @:privateAccess renderer.slides;
				for (v in viewFilter) {
					var typeid = v.name;
					var on = renderer.displayMode == v.inf.display
						&& (renderer.displayMode == Debug ? slides.shader.mode == v.inf.debug : true);
					var input = new Element('<input type="radio" name="filter" id="$typeid" value="$typeid"/>');
					if (on)
						input.get(0).toggleAttribute("checked", true);

					input.change((e) -> {
						var slides = @:privateAccess renderer.slides;
						if (slides == null)
							return;
						renderer.displayMode = v.inf.display;
						if (renderer.displayMode == Debug) {
							slides.shader.mode = v.inf.debug;
						}
					});

					form_div.append(input);
					form_div.append(new Element('<label for="$typeid" class="left">$typeid</label>'));
				}
			}
		}
	}
}

class SnapSettingsPopup extends Popup {
	var editor:SceneEditor;

	public function new(?parent:Element, ?root:Element, editor:SceneEditor) {
		super(parent, root);
		this.editor = editor;

		popup.append(new Element("<p>Snap Settings</p>"));
		popup.addClass("settings-popup");
		popup.css("max-width", "300px");

		var form_div = new Element("<div>").addClass("form-grid").appendTo(popup);

		var editMode:hide.view.l3d.Gizmo.EditMode = @:privateAccess editor.gizmo.editMode;

		var steps:Array<Float> = [];
		switch (editMode) {
			case Translation:
				steps = editor.view.config.get("sceneeditor.gridSnapSteps");
			case Rotation:
				steps = editor.view.config.get("sceneeditor.rotateStepCoarses");
			case Scaling:
				steps = editor.view.config.get("sceneeditor.gridSnapSteps");
		}

		for (value in steps) {
			var input = new Element('<input type="radio" name="snap" id="snap$value" value="$value"/>');

			var equals = switch (editMode) {
				case Translation:
					editor.snapMoveStep == value;
				case Rotation:
					editor.snapRotateStep == value;
				case Scaling:
					editor.snapScaleStep == value;
			}

			if (equals)
				input.get(0).toggleAttribute("checked", true);
			input.change((e) -> {
				switch (editMode) {
					case Translation:
						editor.snapMoveStep = value;
					case Rotation:
						editor.snapRotateStep = value;
					case Scaling:
						editor.snapScaleStep = value;
				}
				editor.updateGrid();
				editor.saveSnapSettings();
			});
			form_div.append(input);
			form_div.append(new Element('<label for="snap$value" class="left">$value${editMode == Rotation ? "°" : ""}</label>'));
		}

		{
			var input = new Element('<input type="checkbox" name="forceSnapGrid" id="forceSnapGrid"/>').appendTo(form_div);
			new Element('<label for="forceSnapGrid" class="left">Force On Grid</label>').appendTo(form_div);

			if (editor.snapForceOnGrid)
				input.get(0).toggleAttribute("checked", true);

			input.change((e) -> {
				editor.snapForceOnGrid = !editor.snapForceOnGrid;
				editor.saveSnapSettings();
			});
		}
	}
}

class IconVisibilityPopup extends Popup {
	var editor:SceneEditor;

	public function new(?parent:Element, ?root:Element, editor:SceneEditor) {
		super(parent, root);
		this.editor = editor;

		popup.append(new Element("<p>Icon Visibility</p>"));
		popup.addClass("settings-popup");
		popup.css("max-width", "300px");

		var form_div = new Element("<div>").addClass("form-grid").appendTo(popup);

		var editMode:hide.view.l3d.Gizmo.EditMode = @:privateAccess editor.gizmo.editMode;

		var ide = hide.Ide.inst;
		for (k => v in ide.show3DIconsCategory) {
			var input = new Element('<input type="checkbox" name="snap" id="$k" value="$k"/>');
			if (v)
				input.get(0).toggleAttribute("checked", true);
			input.change((e) -> {
				var val = !ide.show3DIconsCategory.get(k);
				ide.show3DIconsCategory.set(k, val);
				js.Browser.window.localStorage.setItem(hrt.impl.EditorTools.iconVisibilityKey(k), val ? "true" : "false");
			});
			form_div.append(input);
			form_div.append(new Element('<label for="$k" class="left">$k</label>'));
		}
	}
}

class HelpPopup extends Popup {
	var editor:SceneEditor;

	public function new(?parent:Element, ?root:Element, editor:SceneEditor) {
		super(parent, root);
		this.editor = editor;

		popup.append(new Element("<p>Shortcuts</p>"));
		popup.addClass("settings-popup");
		popup.css("max-width", "300px");

		var form_div = new Element("<div>").addClass("form-grid").appendTo(popup);
		var categories = editor.view.keys.sortDocCategories(editor.view.config);

		for (cat => shortcuts in categories) {
			if (cat == "none")
				continue;
			form_div.append(new Element('<p style="grid-column: 1 / -1">$cat</p>'));
			for (s in shortcuts) {
				form_div.append(new Element('<label>${s.name}</label><span>${s.shortcut}</span>'));
			}
		}
	}
}

class RenderPropsPopup extends Popup {
	var editor:SceneEditor;

	public function new(?parent:Element, ?root:Element, editor:SceneEditor, isSearchable = false, canChangeCurrRp = false) {
		super(parent, root, isSearchable);
		this.editor = editor;

		popup.addClass("settings-popup");
		popup.css("max-width", "300px");

		var form_div = new Element("<div>").addClass("form-grid").appendTo(popup);
		var lastRenderProps:hrt.prefab.RenderProps = null;
		var currentRenderProps = @:privateAccess editor.getAllWithRefs(@:privateAccess editor.sceneData, hrt.prefab.RenderProps);
		for (r in currentRenderProps)
			if (@:privateAccess r.isDefault) {
				lastRenderProps = r;
				break;
			}
		if (lastRenderProps == null)
			lastRenderProps = currentRenderProps[0];

		if (lastRenderProps != null && !canChangeCurrRp) {
			form_div.append(new Element('<p>A render props (${lastRenderProps.name}) is already existing in scene.</p>'));
			return;
		}

		var renderProps = hide.Ide.inst.currentConfig.get("scene.renderProps");

		if (renderProps is String) {
			var s_renderProps:String = cast renderProps;

			var input = new Element('<input type="radio" name="renderProps" id="${s_renderProps}" value="${s_renderProps}"/>');
			input.get(0).toggleAttribute("checked", true);

			form_div.append(input);
			form_div.append(new Element('<label for="${s_renderProps}" class="left">${s_renderProps}</label>'));
			return;
		}

		if (renderProps is Array) {
			var a_renderProps = Std.downcast(renderProps, Array);
			var selectedRenderProps = editor.view.getDisplayState("renderProps");

			for (idx in 0...a_renderProps.length) {
				var rp = a_renderProps[idx];
				var input = new Element('<input type="radio" name="renderProps" id="${rp.name}" value="${rp.name}"/>');

				var isDefaultRenderProp = selectedRenderProps == null && idx == 0;
				var isSelectedRenderProp = selectedRenderProps != null && rp.value == selectedRenderProps.value;
				if (isDefaultRenderProp || isSelectedRenderProp)
					input.get(0).toggleAttribute("checked", true);

				input.change((e) -> {
					editor.view.saveDisplayState("renderProps", rp);
					editor.refreshScene();
					@:privateAccess editor.refreshTree();
				});

				form_div.append(input);
				form_div.append(new Element('<label for="${rp.name}" class="left">${rp.name}</label>'));
			}
			return;
		}

		form_div.append(new Element("<p>No render props detected in .json file.</p>"));
	}

	override function onSearchChanged(searchBar:Element) {
		var search = searchBar.val();
		var form_div = popup.find(".form-grid");

		popup.find("label").remove();
		popup.find('input[type=radio]').remove();

		var renderProps = hide.Ide.inst.currentConfig.get("scene.renderProps");
		if (renderProps is Array) {
			var a_renderProps = Std.downcast(renderProps, Array);
			var selectedRenderProps = editor.view.getDisplayState("renderProps");

			for (idx in 0...a_renderProps.length) {
				var rp = a_renderProps[idx];

				if (!StringTools.contains(rp.name.toLowerCase(), search.toLowerCase()))
					continue;

				var input = new Element('<input type="radio" name="renderProps" id="${rp.name}" value="${rp.name}"/>');

				var isDefaultRenderProp = selectedRenderProps == null && idx == 0;
				var isSelectedRenderProp = selectedRenderProps != null && rp.value == selectedRenderProps.value;
				if (isDefaultRenderProp || isSelectedRenderProp)
					input.get(0).toggleAttribute("checked", true);

				input.change((e) -> {
					editor.view.saveDisplayState("renderProps", rp);
					editor.refreshScene();
				});

				form_div.append(input);
				form_div.append(new Element('<label for="${rp.name}" class="left">${rp.name}</label>'));
			}
			return;
		}
	}
}

class SceneEditor {
	public var tree:hide.comp.IconTree<PrefabElement>;
	public var scene:hide.comp.Scene;
	public var properties:hide.comp.PropsEditor;
	public var context(default, null):hrt.prefab.Context;
	public var curEdit(default, null):SceneEditorContext;
	public var snapToGround = false;

	public var snapToggle = false;
	public var snapMoveStep = 1.0;
	public var snapRotateStep = 30.0;
	public var snapScaleStep = 1.0;
	public var snapForceOnGrid = false;

	public var localTransform = true;
	public var cameraController:CameraControllerBase;
	public var cameraController2D:hide.view.l3d.CameraController2D;
	public var editorDisplay(default, set):Bool;
	public var camera2D(default, set):Bool = false;
	public var objectAreSelectable = true;
	public var renderPropsRoot:Reference;

	var updates:Array<Float->Void> = [];

	var showGizmo = true;
	var gizmo:hide.view.l3d.Gizmo;
	var gizmo2d:hide.view.l3d.Gizmo2D;
	var basis:h3d.scene.Object;

	public var showBasis = false;

	static var customPivot:CustomPivot;

	var interactives:Map<PrefabElement, hxd.SceneEvents.Interactive>;
	var nextInteractivePriority = -1;
	var ide:hide.Ide;

	public var event(default, null):hxd.WaitEvent;

	var hideList:Map<PrefabElement, Bool> = new Map();

	var undo(get, null):hide.ui.UndoHistory;

	function get_undo() {
		return view.undo;
	}

	public var view(default, null):hide.view.FileView;

	var sceneData:PrefabElement;
	var lastRenderProps:hrt.prefab.RenderProps;

	public var lastFocusObjects:Array<Object> = [];

	public function new(view, data) {
		ide = hide.Ide.inst;
		this.view = view;
		this.sceneData = data;

		event = new hxd.WaitEvent();

		var propsEl = new Element('<div class="props"></div>');
		properties = new hide.comp.PropsEditor(undo, null, propsEl);
		properties.saveDisplayKey = view.saveDisplayKey + "/properties";

		tree = new hide.comp.IconTree();
		tree.async = false;
		tree.autoOpenNodes = false;

		var sceneEl = new Element('<div class="heaps-scene"></div>');
		scene = new hide.comp.Scene(view.config, null, sceneEl);
		scene.editor = this;
		scene.onReady = onSceneReady;
		scene.onResize = function() {
			if (cameraController2D != null)
				cameraController2D.toTarget();
			onResize();
		};

		context = new hrt.prefab.Context();
		context.shared = new hide.prefab.ContextShared(scene, this);
		context.shared.currentPath = view.state.path;
		context.init();
		editorDisplay = true;

		view.keys.register("copy", {name: "Copy", category: "Edit"}, onCopy);
		view.keys.register("paste", {name: "Paste", category: "Edit"}, onPaste);
		view.keys.register("cancel", {name: "De-select", category: "Scene"}, deselect);
		view.keys.register("selectAll", {name: "Select All", category: "Scene"}, selectAll);
		view.keys.register("duplicate", {name: "Duplicate", category: "Scene"}, duplicate.bind(true));
		view.keys.register("duplicateInPlace", {name: "Duplicate in place", category: "Scene"}, duplicate.bind(false));
		view.keys.register("group", {name: "Group Selection", category: "Scene"}, groupSelection);
		view.keys.register("delete", {name: "Delete", category: "Scene"}, () -> deleteElements(curEdit.rootElements));
		view.keys.register("search", {name: "Search", category: "Scene"}, function() tree.openFilter());
		view.keys.register("rename", {name: "Rename", category: "Scene"}, function() {
			if (curEdit.rootElements.length > 0)
				tree.editNode(curEdit.rootElements[0]);
		});

		view.keys.register("sceneeditor.focus", {name: "Focus Selection", category: "Scene"}, focusSelection);
		view.keys.register("sceneeditor.lasso", {name: "Lasso Select", category: "Scene"}, startLassoSelect);
		view.keys.register("sceneeditor.hide", {name: "Hide Selection", category: "Scene"}, function() {
			var isHidden = isHidden(curEdit.rootElements[0]);
			setVisible(curEdit.elements, isHidden);
		});
		view.keys.register("sceneeditor.isolate", {name: "Isolate", category: "Scene"}, function() {
			isolate(curEdit.elements);
		});
		view.keys.register("sceneeditor.showAll", {name: "Show all", category: "Scene"}, function() {
			setVisible(context.shared.elements(), true);
		});
		view.keys.register("sceneeditor.selectParent", {name: "Select Parent", category: "Scene"}, function() {
			if (curEdit.rootElements.length > 0) {
				var p = curEdit.rootElements[0].parent;
				if (p != null && p != sceneData)
					selectElements([p]);
			}
		});
		view.keys.register("sceneeditor.reparent", {name: "Reparent", category: "Scene"}, function() {
			if (curEdit.rootElements.length > 1) {
				var children = curEdit.rootElements.copy();
				var parent = children.pop();
				reparentElement(children, parent, 0);
			}
		});
		view.keys.register("sceneeditor.gatherToMouse", {name: "Gather to mouse", category: "Scene"}, gatherToMouse);

		// Load display state
		{
			var all = sceneData.flatten(hrt.prefab.Prefab);
			var list = @:privateAccess view.getDisplayState("hideList");
			if (list != null) {
				var m = [for (i in (list : Array<Dynamic>)) i => true];
				for (p in all) {
					if (m.exists(p.getAbsPath(true)))
						hideList.set(p, true);
				}
			}
		}
	}

	public function getSnapStatus():Bool {
		var ctrl = K.isDown(K.CTRL);
		return (snapToggle && !ctrl) || (!snapToggle && ctrl);
	};

	public function snap(value:Float, step:Float):Float {
		if (step > 0.0 && getSnapStatus())
			value = hxd.Math.round(value / step) * step;
		return value;
	}

	public function dispose() {
		scene.dispose();
		tree.dispose();
		clearWatches();
	}

	function set_camera2D(b) {
		if (cameraController != null)
			cameraController.visible = !b;
		if (cameraController2D != null)
			cameraController2D.visible = b;
		return camera2D = b;
	}

	public function onResourceChanged(lib:hxd.fmt.hmd.Library) {
		var models = sceneData.findAll(p -> Std.downcast(p, PrefabElement));
		var toRebuild:Array<PrefabElement> = [];
		for (m in models) {
			@:privateAccess if (m.source == lib.resource.entry.path) {
				if (toRebuild.indexOf(m) < 0) {
					toRebuild.push(m);
				}
			}
		}

		for (m in toRebuild) {
			removeInstance(m);
			makeInstance(m);
		}
	}

	public dynamic function onResize() {}

	function set_editorDisplay(v) {
		context.shared.editorDisplay = v;
		return editorDisplay = v;
	}

	public function getSelection() {
		return curEdit != null ? curEdit.elements : [];
	}

	function makeCamController():CameraControllerBase {
		// var c = new CameraController(scene.s3d, this);
		var c = new hide.view.CameraController.FlightController(scene.s3d, this);
		// c.friction = 0.9;
		// c.panSpeed = 0.6;
		// c.zoomAmount = 1.05;
		// c.smooth = 0.7;
		// c.minDistance = 1;
		return c;
	}

	public function setFullScreen(b:Bool) {
		view.fullScreen = b;
		if (b) {
			view.element.find(".tabs").hide();
		} else {
			view.element.find(".tabs").show();
		}
		var pview = Std.downcast(view, hide.view.Prefab);
		if (pview != null) {
			if (b)
				pview.hideColumns();
			else
				pview.showColumns();
		}
	}

	function makeCamController2D() {
		return new hide.view.l3d.CameraController2D(context.shared.root2d);
	}

	function focusSelection() {
		focusObjects(curEdit.rootObjects);
		for (obj in curEdit.rootElements)
			tree.revealNode(obj);
	}

	public function focusObjects(objs:Array<Object>) {
		var focusChanged = false;
		for (o in objs) {
			if (!lastFocusObjects.contains(o)) {
				focusChanged = true;
				break;
			}
		}

		if (objs.length > 0) {
			var bnds = new h3d.col.Bounds();
			var centroid = new h3d.Vector();
			for (obj in objs) {
				centroid = centroid.add(obj.getAbsPos().getPosition());
				bnds.add(obj.getBounds());
			}
			if (!bnds.isEmpty()) {
				var s = bnds.toSphere();
				var r = focusChanged ? null : s.r * 4.0;
				cameraController.set(r, null, null, s.getCenter());
			} else {
				centroid.scale3(1.0 / objs.length);
				cameraController.set(5.0, null, null, centroid.toPoint());
			}
		}
		lastFocusObjects = objs;
	}

	function getAvailableTags(p:PrefabElement):Array<{id:String, color:String}> {
		return null;
	}

	public function getTag(p:PrefabElement) {
		if (p.props != null) {
			var tagId = Reflect.field(p.props, "tag");
			if (tagId != null) {
				var tags = getAvailableTags(p);
				if (tags != null)
					return Lambda.find(tags, t -> t.id == tagId);
			}
		}
		return null;
	}

	public function setTag(p:PrefabElement, tag:String) {
		if (p.props == null)
			p.props = {};
		var prevVal = getTag(p);
		Reflect.setField(p.props, "tag", tag);
		onPrefabChange(p, "tag");
		undo.change(Field(p.props, "tag", prevVal), function() {
			onPrefabChange(p, "tag");
		});
	}

	function getTagMenu(p:PrefabElement):Array<hide.comp.ContextMenu.ContextMenuItem> {
		var tags = getAvailableTags(p);
		if (tags == null)
			return null;
		var ret = [];
		for (tag in tags) {
			var style = 'background-color: ${tag.color};';
			ret.push({
				label: '<span class="tag-disp-expand"><span class="tag-disp" style="$style">${tag.id}</span></span>',
				click: function() {
					if (getTag(p) == tag)
						setTag(p, null);
					else
						setTag(p, tag.id);
				},
				checked: getTag(p) == tag,
				stayOpen: true,
			});
		}
		return ret;
	}

	public function switchCamController(camClass:Class<CameraControllerBase>, force:Bool = false) {
		if (cameraController != null) {
			if (!force)
				saveCam3D();
			cameraController.remove();
		}

		cameraController = Type.createInstance(camClass, [scene.s3d, this]);
		loadCam3D();
	}

	public function loadSavedCameraController3D(force:Bool = false) {
		var wantedClass:Class<CameraControllerBase> = FPSController;
		var cam = @:privateAccess view.getDisplayState("Camera");
		if (cam != null && cam.camTypeIndex != null) {
			if (cam.camTypeIndex >= 0 && cam.camTypeIndex < CameraControllerEditor.controllersClasses.length) {
				wantedClass = CameraControllerEditor.controllersClasses[cam.camTypeIndex].cl;
			}
		}

		switchCamController(wantedClass, force);
	}

	public function loadCam3D() {
		cameraController.onClick = function(e) {
			switch (e.button) {
				case K.MOUSE_RIGHT:
					selectNewObject();
				case K.MOUSE_LEFT:
					selectElements([]);
			}
		};

		if (!camera2D)
			resetCamera();

		var cam = @:privateAccess view.getDisplayState("Camera");
		if (cam != null) {
			scene.s3d.camera.pos.set(cam.x, cam.y, cam.z);
			scene.s3d.camera.target.set(cam.tx, cam.ty, cam.tz);

			if (cam.ux == null) {
				scene.s3d.camera.up.set(0, 0, 1);
			} else {
				scene.s3d.camera.up.set(cam.ux, cam.uy, cam.uz);
			}
			cameraController.loadSettings(cam);
		}
		cameraController.loadFromCamera();
	}

	public function saveCam3D() {
		var cam = scene.s3d.camera;
		if (cam == null)
			return;
		var toSave:Dynamic = @:privateAccess view.getDisplayState("Camera");
		if (toSave == null)
			toSave = {};

		toSave.x = cam.pos.x;
		toSave.y = cam.pos.y;
		toSave.z = cam.pos.z;
		toSave.tx = cam.target.x;
		toSave.ty = cam.target.y;
		toSave.tz = cam.target.z;
		toSave.ux = cam.up.x;
		toSave.uy = cam.up.y;
		toSave.uz = cam.up.z;

		for (i in 0...CameraControllerEditor.controllersClasses.length) {
			if (CameraControllerEditor.controllersClasses[i].cl == Type.getClass(cameraController)) {
				toSave.camTypeIndex = i;
				break;
			}
		}

		cameraController.saveSettings(toSave);

		/*var cc = Std.downcast(cameraController, hide.view.CameraController.CamController);
			if (cc!=null) {
				var toSave = { x : cam.pos.x, y : cam.pos.y, z : cam.pos.z, tx : cam.target.x, ty : cam.target.y, tz : cam.target.z,
					isFps : cc.isFps,
					isOrtho : cc.isOrtho,
					camSpeed : cc.camSpeed,
					fov : cc.wantedFOV,
		};*/
		@:privateAccess view.saveDisplayState("Camera", toSave);
	}

	function loadSnapSettings() {
		// node : Snap toggle is already handled by the toolbar
		function sanitize(value:Dynamic, def:Dynamic) {
			if (value == null || value == 0.0)
				return def;
			return value;
		}
		@:privateAccess snapMoveStep = sanitize(view.getDisplayState("snapMoveStep"), snapMoveStep);
		@:privateAccess snapRotateStep = sanitize(view.getDisplayState("snapRotateStep"), snapRotateStep);
		@:privateAccess snapScaleStep = sanitize(view.getDisplayState("snapScaleStep"), snapScaleStep);
		@:privateAccess snapForceOnGrid = view.getDisplayState("snapForceOnGrid");
	}

	public function saveSnapSettings() {
		@:privateAccess view.saveDisplayState("snapMoveStep", snapMoveStep);
		@:privateAccess view.saveDisplayState("snapRotateStep", snapRotateStep);
		@:privateAccess view.saveDisplayState("snapScaleStep", snapScaleStep);
		@:privateAccess view.saveDisplayState("snapForceOnGrid", snapForceOnGrid);
	}

	function toggleSnap(?force:Bool) {
		if (force != null)
			snapToggle = force;
		else
			snapToggle = !snapToggle;

		var snap = new Element("#snap").get(0);
		if (snap != null) {
			snap.toggleAttribute("checked", snapToggle);
		}

		updateGrid();
	}

	function onSceneReady() {
		tree.saveDisplayKey = view.saveDisplayKey + '/tree';

		scene.s2d.addChild(context.shared.root2d);
		scene.s3d.addChild(context.shared.root3d);

		gizmo = new hide.view.l3d.Gizmo(scene);
		view.keys.register("sceneeditor.translationMode", gizmo.translationMode);
		view.keys.register("sceneeditor.rotationMode", gizmo.rotationMode);
		view.keys.register("sceneeditor.scalingMode", gizmo.scalingMode);

		gizmo2d = new hide.view.l3d.Gizmo2D();
		scene.s2d.add(gizmo2d, 1); // over local3d

		basis = new h3d.scene.Object(scene.s3d);

		// Note : we create 2 different graphics because
		// 1 graohic can only handle one line style, and
		// we want the forward vector to be thicker so
		// it's easier to recognise
		{
			var fwd = new h3d.scene.Graphics(basis);
			fwd.is3D = false;
			fwd.lineStyle(1.25, 0xFF0000);
			fwd.lineTo(1.0, 0.0, 0.0);

			var mat = fwd.getMaterials()[0];
			mat.mainPass.depth(false, Always);
			mat.mainPass.setPassName("ui");
			mat.mainPass.blend(SrcAlpha, OneMinusSrcAlpha);
		}

		{
			var otheraxis = new h3d.scene.Graphics(basis);

			otheraxis.lineStyle(.75, 0x00FF00);

			otheraxis.moveTo(0.0, 0.0, 0.0);
			otheraxis.setColor(0x00FF00);
			otheraxis.lineTo(0.0, 2.0, 0.0);

			otheraxis.moveTo(0.0, 0.0, 0.0);
			otheraxis.setColor(0x0000FF);
			otheraxis.lineTo(0.0, 0.0, 2.0);

			var mat = otheraxis.getMaterials()[0];
			mat.mainPass.depth(false, Always);
			mat.mainPass.setPassName("ui");
			mat.mainPass.blend(SrcAlpha, OneMinusSrcAlpha);
		}

		basis.visible = true;

		loadSavedCameraController3D();

		loadSnapSettings();

		scene.s2d.defaultSmooth = true;
		context.shared.root2d.x = scene.s2d.width >> 1;
		context.shared.root2d.y = scene.s2d.height >> 1;
		cameraController2D = makeCamController2D();
		cameraController2D.onClick = cameraController.onClick;
		var cam2d = @:privateAccess view.getDisplayState("Camera2D");
		if (cam2d != null) {
			context.shared.root2d.x = scene.s2d.width * 0.5 + cam2d.x;
			context.shared.root2d.y = scene.s2d.height * 0.5 + cam2d.y;
			context.shared.root2d.setScale(cam2d.z);
		}
		cameraController2D.loadFromScene();
		if (camera2D)
			resetCamera();

		scene.onUpdate = update;

		// BUILD scene tree

		var icons = new Map();
		var iconsConfig = view.config.get("sceneeditor.icons");
		for (f in Reflect.fields(iconsConfig))
			icons.set(f, Reflect.field(iconsConfig, f));

		function makeItem(o:PrefabElement, ?state):hide.comp.IconTree.IconTreeItem<PrefabElement> {
			var p = o.getHideProps();
			var ref = o.to(Reference);
			var icon = p.icon;
			var ct = o.getCdbType();
			if (ct != null && icons.exists(ct))
				icon = icons.get(ct);
			var r:hide.comp.IconTree.IconTreeItem<PrefabElement> = {
				value: o,
				text: o.name,
				icon: "ico ico-" + icon,
				children: o.children.length > 0 || (ref != null && @:privateAccess ref.editMode),
				state: state
			};
			return r;
		}
		tree.get = function(o:PrefabElement) {
			var objs = o == null ? sceneData.children : Lambda.array(o);
			if (o != null && o.getHideProps().hideChildren != null) {
				var hideChildren = o.getHideProps().hideChildren;
				var visibleObjs = [];
				for (o in objs) {
					if (hideChildren(o))
						continue;
					visibleObjs.push(o);
				}
				objs = visibleObjs;
			}
			var ref = o == null ? null : o.to(Reference);
			@:privateAccess if (ref != null && ref.editMode && ref.ref != null) {
				for (c in ref.ref)
					objs.push(c);
			}
			var out = [for (o in objs) makeItem(o)];
			return out;
		};
		function ctxMenu(tree, e) {
			e.preventDefault();
			var current = tree.getCurrentOver();
			if (current != null && (curEdit == null || curEdit.elements.indexOf(current) < 0)) {
				selectElements([current]);
			}

			var newItems = getNewContextMenu(current);
			var menuItems:Array<hide.comp.ContextMenu.ContextMenuItem> = [];

			var triggerMenuItems:Array<hide.comp.ContextMenu.ContextMenuItem> = buildTriggerCreateMenu(current);
			var shapeMenuItems:Array<hide.comp.ContextMenu.ContextMenuItem> = buildShapeCreateMenu(current);
			var torqueMenuItems:Array<hide.comp.ContextMenu.ContextMenuItem> = buildTorqueCreateMenu(current);

			menuItems.push({
				label: "Create...",
				menu: [
					{
						label: "Shapes",
						menu: shapeMenuItems
					},
					{
						label: "Triggers",
						menu: triggerMenuItems
					}
				].concat(torqueMenuItems)
			});

			var actionItems:Array<hide.comp.ContextMenu.ContextMenuItem> = [
				{
					label: "Rename",
					enabled: current != null,
					click: function() tree.editNode(current),
					keys: view.config.get("key.rename")
				},
				{
					label: "Delete",
					enabled: current != null,
					click: function() deleteElements(curEdit.rootElements),
					keys: view.config.get("key.delete")
				},
				{
					label: "Duplicate",
					enabled: current != null,
					click: duplicate.bind(false),
					keys: view.config.get("key.duplicateInPlace")
				},
			];

			var isObj = current != null && (current.to(Object3D) != null || current.to(Object2D) != null);
			var isRef = isReference(current);

			if (isObj) {
				menuItems = menuItems.concat([
					{
						label: "Visible",
						checked: !isHidden(current),
						stayOpen: true,
						click: function() setVisible(curEdit.elements, isHidden(current)),
						keys: view.config.get("key.sceneeditor.hide")
					},
					{
						label: "Locked",
						checked: current.locked,
						stayOpen: true,
						click: function() {
							current.locked = !current.locked;
							setLock(curEdit.elements, current.locked);
						}
					},
					{label: "Select all", click: selectAll, keys: view.config.get("key.selectAll")},
					{label: "Select children", enabled: current != null, click: function() selectElements(current.flatten())},
				]);
				if (!isRef)
					actionItems = actionItems.concat([
						{label: "Isolate", click: function() isolate(curEdit.elements), keys: view.config.get("key.sceneeditor.isolate")},
						{
							label: "Group",
							enabled: curEdit != null && canGroupSelection(),
							click: groupSelection,
							keys: view.config.get("key.group")
						},
					]);
			}

			menuItems.push({isSeparator: true, label: ""});
			new hide.comp.ContextMenu(menuItems.concat(actionItems));
		};
		tree.element.parent().contextmenu(ctxMenu.bind(tree));
		tree.allowRename = true;
		tree.init();
		tree.onClick = function(e, _) {
			selectElements(tree.getSelection(), NoTree);
		}
		tree.onDblClick = function(e) {
			focusSelection();
			return true;
		}
		tree.onRename = function(e, name) {
			var oldName = e.name;
			e.name = name;
			var to = cast(e, hrt.prefab.l3d.TorqueObject);
			if (to != null) {
				to.setName(name);
			}
			undo.change(Field(e, "name", oldName), function() {
				if (to != null) {
					to.setName(oldName);
				}
				tree.refresh();
				// refreshScene();
			});
			// refreshScene();
			return true;
		};
		tree.onAllowMove = function(e, to) return checkAllowParent({cl: e.type, inf: e.getHideProps()}, to);

		// Batch tree.onMove, which is called for every node moved, causing problems with undo and refresh
		{
			var movetimer:haxe.Timer = null;
			var moved = [];
			tree.onMove = function(e, to, idx) {
				if (movetimer != null) {
					movetimer.stop();
				}
				moved.push(e);
				movetimer = haxe.Timer.delay(function() {
					reparentElement(moved, to, idx);
					movetimer = null;
					moved = [];
				}, 50);
			}
		}
		tree.applyStyle = function(p, el) applyTreeStyle(p, el);
		selectElements([]);
		refresh();
		this.camera2D = camera2D;
	}

	function checkAllowParent(prefabInf, prefabParent:PrefabElement):Bool {
		if (prefabInf.inf.allowParent == null)
			if (prefabParent == null
				|| prefabParent.getHideProps().allowChildren == null
				|| (prefabParent.getHideProps().allowChildren != null && prefabParent.getHideProps().allowChildren(prefabInf.cl)))
				return true;
			else
				return false;

		if (prefabParent == null)
			if (prefabInf.inf.allowParent(sceneData))
				return true;
			else
				return false;

		if ((prefabParent.getHideProps().allowChildren == null
			|| prefabParent.getHideProps().allowChildren != null
			&& prefabParent.getHideProps().allowChildren(prefabInf.cl))
			&& prefabInf.inf.allowParent(prefabParent))
			return true;
		return false;
	};

	public function refresh(?mode:RefreshMode, ?callb:Void->Void) {
		if (mode == null || mode == Full)
			refreshScene();
		refreshTree(callb);
	}

	public function collapseTree() {
		tree.collapseAll();
	}

	function refreshTree(?callb) {
		tree.refresh(function() {
			var all = sceneData.flatten(hrt.prefab.Prefab);
			for (elt in all) {
				var el = tree.getElement(elt);
				if (el == null)
					continue;
				applyTreeStyle(elt, el);
			}
			if (callb != null)
				callb();
		});
	}

	function refreshProps() {
		selectElements(curEdit.elements, Nothing);
	}

	var refWatches:Map<String, {callb:Void->Void, ignoreCount:Int}> = [];

	public function watchIgnoreChanges(source:String) {
		var w = refWatches.get(source);
		if (w == null)
			return;
		w.ignoreCount++;
	}

	public function watch(source:String) {
		var w = refWatches.get(source);
		if (w != null)
			return;
		w = {
			callb: function() {
				if (w.ignoreCount > 0) {
					w.ignoreCount--;
					return;
				}
				if (view.modified && !ide.confirm('${source} has been modified, reload and ignore local changes?'))
					return;
				view.undo.clear();
				view.rebuild();
			},
			ignoreCount: 0
		};
		refWatches.set(source, w);
		ide.fileWatcher.register(source, w.callb, false, scene.element);
	}

	function clearWatches() {
		var prev = refWatches;
		refWatches = [];
		for (source => w in prev)
			ide.fileWatcher.unregister(source, w.callb);
	}

	function createRenderProps(?parent:hrt.prefab.Prefab) {
		renderPropsRoot = new Reference();

		if (parent != null)
			renderPropsRoot.parent = parent;

		renderPropsRoot.name = "Render Props";
		@:privateAccess renderPropsRoot.editMode = true;

		var renderProps = view.config.getLocal("scene.renderProps");

		if (renderProps is String) {
			renderPropsRoot.source = cast renderProps;
		}

		if (renderProps is Array) {
			var a_renderProps = Std.downcast(renderProps, Array);
			var savedRenderProp = @:privateAccess view.getDisplayState("renderProps");

			// Check if the saved render prop hasn't been deleted from json
			var isRenderPropAvailable = false;
			for (idx in 0...a_renderProps.length) {
				if (savedRenderProp != null && a_renderProps[idx].value == savedRenderProp.value)
					isRenderPropAvailable = true;
			}

			renderPropsRoot.source = view.config.getLocal("scene.renderProps")[0].value;
			if (savedRenderProp != null && isRenderPropAvailable)
				renderPropsRoot.source = savedRenderProp.value;
		}

		var ctx2 = renderPropsRoot.makeInstance(context);

		var lights = renderPropsRoot.getAll(hrt.prefab.Light, true);
		for (light in lights) {
			var ctxs = ctx2.shared.getContexts(light);
			for (ctx in ctxs) {
				var icon = Std.downcast(ctx.custom, hrt.impl.EditorTools.EditorIcon);
				if (icon != null) {
					icon.remove();
					ctx.custom = null;
				}
			}
		}

		if (@:privateAccess renderPropsRoot.ref != null) {
			var renderProps = @:privateAccess renderPropsRoot.ref.getOpt(hrt.prefab.RenderProps);
			if (renderProps != null)
				renderProps.applyProps(scene.s3d.renderer);
		}
	}

	public function cleanup() {
		sceneData.cleanup();
		var sh = context.shared;
		sh.root3d.remove();
		sh.root2d.remove();
		for (pref => int in interactives) {
			var i3d = Std.downcast(int, h3d.scene.Interactive);
			i3d.remove();
			i3d.onPush = null;
			i3d.onMove = null;
			i3d.onClick = null;
			i3d.onRelease = null;
			i3d.preciseShape = null;
			i3d.shape = null;
		}
		interactives.clear();
		interactives = [];

		for (c in sh.contexts)
			if (c != null && c.cleanup != null)
				c.cleanup();
	}

	public function refreshScene() {
		clearWatches();

		var sh = context.shared;
		sh.root3d.removeChildren();
		sh.root3d.remove();
		sh.root2d.remove();

		for (c in sh.contexts)
			if (c != null && c.cleanup != null)
				c.cleanup();
		context.shared = sh = new hide.prefab.ContextShared(scene, this);
		sh.editorDisplay = editorDisplay;
		sh.currentPath = view.state.path;
		scene.s3d.addChild(sh.root3d);
		scene.s2d.addChild(sh.root2d);
		sh.root2d.addChild(cameraController2D);
		scene.setCurrent();
		scene.onResize();
		context.init();
		sceneData.make(context);
		var bgcol = scene.engine.backgroundColor;
		scene.init();
		scene.engine.backgroundColor = bgcol;
		refreshInteractives();

		var contexts = context.shared.contexts;
		var all = contexts.keys();
		for (elt in all)
			applySceneStyle(elt);

		// Find latest existing render props in scene
		var renderProps = getAllWithRefs(sceneData, hrt.prefab.RenderProps);
		for (r in renderProps)
			if (@:privateAccess r.isDefault) {
				lastRenderProps = r;
				break;
			}

		if (lastRenderProps == null)
			lastRenderProps = renderProps[0];

		if (lastRenderProps != null)
			lastRenderProps.applyProps(scene.s3d.renderer);
		else {
			createRenderProps();
		}

		onRefresh();
	}

	function getAllWithRefs<T:hrt.prefab.Prefab>(p:hrt.prefab.Prefab, cl:Class<T>, ?arr:Array<T>):Array<T> {
		if (arr == null)
			arr = [];
		var v = p.to(cl);
		if (v != null)
			arr.push(v);
		for (c in p.children)
			getAllWithRefs(c, cl, arr);
		var ref = p.to(Reference);
		@:privateAccess if (ref != null && ref.ref != null)
			getAllWithRefs(ref.ref, cl, arr);
		return arr;
	}

	public dynamic function onRefresh() {}

	function makeInteractive(elt:PrefabElement, ?shared:hrt.prefab.ContextShared) {
		if (shared == null)
			shared = context.shared;
		var ctx = shared.contexts[elt];
		if (ctx == null)
			return;
		var int = elt.makeInteractive(ctx);
		if (int != null) {
			initInteractive(elt, cast int);
			if (isLocked(elt))
				toggleInteractive(elt, false);
		}
		var ref = Std.downcast(elt, Reference);
		@:privateAccess if (ref != null && ref.editMode) {
			var ctx = shared.getRef(elt);
			for (p in ref.ref.flatten())
				makeInteractive(p, ctx);
		}
	}

	function toggleInteractive(e:PrefabElement, visible:Bool) {
		var int = getInteractive(e);
		if (int == null)
			return;
		var i2d = Std.downcast(int, h2d.Interactive);
		var i3d = Std.downcast(int, h3d.scene.Interactive);
		if (i2d != null)
			i2d.visible = visible;
		if (i3d != null)
			i3d.visible = visible;
	}

	function initInteractive(elt:PrefabElement, int:{
		dynamic function onPush(e:hxd.Event):Void;
		dynamic function onMove(e:hxd.Event):Void;
		dynamic function onRelease(e:hxd.Event):Void;
		dynamic function onClick(e:hxd.Event):Void;
		function handleEvent(e:hxd.Event):Void;
		function preventClick():Void;
	}) {
		if (int == null)
			return;
		var startDrag = null;
		var curDrag = null;
		var dragBtn = -1;
		var lastPush:Array<Float> = null;
		var i3d = Std.downcast(int, h3d.scene.Interactive);
		var i2d = Std.downcast(int, h2d.Interactive);

		int.onClick = function(e) {
			if (e.button == K.MOUSE_RIGHT) {
				var dist = hxd.Math.distance(scene.s2d.mouseX - lastPush[0], scene.s2d.mouseY - lastPush[1]);
				if (dist > 5)
					return;
				selectNewObject();
				e.propagate = false;
				return;
			}
		}
		int.onPush = function(e) {
			if (e.button == K.MOUSE_MIDDLE)
				return;
			startDrag = [scene.s2d.mouseX, scene.s2d.mouseY];
			if (e.button == K.MOUSE_RIGHT)
				lastPush = startDrag;
			dragBtn = e.button;
			if (e.button == K.MOUSE_LEFT) {
				var elts = null;
				if (K.isDown(K.SHIFT)) {
					if (Type.getClass(elt.parent) == hrt.prefab.Object3D)
						elts = [elt.parent];
					else
						elts = elt.parent.children;
				} else
					elts = [elt];
				i3d.priority = nextInteractivePriority--;
				if (K.isDown(K.CTRL)) {
					var current = curEdit.elements.copy();
					if (current.indexOf(elt) < 0) {
						for (e in elts) {
							if (current.indexOf(e) < 0)
								current.push(e);
						}
					} else {
						for (e in elts)
							current.remove(e);
					}
					selectElements(current);
				} else
					selectElements(elts);
			}
			// ensure we get onMove even if outside our interactive, allow fast click'n'drag
			if (e.button == K.MOUSE_LEFT) {
				scene.sevents.startCapture(int.handleEvent);
				e.propagate = false;
			}
		};
		int.onRelease = function(e) {
			if (e.button == K.MOUSE_MIDDLE)
				return;
			startDrag = null;
			curDrag = null;
			dragBtn = -1;
			if (e.button == K.MOUSE_LEFT) {
				scene.sevents.stopCapture();
				e.propagate = false;
			}
		}
		int.onMove = function(e) {
			if (startDrag != null && hxd.Math.distance(startDrag[0] - scene.s2d.mouseX, startDrag[1] - scene.s2d.mouseY) > 5) {
				if (dragBtn == K.MOUSE_LEFT) {
					if (i3d != null) {
						moveGizmoToSelection();
						gizmo.startMove(MoveXY);
					}
					if (i2d != null) {
						moveGizmoToSelection();
						gizmo2d.startMove(Pan);
					}
				}
				int.preventClick();
				startDrag = null;
			}
		}
		interactives.set(elt, cast int);
	}

	function selectNewObject() {
		if (!objectAreSelectable)
			return;
		var parentEl = sceneData;
		// for now always create at scene root, not `curEdit.rootElements[0];`
		var group = getParentGroup(parentEl);
		if (group != null)
			parentEl = group;

		var origTrans = getPickTransform(parentEl);
		if (origTrans == null) {
			origTrans = new h3d.Matrix();
			origTrans.identity();
		}

		var originPt = origTrans.getPosition();
		var newItems = getNewContextMenu(parentEl, function(newElt) {
			var newObj3d = Std.downcast(newElt, Object3D);
			if (newObj3d != null) {
				var newPos = new h3d.Matrix();
				newPos.identity();
				newPos.setPosition(originPt);
				var invParent = getObject(parentEl).getAbsPos().clone();
				invParent.invert();
				newPos.multiply(newPos, invParent);
				newObj3d.setTransform(newPos);
			}
			var newObj2d = Std.downcast(newElt, Object2D);
			if (newObj2d != null) {
				var pt = new h2d.col.Point(scene.s2d.mouseX, scene.s2d.mouseY);
				var l2d = getContext(parentEl).local2d;
				l2d.globalToLocal(pt);
				newObj2d.x = pt.x;
				newObj2d.y = pt.y;
			}
		});

		var mg:PrefabElement = parentEl.getPrefabByName("MissionGroup");
		if (mg == null)
			mg = parentEl;

		var triggerMenuItems:Array<hide.comp.ContextMenu.ContextMenuItem> = buildTriggerCreateMenu(mg, newElt -> {
			var newObj3d = Std.downcast(newElt, Object3D);
			if (newObj3d != null) {
				var newPos = new h3d.Matrix();
				newPos.identity();
				newPos.setPosition(originPt);
				var invParent = getObject(mg).getAbsPos().clone();
				invParent.invert();
				newPos.multiply(newPos, invParent);
				newObj3d.setTransform(newPos);
			}
		});

		var shapeMenuItems:Array<hide.comp.ContextMenu.ContextMenuItem> = buildShapeCreateMenu(mg, newElt -> {
			var newObj3d = Std.downcast(newElt, Object3D);
			if (newObj3d != null) {
				var newPos = new h3d.Matrix();
				newPos.identity();
				newPos.setPosition(originPt);
				var invParent = getObject(mg).getAbsPos().clone();
				invParent.invert();
				newPos.multiply(newPos, invParent);
				newObj3d.setTransform(newPos);
			}
		});

		var torqueMenuItems:Array<hide.comp.ContextMenu.ContextMenuItem> = buildTorqueCreateMenu(mg, newElt -> {
			var newObj3d = Std.downcast(newElt, Object3D);
			if (newObj3d != null) {
				var newPos = new h3d.Matrix();
				newPos.identity();
				newPos.setPosition(originPt);
				var invParent = getObject(mg).getAbsPos().clone();
				invParent.invert();
				newPos.multiply(newPos, invParent);
				newObj3d.setTransform(newPos);
			}
		});

		var menuItems:Array<hide.comp.ContextMenu.ContextMenuItem> = [
			{
				label: "Create...",
				menu: [
					{
						label: "Shapes",
						menu: shapeMenuItems
					},
					{
						label: "Triggers",
						menu: triggerMenuItems
					}
				].concat(torqueMenuItems)
			},
			{isSeparator: true, label: ""},
			{
				label: "Gather here",
				click: gatherToMouse,
				enabled: (curEdit.rootElements.length > 0),
				keys: view.config.get("key.sceneeditor.gatherToMouse"),
			},
			{
				label: "Drop to Ground",
				enabled: (curEdit.rootElements.length > 0),
				click: dropToGround,
			}
		];
		new hide.comp.ContextMenu(menuItems);
	}

	public function buildTriggerCreateMenu(current:PrefabElement, ?onMake:PrefabElement->Void = null):Array<hide.comp.ContextMenu.ContextMenuItem> {
		var e = hrt.mis.TorqueConfig.creatorMenuJson.triggers.map(t -> {
			var pmodel = hrt.prefab.Library.getRegistered().get("trigger");
			var parent = current == null ? sceneData : current;

			var ret:hide.comp.ContextMenu.ContextMenuItem = {
				label: t.name,
				icon: "square-o",
				click: () -> {
					var p:hrt.prefab.l3d.Trigger = cast Type.createInstance(pmodel.cl, [parent]);
					@:privateAccess p.type = "trigger";
					p.name = "";
					p.customFieldProvider = t.name.toLowerCase();

					if (onMake != null)
						onMake(p);
					addElements([p]);
				}
			};
			return ret;
		});
		function sortByLabel(arr:Array<hide.comp.ContextMenu.ContextMenuItem>) {
			arr.sort(function(l1, l2) return Reflect.compare(l1.label, l2.label));
		}
		sortByLabel(e);
		return e;
	}

	public function buildShapeCreateMenu(current:PrefabElement, ?onMake:PrefabElement->Void = null):Array<hide.comp.ContextMenu.ContextMenuItem> {
		var kvi = new haxe.iterators.DynamicAccessKeyValueIterator(hrt.mis.TorqueConfig.creatorMenuJson.shapes);
		var items:Array<hide.comp.ContextMenu.ContextMenuItem> = [];

		function sortByLabel(arr:Array<hide.comp.ContextMenu.ContextMenuItem>) {
			arr.sort(function(l1, l2) return Reflect.compare(l1.label.toLowerCase(), l2.label.toLowerCase()));
		}

		var treeThing:Map<String, hide.comp.ContextMenu.ContextMenuItem> = [];

		for (k => v in kvi) {
			var insCat:hide.comp.ContextMenu.ContextMenuItem;
			if (k.indexOf(".") != -1) {
				var spl = k.split('.');
				var superCategory = spl[0];
				var category = spl[1];

				if (treeThing.get(superCategory) == null) {
					var item:hide.comp.ContextMenu.ContextMenuItem = {label: superCategory, menu: []};
					treeThing.set(superCategory, item);
					items.push(item);

					var subitem:hide.comp.ContextMenu.ContextMenuItem = {label: category, menu: []};
					item.menu.push(subitem);
					insCat = subitem;
				} else {
					insCat = treeThing.get(superCategory).menu.find(x -> x.label == category);
					if (insCat == null) {
						var subitem:hide.comp.ContextMenu.ContextMenuItem = {label: category, menu: []};
						treeThing.get(superCategory).menu.push(subitem);
						insCat = subitem;
					}
				}
			} else {
				if (treeThing.get(k) == null) {
					var item:hide.comp.ContextMenu.ContextMenuItem = {label: k, menu: []};
					treeThing.set(k, item);
					items.push(item);
					insCat = item;
				} else {
					insCat = treeThing.get(k);
				}
			}

			var shapeGroup:Array<hrt.mis.TorqueConfig.ShapeCreatorMenuJson> = cast v;
			for (s in shapeGroup) {
				var pmodel = hrt.prefab.Library.getRegistered().get(s.classname.toLowerCase());
				var parent = current == null ? sceneData : current;

				var ret:hide.comp.ContextMenu.ContextMenuItem = {
					label: s.name,
					icon: pmodel.inf.icon,
					click: () -> {
						var p:hrt.prefab.l3d.DtsMesh = cast Type.createInstance(pmodel.cl, [parent]);
						@:privateAccess p.type = s.classname.toLowerCase();
						p.name = "";
						p.customFieldProvider = s.name.toLowerCase();
						p.path = StringTools.replace(StringTools.replace(s.shapefile.toLowerCase(), "marble/", ""), "platinum/", "");
						p.skin = s.skin == "" ? null : s.skin;

						p.customFields = hrt.mis.TorqueConfig.getDataBlock(s.name).fields.filter(x -> x.defaultValue != null).map(x -> {
							return {field: x.name.toLowerCase(), value: '${x.defaultValue}'};
						});

						if (onMake != null)
							onMake(p);
						addElements([p]);
					}
				};
				insCat.menu.push(ret);
			}

			sortByLabel(insCat.menu);
		}
		sortByLabel(items);
		return items;
	}

	public function buildTorqueCreateMenu(current:PrefabElement, ?onMake:PrefabElement->Void = null) {
		var parent = current == null ? sceneData : current;

		var makeTMenuItem:String->hide.comp.ContextMenu.ContextMenuItem = (cname:String) -> {
			var pmodel = hrt.prefab.Library.getRegistered().get(cname.toLowerCase());

			var buildFn = (cname:String) -> {
				var p = Type.createInstance(pmodel.cl, [parent]);
				@:privateAccess p.type = cname.toLowerCase();
				p.name = cname;

				if (onMake != null)
					onMake(p);

				if (pmodel.inf.fileSource != null) {
					ide.chooseFile(pmodel.inf.fileSource, function(path) {
						// Ew hardcoded lol
						if (StringTools.startsWith(path, "../")) {
							// Invalid, out of our root directory
							js.Browser.window.alert("Please select a file within the project folder.");
						} else {
							if (p is hrt.prefab.l3d.Interior)
								cast(p, hrt.prefab.l3d.Interior).path = path;
							if (p is hrt.prefab.l3d.PathedInterior)
								cast(p, hrt.prefab.l3d.PathedInterior).path = path;
							if (p is hrt.prefab.l3d.TSStatic) {
								cast(p, hrt.prefab.l3d.TSStatic).path = path;
							}
							addElements([p]);
						}
					});
				} else
					addElements([p]);
			};

			return {
				label: cname,
				icon: pmodel.inf.icon,
				click: () -> {
					buildFn(cname);
				}
			}
		}

		var menu:Array<hide.comp.ContextMenu.ContextMenuItem> = [
			{
				label: "Interior",
				menu: [
					makeTMenuItem("InteriorInstance"),
					makeTMenuItem("PathedInterior"),
					makeTMenuItem("Path")
				]
			},
			{
				label: "Environment",
				menu: [makeTMenuItem("Sun"), makeTMenuItem("Sky")]
			},
			{
				label: "Torque",
				menu: [
					makeTMenuItem("SimGroup"),
					makeTMenuItem("ScriptObject"),
					makeTMenuItem("TSStatic")
				]
			}
		];

		return menu;
	}

	public function refreshInteractive(elt:PrefabElement) {
		var int = interactives.get(elt);
		if (int != null) {
			var i3d = Std.downcast(int, h3d.scene.Interactive);
			if (i3d != null)
				i3d.remove()
			else
				cast(int, h2d.Interactive).remove();
			interactives.remove(elt);
		}
		makeInteractive(elt);
	}

	function refreshInteractives() {
		var contexts = context.shared.contexts;
		interactives = new Map();
		var all = contexts.keys();
		for (elt in all) {
			makeInteractive(elt);
		}
	}

	public dynamic function updateGrid() {}

	function setupGizmo() {
		if (curEdit == null)
			return;

		var posQuant = view.config.get("sceneeditor.xyzPrecision");
		var scaleQuant = view.config.get("sceneeditor.scalePrecision");
		var rotQuant = view.config.get("sceneeditor.rotatePrecision");
		inline function quantize(x:Float, step:Float) {
			if (step > 0) {
				x = Math.round(x / step) * step;
				x = untyped parseFloat(x.toFixed(5)); // Snap to closest nicely displayed float :cold_sweat:
			}
			return x;
		}

		gizmo.onStartMove = function(mode) {
			var objects3d = [
				for (o in curEdit.rootElements) {
					var obj3d = o.to(hrt.prefab.Object3D);
					if (obj3d != null) obj3d;
				}
			];
			var sceneObjs = [for (o in objects3d) getContext(o).local3d];
			var pivotPt = getPivot(sceneObjs);
			var pivot = new h3d.Matrix();
			pivot.initTranslation(pivotPt.x, pivotPt.y, pivotPt.z);
			var invPivot = pivot.clone();
			invPivot.invert();

			var localMats = [
				for (o in sceneObjs) {
					var m = worldMat(o);
					m.multiply(m, invPivot);
					m;
				}
			];

			var prevState = [for (o in objects3d) o.saveTransform()];
			gizmo.onMove = function(translate:h3d.Vector, rot:h3d.Quat, scale:h3d.Vector) {
				var transf = new h3d.Matrix();
				transf.identity();
				if (rot != null) {
					rot.toMatrix(transf);
				}
				if (translate != null)
					transf.translate(translate.x, translate.y, translate.z);
				for (i in 0...sceneObjs.length) {
					var newMat = localMats[i].clone();
					newMat.multiply(newMat, transf);
					newMat.multiply(newMat, pivot);
					if (snapToGround && mode == MoveXY) {
						newMat.tz = getZ(newMat.tx, newMat.ty);
					}
					var obj3d = sceneObjs[i];
					var parentMat = obj3d.parent.getAbsPos().clone();
					if (obj3d.follow != null) {
						if (obj3d.followPositionOnly)
							parentMat.setPosition(obj3d.follow.getAbsPos().getPosition());
						else
							parentMat = obj3d.follow.getAbsPos().clone();
					}
					var invParent = parentMat;
					invParent.invert();
					newMat.multiply(newMat, invParent);
					if (scale != null) {
						newMat.prependScale(scale.x, scale.y, scale.z);
					}
					var obj3d = objects3d[i];
					var euler = newMat.getEulerAngles();
					if (translate != null && translate.length() > 0.0001 && snapForceOnGrid) {
						obj3d.x = snap(quantize(newMat.tx, posQuant), snapMoveStep);
						obj3d.y = snap(quantize(newMat.ty, posQuant), snapMoveStep);
						obj3d.z = snap(quantize(newMat.tz, posQuant), snapMoveStep);
					} else { // Don't snap translation if the primary action wasn't a translation (i.e. Rotation around a pivot)
						obj3d.x = quantize(newMat.tx, posQuant);
						obj3d.y = quantize(newMat.ty, posQuant);
						obj3d.z = quantize(newMat.tz, posQuant);
					}

					if (rot != null) {
						var rotQX = quantize(M.radToDeg(euler.x), rotQuant);
						var rotQY = quantize(M.radToDeg(euler.y), rotQuant);
						var rotQZ = quantize(M.radToDeg(euler.z), rotQuant);
						var q = new h3d.Quat();
						q.initRotation(hxd.Math.degToRad(rotQX), hxd.Math.degToRad(rotQY), hxd.Math.degToRad(rotQZ));
						obj3d.rotationX = q.x;
						obj3d.rotationY = q.y;
						obj3d.rotationZ = q.z;
						obj3d.rotationW = q.w;
					}

					if (scale != null) {
						var s = newMat.getScale();
						obj3d.scaleX = quantize(s.x, scaleQuant);
						obj3d.scaleY = quantize(s.y, scaleQuant);
						obj3d.scaleZ = quantize(s.z, scaleQuant);
					}
					obj3d.applyTransform(sceneObjs[i]);
				}
			}

			gizmo.onFinishMove = function() {
				var newState = [for (o in objects3d) o.saveTransform()];
				refreshProps();
				undo.change(Custom(function(undo) {
					if (undo) {
						for (i in 0...objects3d.length) {
							objects3d[i].loadTransform(prevState[i]);
							objects3d[i].applyTransform(sceneObjs[i]);
						}
						refreshProps();
					} else {
						for (i in 0...objects3d.length) {
							objects3d[i].loadTransform(newState[i]);
							objects3d[i].applyTransform(sceneObjs[i]);
						}
						refreshProps();
					}

					for (o in objects3d)
						o.updateInstance(getContext(o));
				}));

				for (o in objects3d)
					o.updateInstance(getContext(o));
			}
		}
		gizmo2d.onStartMove = function(mode) {
			var objects2d = [
				for (o in curEdit.rootElements) {
					var obj = o.to(hrt.prefab.Object2D);
					if (obj != null) obj;
				}
			];
			var sceneObjs = [for (o in objects2d) getContext(o).local2d];
			var pivot = getPivot2D(sceneObjs);
			var center = pivot.getCenter();
			var prevState = [for (o in objects2d) o.saveTransform()];
			var startPos = [for (o in sceneObjs) o.getAbsPos()];

			gizmo2d.onMove = function(t) {
				t.x = Math.round(t.x);
				t.y = Math.round(t.y);
				for (i in 0...sceneObjs.length) {
					var pos = startPos[i].clone();
					var obj = objects2d[i];
					switch (mode) {
						case Pan:
							pos.x += t.x;
							pos.y += t.y;
						case ScaleX, ScaleY, Scale:
							// no inherited rotation
							if (pos.b == 0 && pos.c == 0) {
								pos.x -= center.x;
								pos.y -= center.y;
								pos.x *= t.scaleX;
								pos.y *= t.scaleY;
								pos.x += center.x;
								pos.y += center.y;
								obj.scaleX = quantize(t.scaleX * prevState[i].scaleX, scaleQuant);
								obj.scaleY = quantize(t.scaleY * prevState[i].scaleY, scaleQuant);
							} else {
								var m2 = new h2d.col.Matrix();
								m2.initScale(t.scaleX, t.scaleY);
								pos.x -= center.x;
								pos.y -= center.y;
								pos.multiply(pos, m2);
								pos.x += center.x;
								pos.y += center.y;
								var s = pos.getScale();
								obj.scaleX = quantize(s.x, scaleQuant);
								obj.scaleY = quantize(s.y, scaleQuant);
							}
						case Rotation:
							pos.x -= center.x;
							pos.y -= center.y;
							var ca = Math.cos(t.rotation);
							var sa = Math.sin(t.rotation);
							var px = pos.x * ca - pos.y * sa;
							var py = pos.x * sa + pos.y * ca;
							pos.x = px + center.x;
							pos.y = py + center.y;
							var r = M.degToRad(prevState[i].rotation) + t.rotation;
							r = quantize(M.radToDeg(r), rotQuant);
							obj.rotation = r;
					}
					var pt = pos.getPosition();
					sceneObjs[i].parent.globalToLocal(pt);
					obj.x = quantize(pt.x, posQuant);
					obj.y = quantize(pt.y, posQuant);
					obj.applyTransform(sceneObjs[i]);
				}
			};
			gizmo2d.onFinishMove = function() {
				var newState = [for (o in objects2d) o.saveTransform()];
				refreshProps();
				undo.change(Custom(function(undo) {
					if (undo) {
						for (i in 0...objects2d.length) {
							objects2d[i].loadTransform(prevState[i]);
							objects2d[i].applyTransform(sceneObjs[i]);
						}
						refreshProps();
					} else {
						for (i in 0...objects2d.length) {
							objects2d[i].loadTransform(newState[i]);
							objects2d[i].applyTransform(sceneObjs[i]);
						}
						refreshProps();
					}
					for (o in objects2d)
						o.updateInstance(getContext(o));
				}));
				for (o in objects2d)
					o.updateInstance(getContext(o));
			};
		};
	}

	public function updateBasis() {
		if (basis == null)
			return;
		if (curEdit != null && curEdit.rootObjects.length == 1) {
			basis.visible = showBasis;
			var pos = getPivot(curEdit.rootObjects);
			basis.setPosition(pos.x, pos.y, pos.z);
			var obj = curEdit.rootObjects[0];
			var mat = worldMat(obj);
			var s = mat.getScale();

			if (s.x != 0 && s.y != 0 && s.z != 0) {
				mat.prependScale(1.0 / s.x, 1.0 / s.y, 1.0 / s.z);
				basis.getRotationQuat().initRotateMatrix(mat);
			}

			var cam = scene.s3d.camera;
			var gpos = gizmo.getAbsPos().getPosition();
			var distToCam = cam.pos.sub(gpos).length();
			var engine = h3d.Engine.getCurrent();
			var ratio = 150 / engine.height;

			var scale = ratio * distToCam * Math.tan(cam.fovY * 0.5 * Math.PI / 180.0);
			if (cam.orthoBounds != null) {
				scale = ratio * (cam.orthoBounds.xSize) * 0.5;
			}
			basis.setScale(scale);
		} else {
			basis.visible = false;
		}
	}

	function moveGizmoToSelection() {
		// Snap Gizmo at center of objects
		gizmo.getRotationQuat().identity();
		if (curEdit != null && curEdit.rootObjects.length > 0) {
			var pos = getPivot(curEdit.rootObjects);
			gizmo.visible = showGizmo;
			gizmo.setPosition(pos.x, pos.y, pos.z);

			if (curEdit.rootObjects.length == 1 && (localTransform || K.isDown(K.ALT) || gizmo.editMode == Scaling)) {
				var obj = curEdit.rootObjects[0];
				var mat = worldMat(obj);
				var s = mat.getScale();
				if (s.x != 0 && s.y != 0 && s.z != 0) {
					mat.prependScale(1.0 / s.x, 1.0 / s.y, 1.0 / s.z);
					gizmo.getRotationQuat().initRotateMatrix(mat);
				}
			}
		} else {
			gizmo.visible = false;
		}
		if (curEdit != null && curEdit.rootObjects2D.length > 0 && !gizmo.visible) {
			var pos = getPivot2D(curEdit.rootObjects2D);
			gizmo2d.visible = showGizmo;
			gizmo2d.setPosition(pos.getCenter().x, pos.getCenter().y);
			gizmo2d.setSize(pos.width, pos.height);
		} else {
			gizmo2d.visible = false;
		}
	}

	var inLassoMode = false;

	function startLassoSelect() {
		if (inLassoMode) {
			inLassoMode = false;
			return;
		}
		scene.setCurrent();
		inLassoMode = true;
		var g = new h2d.Object(scene.s2d);
		var overlay = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff, 10000, 10000, 0.1), g);
		var intOverlay = new h2d.Interactive(10000, 10000, scene.s2d);
		var lastPt = new h2d.col.Point(scene.s2d.mouseX, scene.s2d.mouseY);
		var points:h2d.col.Polygon = [lastPt];
		var polyG = new h2d.Graphics(g);
		event.waitUntil(function(dt) {
			var curPt = new h2d.col.Point(scene.s2d.mouseX, scene.s2d.mouseY);
			if (curPt.distance(lastPt) > 3.0) {
				points.push(curPt);
				polyG.clear();
				polyG.beginFill(0xff0000, 0.5);
				polyG.lineStyle(1.0, 0, 1.0);
				polyG.moveTo(points[0].x, points[0].y);
				for (i in 1...points.length) {
					polyG.lineTo(points[i].x, points[i].y);
				}
				polyG.endFill();
				lastPt = curPt;
			}

			var finish = false;
			if (!inLassoMode || K.isDown(K.ESCAPE) || K.isDown(K.MOUSE_RIGHT)) {
				finish = true;
			}

			if (K.isDown(K.MOUSE_LEFT)) {
				var contexts = context.shared.contexts;
				var all = getAllSelectable3D();
				var inside = [];
				for (elt in all) {
					if (elt.to(Object3D) == null)
						continue;
					var ctx = contexts[elt];
					if (ctx == null) // It appears that in edge cases the context linked to a prefab doesn't exist
						continue;
					var o = ctx.local3d;
					if (o == null || !o.visible)
						continue;
					var absPos = o.getAbsPos();
					var screenPos = worldToScreen(absPos.tx, absPos.ty, absPos.tz);
					if (points.contains(screenPos, false)) {
						inside.push(elt);
					}
				}
				selectElements(inside);
				finish = true;
			}

			if (finish) {
				intOverlay.remove();
				g.remove();
				inLassoMode = false;
				return true;
			}
			return false;
		});
	}

	public function setWireframe(val = true) {
		var engine = h3d.Engine.getCurrent();
		if (engine.driver.hasFeature(Wireframe)) {
			for (m in scene.s3d.getMaterials()) {
				m.mainPass.wireframe = val;
			}
		}
	}

	var jointsGraphics:h3d.scene.Graphics = null;

	@:access(h3d.scene.Skin)
	public function setJoints(showJoints = true, selectedJoint:String) {
		if (showJoints) {
			if (jointsGraphics == null) {
				jointsGraphics = new h3d.scene.Graphics(scene.s3d);
				jointsGraphics.material.mainPass.depth(false, Always);
				jointsGraphics.material.mainPass.setPassName("overlay");
			}
			jointsGraphics.clear();
			for (m in scene.s3d.getMeshes()) {
				var sk = Std.downcast(m, h3d.scene.Skin);
				if (sk != null) {
					if (selectedJoint != null) {
						var topParent:h3d.scene.Object = sk;
						while (topParent.parent != null)
							topParent = topParent.parent;
						jointsGraphics.follow = topParent;
						var skinData = sk.getSkinData();
						for (j in skinData.allJoints) {
							var m = sk.currentAbsPose[j.index];
							var mp = j.parent == null ? sk.absPos : sk.currentAbsPose[j.parent.index];
							if (j.name == selectedJoint) {
								jointsGraphics.lineStyle(1, 0x00FF00FF);
								jointsGraphics.moveTo(mp._41, mp._42, mp._43);
								jointsGraphics.lineTo(m._41, m._42, m._43);
							}
						}
					}
					sk.showJoints = true;
				}
			}
		} else if (jointsGraphics != null) {
			jointsGraphics.remove();
			jointsGraphics = null;
			for (m in scene.s3d.getMeshes()) {
				var sk = Std.downcast(m, h3d.scene.Skin);
				if (sk != null) {
					sk.showJoints = false;
				}
			}
		}
	}

	public function onPrefabChange(p:PrefabElement, ?pname:String) {
		var model = p.to(hrt.prefab.Model);
		if (model != null && pname == "source") {
			refreshScene();
			return;
		}

		if (p != sceneData) {
			var el = tree.getElement(p);
			if (el != null && el.toggleClass != null)
				applyTreeStyle(p, el, pname);
		}

		applySceneStyle(p);
	}

	public function applyTreeStyle(p:PrefabElement, el:Element, ?pname:String) {
		if (el == null)
			return;
		var obj3d = p.to(Object3D);
		el.toggleClass("disabled", !p.enabled);
		var aEl = el.find("a").first();
		var root = p.parent;
		while (root.parent != null)
			root = root.parent;
		el.toggleClass("inRef", root != sceneData);

		var tag = getTag(p);

		if (tag != null) {
			aEl.css("background", tag.color);
			el.find("ul").first().css("background", tag.color + "80");
		} else if (pname == "tag") {
			aEl.css("background", "");
			el.find("ul").first().css("background", "");
		}

		if (obj3d != null) {
			el.toggleClass("disabled", !p.enabled || !obj3d.visible);
			el.toggleClass("hidden", isHidden(obj3d));
			el.toggleClass("locked", p.locked);
			el.toggleClass("editorOnly", p.editorOnly);
			el.toggleClass("inGameOnly", p.inGameOnly);

			var anchor = el.find("a.jstree-anchor").first();
			if (anchor.length != 0) {
				if (anchor[0].childNodes[1] == null) {
					var textnode = js.Browser.document.createTextNode("");
					anchor[0].appendChild(textnode);
				}
				if (p is TorqueObject) {
					var to = cast(p, TorqueObject);
					if (to.customFieldProvider != null) {
						var db = hrt.mis.TorqueConfig.getDataBlock(to.customFieldProvider);
						anchor[0].childNodes[1].textContent = '${to.getEditorClassName()} - ${db != null ? db.name : "(unknown)"} - ${p.name}';
					} else {
						anchor[0].childNodes[1].textContent = '${to.getEditorClassName()} - ${p.name}';
					}
				}
				if (p is InteriorPath) {
					anchor[0].childNodes[1].textContent = 'Path - ${p.name}';
				}
				if (p is ScriptObject) {
					anchor[0].childNodes[1].textContent = 'ScriptObject" - ${p.name}';
				}
				if (p is SimGroup) {
					anchor[0].childNodes[1].textContent = 'SimGroup" - ${p.name}';
				}
			}

			var visTog = el.find(".visibility-toggle").first();
			if (visTog.length == 0) {
				visTog = new Element('<i class="ico ico-eye visibility-toggle" title = "Hide (${view.config.get("key.sceneeditor.hide")})"/>')
					.insertAfter(el.find("a.jstree-anchor")
					.first());
				visTog.click(function(e) {
					if (curEdit.elements.indexOf(obj3d) >= 0)
						setVisible(curEdit.elements, isHidden(obj3d));
					else
						setVisible([obj3d], isHidden(obj3d));

					e.preventDefault();
					e.stopPropagation();
				});
				visTog.dblclick(function(e) {
					e.preventDefault();
					e.stopPropagation();
				});
			}
			var lockTog = el.find(".lock-toggle").first();
			if (lockTog.length == 0) {
				lockTog = new Element('<i class="ico ico-lock lock-toggle"/>').insertAfter(el.find("a.jstree-anchor").first());
				lockTog.click(function(e) {
					if (curEdit.elements.indexOf(obj3d) >= 0)
						setLock(curEdit.elements, !obj3d.locked);
					else
						setLock([obj3d], !obj3d.locked);

					e.preventDefault();
					e.stopPropagation();
				});
				lockTog.dblclick(function(e) {
					e.preventDefault();
					e.stopPropagation();
				});
			}
			lockTog.css({visibility: p.locked ? "visible" : "hidden"});
		}
	}

	public function applySceneStyle(p:PrefabElement) {
		var obj3d = p.to(Object3D);
		if (obj3d != null) {
			var visible = obj3d.visible && !isHidden(obj3d);
			for (ctx in getContexts(obj3d)) {
				ctx.local3d.visible = visible;
			}
		}
	}

	public function getInteractives(elt:PrefabElement) {
		var r = [getInteractive(elt)];
		for (c in elt.children) {
			r = r.concat(getInteractives(c));
		}
		return r;
	}

	public function getInteractive(elt:PrefabElement) {
		return interactives.get(elt);
	}

	public function getContext(elt:PrefabElement, ?shared:hrt.prefab.ContextShared) {
		if (elt == null)
			return null;
		if (shared == null)
			shared = context.shared;
		var ctx = shared.contexts.get(elt);
		if (ctx == null) {
			for (r in @:privateAccess shared.refsContexts) {
				ctx = getContext(elt, r);
				if (ctx != null)
					break;
			}
		}
		if (ctx == null && elt == sceneData)
			ctx = context;
		return ctx;
	}

	public function getContexts(elt:PrefabElement) {
		if (elt == null)
			return null;
		return context.shared.getContexts(elt);
	}

	public function getObject(elt:PrefabElement) {
		var ctx = getContext(elt);
		if (ctx != null)
			return ctx.local3d;
		return context.shared.root3d;
	}

	public function getSelfObject(elt:PrefabElement) {
		var ctx = getContext(elt);
		var parentCtx = getContext(elt.parent);
		if (ctx == null || parentCtx == null)
			return null;
		if (ctx.local3d != parentCtx.local3d)
			return ctx.local3d;
		return null;
	}

	function removeInstance(elt:PrefabElement) {
		var result = true;
		var contexts = context.shared.contexts;
		function recRemove(e:PrefabElement) {
			for (c in e.children)
				recRemove(c);

			var int = interactives.get(e);
			if (int != null) {
				var i3d = Std.downcast(int, h3d.scene.Interactive);
				if (i3d != null)
					i3d.remove()
				else
					cast(int, h2d.Interactive).remove();
				interactives.remove(e);
			}
			for (ctx in getContexts(e)) {
				if (!e.removeInstance(ctx))
					result = false;
				contexts.remove(e);
			}
		}
		recRemove(elt);
		return result;
	}

	function makeInstance(elt:PrefabElement) {
		scene.setCurrent();
		var p = elt.parent;
		var parentCtx = null;
		while (p != null) {
			parentCtx = getContext(p);
			if (parentCtx != null)
				break;
			p = p.parent;
		}
		var ctx = elt.make(parentCtx);
		for (p in elt.flatten())
			makeInteractive(p, ctx.shared);
		scene.init(ctx.local3d);
	}

	function refreshParents(elts:Array<PrefabElement>) {
		var parents = new Map();
		for (e in elts) {
			if (e.parent == null)
				throw e + " is missing parent";
			parents.set(e.parent, true);
		}
		for (p in parents.keys()) {
			var h = p.getHideProps();
			if (h.onChildListChanged != null)
				h.onChildListChanged();
		}
		if (lastRenderProps != null && parents.exists(lastRenderProps))
			lastRenderProps.applyProps(scene.s3d.renderer);
	}

	public function addElements(elts:Array<PrefabElement>, selectObj:Bool = true, doRefresh:Bool = true, enableUndo = true) {
		for (e in elts) {
			makeInstance(e);
		}
		if (doRefresh) {
			refresh(Partial, if (selectObj) () -> selectElements(elts, NoHistory) else null);
			refreshParents(elts);
		}
		if (!enableUndo)
			return;

		undo.change(Custom(function(undo) {
			var fullRefresh = false;
			if (undo) {
				selectElements([], NoHistory);
				for (e in elts) {
					if (!removeInstance(e))
						fullRefresh = true;
					e.parent.children.remove(e);
				}
				refresh(fullRefresh ? Full : Partial);
			} else {
				for (e in elts) {
					e.parent.children.push(e);
					makeInstance(e);
				}
				refresh(Partial, () -> selectElements(elts, NoHistory));
				refreshParents(elts);
			}
		}));
	}

	function serializeProps(fields:Array<hide.comp.PropsEditor.PropsField>):String {
		var out = new Array<String>();
		for (field in fields) {
			@:privateAccess var accesses = field.getAccesses();
			for (a in accesses) {
				var v = Reflect.getProperty(a.obj, a.name);
				var json = haxe.Json.stringify(v);
				out.push('${a.name}:$json');
			}
		}
		return haxe.Json.stringify(out);
	}

	// Return true if unseialization was successfull
	function unserializeProps(fields:Array<hide.comp.PropsEditor.PropsField>, s:String):Bool {
		var data:Null<Array<Dynamic>> = null;
		try {
			data = cast(haxe.Json.parse(s), Array<Dynamic>);
		} catch (_) {}
		if (data != null) {
			var map = new Map<String, Dynamic>();
			for (field in data) {
				var field:String = cast field;
				var delimPos = field.indexOf(":");
				var fieldName = field.substr(0, delimPos);
				var fieldData = field.substr(delimPos + 1);

				var subdata:Dynamic = null;
				try {
					subdata = haxe.Json.parse(fieldData);
				} catch (_) {}

				if (subdata != null) {
					map.set(fieldName, subdata);
				}
			}

			for (field in fields) {
				@:privateAccess var accesses = field.getAccesses();
				for (a in accesses) {
					if (map.exists(a.name)) {
						Reflect.setProperty(a.obj, a.name, map.get(a.name));
						field.onChange(false);
					}
				}
			}

			return true;
		}
		return false;
	}

	function pasteFields(edit:SceneEditorContext, fields:Array<hide.comp.PropsEditor.PropsField>) {
		var pasteData = ide.getClipboard();
		var currentData = serializeProps(fields);
		var success = unserializeProps(fields, pasteData);
		if (success) {
			undo.change(Custom(function(undo) {
				if (undo) {
					unserializeProps(fields, currentData);
					edit.onChange(edit.elements[0], "props");
					edit.rebuildProperties();
				} else {
					unserializeProps(fields, pasteData);
					edit.onChange(edit.elements[0], "props");
					edit.rebuildProperties();
				}
			}));

			edit.onChange(edit.elements[0], "props");
			edit.rebuildProperties();
		}
	}

	function copyFields(fields:Array<hide.comp.PropsEditor.PropsField>) {
		ide.setClipboard(serializeProps(fields));
	}

	function fillProps(edit:SceneEditorContext, e:PrefabElement) {
		properties.element.append(new Element('<h1 class="prefab-name">${e.getHideProps().name}</h1>'));

		// var copyButton = new Element('<div class="hide-button" title="Copy all properties">').append(new Element('<div class="icon ico ico-copy">'));
		// copyButton.click(function(event:js.jquery.Event) {
		// 	copyFields(properties.fields);
		// });
		// properties.element.append(copyButton);

		// var pasteButton = new Element('<div class="hide-button" title="Paste values from the clipboard">')
		// 	.append(new Element('<div class="icon ico ico-paste">'));
		// pasteButton.click(function(event:js.jquery.Event) {
		// 	pasteFields(edit, properties.fields);
		// });
		// properties.element.append(pasteButton);

		e.edit(edit);

		var typeName = e.getCdbType();
		if (typeName == null && e.props != null)
			return; // don't allow CDB data with props already used !
	}

	public function addGroupCopyPaste(edit:SceneEditorContext) {
		for (groupName => groupFields in properties.groups) {
			var header = properties.element.find('.group[name="$groupName"]').find(".title");
			header.contextmenu(function(e) {
				e.preventDefault();
				new ContextMenu([
					{
						label: "Copy",
						click: function() {
							copyFields(groupFields);
						}
					},
					{
						label: "Paste",
						click: function() {
							pasteFields(edit, groupFields);
						}
					}
				]);
			});
		}
	}

	public function showProps(e:PrefabElement) {
		scene.setCurrent();
		var edit = makeEditContext([e]);
		properties.clear();
		fillProps(edit, e);
		addGroupCopyPaste(edit);
	}

	function setElementSelected(p:PrefabElement, ctx:hrt.prefab.Context, b:Bool) {
		return p.setSelected(ctx, b);
	}

	public function changeAllModels(source:hrt.prefab.Object3D, path:String) {
		var all = sceneData.flatten(hrt.prefab.Prefab);
		var oldPath = source.source;
		var changedModels = [];
		for (child in all) {
			var model = child.to(hrt.prefab.Object3D);
			if (model != null && model.source == oldPath) {
				model.source = path;
				model.name = "";
				autoName(model);
				changedModels.push(model);
			}
		}
		undo.change(Custom(function(u) {
			if (u) {
				for (model in changedModels) {
					model.source = oldPath;
					model.name = "";
					autoName(model);
				}
			} else {
				for (model in changedModels) {
					model.source = path;
					model.name = "";
					autoName(model);
				}
			}
			refresh();
		}));
		refresh();
	}

	public dynamic function onSelectionChanged(elts:Array<PrefabElement>, ?mode:SelectMode = Default) {};

	public function selectElements(elts:Array<PrefabElement>, ?mode:SelectMode = Default) {
		function impl(elts, mode:SelectMode) {
			scene.setCurrent();
			if (curEdit != null)
				curEdit.cleanup();
			var edit = makeEditContext(elts);
			if (elts.length == 0 || (customPivot != null && customPivot.elt != edit.rootElements[0])) {
				customPivot = null;
			}
			properties.clear();
			if (elts.length > 0) {
				fillProps(edit, elts[0]);
				addGroupCopyPaste(edit);
			}

			switch (mode) {
				case Default, NoHistory:
					tree.setSelection(elts);
				case Nothing, NoTree:
			}

			function getSelContext(e:PrefabElement) {
				var ectx = context.shared.contexts.get(e);
				if (ectx == null)
					ectx = context.shared.getContexts(e)[0];
				if (ectx == null)
					ectx = context;
				return ectx;
			}

			var map = new Map<PrefabElement, Bool>();
			function selectRec(e:PrefabElement, b:Bool) {
				if (map.exists(e))
					return;
				map.set(e, true);
				if (setElementSelected(e, getSelContext(e), b))
					for (e in e.children)
						selectRec(e, b);
			}

			for (e in elts)
				selectRec(e, true);

			edit.cleanups.push(function() {
				for (e in map.keys()) {
					if (hasBeenRemoved(e))
						continue;
					setElementSelected(e, getSelContext(e), false);
				}
			});

			curEdit = edit;
			showGizmo = false;
			for (e in elts)
				if (!isLocked(e)) {
					showGizmo = true;
					break;
				}
			setupGizmo();

			onSelectionChanged(elts, mode);
		}

		var prev:Array<PrefabElement> = null;
		if (curEdit != null && mode.match(Default | NoTree)) {
			prev = curEdit.rootElements.copy();
			undo.change(Custom(function(u) {
				if (u)
					impl(prev, NoHistory);
				else
					impl(elts, NoHistory);
			}), true);
		}

		impl(elts, mode);
	}

	function hasBeenRemoved(e:hrt.prefab.Prefab) {
		var root = sceneData;
		var eltCtx = context.shared.getContexts(e)[0];
		if (eltCtx != null && eltCtx.shared.parent != null) {
			if (hasBeenRemoved(eltCtx.shared.parent.prefab))
				return true;
			root = null;
		}
		while (e != null && e != root) {
			if (e.parent != null && e.parent.children.indexOf(e) < 0)
				return true;
			e = e.parent;
		}
		return e != root;
	}

	public function resetCamera(distanceFactor = 1.5) {
		if (camera2D) {
			cameraController2D.initFromScene();
		} else {
			scene.s3d.camera.zNear = scene.s3d.camera.zFar = 0;
			scene.s3d.camera.fovY = 25; // reset to default fov
			scene.resetCamera(distanceFactor);
			cameraController.lockZPlanes = scene.s3d.camera.zNear != 0;
			cameraController.loadFromCamera();
		}
	}

	public function getPickTransform(parent:PrefabElement) {
		var proj = screenToGround(scene.s2d.mouseX, scene.s2d.mouseY);
		if (proj == null)
			return null;

		var localMat = new h3d.Matrix();
		localMat.initTranslation(proj.x, proj.y, proj.z);

		if (parent == null)
			return localMat;

		var parentMat = worldMat(getObject(parent));
		parentMat.invert();

		localMat.multiply(localMat, parentMat);
		return localMat;
	}

	public function onDragDrop(items:Array<String>, isDrop:Bool) {
		var pickedEl = js.Browser.document.elementFromPoint(ide.mouseX, ide.mouseY);
		var propEl = properties.element[0];
		while (pickedEl != null) {
			if (pickedEl == propEl)
				return properties.onDragDrop(items, isDrop);
			pickedEl = pickedEl.parentElement;
		}

		var supported = @:privateAccess hrt.prefab.Library.registeredExtensions;
		var paths = [];
		for (path in items) {
			var ext = haxe.io.Path.extension(path).toLowerCase();
			if (StringTools.startsWith(path, "CREATE:") || supported.exists(ext) || ext == "fbx" || ext == "hmd" || ext == "json")
				paths.push(path);
		}
		if (paths.length == 0)
			return false;
		if (isDrop)
			dropElements(paths, sceneData);
		return true;
	}

	function createDroppedElement(path:String, parent:PrefabElement):Object3D {
		var obj3d:Object3D;

		var mi = parent.getPrefabByName("MissionGroup");
		if (mi == null)
			mi = parent;

		if (StringTools.startsWith(path, "CREATE:")) {
			var split = path.split(":");
			var classname = split[1];
			var datablock = split[2];
			var skin = split[3];
			var shapefile = split[4];

			var pmodel = hrt.prefab.Library.getRegistered().get(classname.toLowerCase());

			var p:hrt.prefab.l3d.DtsMesh = cast Type.createInstance(pmodel.cl, [mi]);
			@:privateAccess p.type = classname.toLowerCase();
			p.name = "";
			p.customFieldProvider = datablock.toLowerCase();
			p.path = StringTools.replace(StringTools.replace(shapefile.toLowerCase(), "marble/", ""), "platinum/", "");
			p.skin = skin == "" ? null : skin;

			var dbDef = hrt.mis.TorqueConfig.getDataBlock(datablock);

			p.customFields = hrt.mis.TorqueConfig.getDataBlock(datablock).fields.filter(x -> x.defaultValue != null).map(x -> {
				return {field: x.name.toLowerCase(), value: '${x.defaultValue}'};
			});
			if (dbDef.fieldMap.exists("skin") && p.skin != null && p.customFields.find(x -> x.field == "skin") == null)
				p.customFields.push({field: "skin", value: p.skin});

			var skinDef = p.customFields.find(x -> x.field == "skin");
			if (skinDef != null && p.skin != null && skinDef.value != p.skin)
				skinDef.value = p.skin;

			return p;
		}

		var relative = ide.makeRelative(path);

		var prefabType = hrt.prefab.Library.getPrefabType(path);
		if (prefabType == "interiorinstance") {
			var itr = new hrt.prefab.l3d.Interior(mi);
			itr.path = relative;
			obj3d = itr;
			obj3d.name = "";
		} else if (prefabType == 'tsstatic') {
			var ts = new hrt.prefab.l3d.TSStatic(mi);
			ts.path = relative;
			obj3d = ts;
			obj3d.name = "";
		} else if (prefabType != null) {
			var ref = new hrt.prefab.Reference(parent);
			ref.source = relative;
			obj3d = ref;
			obj3d.name = new haxe.io.Path(relative).file;
		} else {
			obj3d = new hrt.prefab.Model(parent);
			obj3d.source = relative;
		}

		@:privateAccess obj3d.type = prefabType;

		return obj3d;
	}

	function dropElements(paths:Array<String>, parent:PrefabElement) {
		scene.setCurrent();
		var localMat = h3d.Matrix.I();
		// if (scene.hasFocus()) {
		localMat = getPickTransform(parent);
		if (localMat == null)
			return;

		localMat.tx = hxd.Math.round(localMat.tx * 10) / 10;
		localMat.ty = hxd.Math.round(localMat.ty * 10) / 10;
		localMat.tz = hxd.Math.floor(localMat.tz * 10) / 10;
		// }

		var elts:Array<PrefabElement> = [];
		for (path in paths) {
			var obj3d = createDroppedElement(path, parent);
			obj3d.setTransform(localMat);
			// autoName(obj3d);
			elts.push(obj3d);
		}

		for (e in elts)
			makeInstance(e);
		refresh(Partial, () -> selectElements(elts));

		undo.change(Custom(function(undo) {
			if (undo) {
				var fullRefresh = false;
				for (e in elts) {
					if (!removeInstance(e))
						fullRefresh = true;
					parent.children.remove(e);
				}
				refresh(fullRefresh ? Full : Partial);
			} else {
				for (e in elts) {
					parent.children.push(e);
					makeInstance(e);
				}
				refresh(Partial);
			}
		}));
	}

	function gatherToMouse() {
		var prevParent = sceneData;
		var localMat = getPickTransform(prevParent);
		if (localMat == null)
			return;

		var objects3d = [
			for (o in curEdit.rootElements) {
				var obj3d = o.to(hrt.prefab.Object3D);
				if (obj3d != null && !obj3d.locked) obj3d;
			}
		];
		if (objects3d.length == 0)
			return;

		var sceneObjs = [for (o in objects3d) getContext(o).local3d];
		var prevState = [for (o in objects3d) o.saveTransform()];

		for (obj3d in objects3d) {
			if (obj3d.parent != prevParent) {
				prevParent = obj3d.parent;
				localMat = getPickTransform(prevParent);
			}
			if (localMat == null)
				continue;
			obj3d.x = hxd.Math.round(localMat.tx * 10) / 10;
			obj3d.y = hxd.Math.round(localMat.ty * 10) / 10;
			obj3d.z = hxd.Math.floor(localMat.tz * 10) / 10;
			obj3d.updateInstance(getContext(obj3d));
		}
		var newState = [for (o in objects3d) o.saveTransform()];
		refreshProps();
		undo.change(Custom(function(undo) {
			if (undo) {
				for (i in 0...objects3d.length) {
					objects3d[i].loadTransform(prevState[i]);
					objects3d[i].applyTransform(sceneObjs[i]);
				}
				refreshProps();
			} else {
				for (i in 0...objects3d.length) {
					objects3d[i].loadTransform(newState[i]);
					objects3d[i].applyTransform(sceneObjs[i]);
				}
				refreshProps();
			}
			for (o in objects3d)
				o.updateInstance(getContext(o));
		}));
	}

	function dropToGround() {
		var prevParent = sceneData;

		var objects3d = [
			for (o in curEdit.rootElements) {
				var obj3d = o.to(hrt.prefab.Object3D);
				if (obj3d != null && !obj3d.locked) obj3d;
			}
		];
		if (objects3d.length == 0)
			return;

		var sceneObjs = [for (o in objects3d) getContext(o).local3d];
		var prevState = [for (o in objects3d) o.saveTransform()];

		for (obj3d in objects3d) {
			var objlocal = getContext(obj3d).local3d;
			var rayStartPos = objlocal.getAbsPos().getPosition();
			var rayEndPos = rayStartPos.add(new Vector(0, 0, -100));
			var ray = h3d.col.Ray.fromPoints(rayStartPos.toPoint(), rayEndPos.toPoint());

			var rayT = projectToGround(ray);
			if (rayT < 0)
				continue;
			var pos = ray.getPoint(rayT);

			var invT = objlocal.parent.getInvPos();
			pos.transform(invT);

			obj3d.x = pos.x;
			obj3d.y = pos.y;
			obj3d.z = pos.z;
			obj3d.updateInstance(getContext(obj3d));
		}
		var newState = [for (o in objects3d) o.saveTransform()];
		refreshProps();
		undo.change(Custom(function(undo) {
			if (undo) {
				for (i in 0...objects3d.length) {
					objects3d[i].loadTransform(prevState[i]);
					objects3d[i].applyTransform(sceneObjs[i]);
				}
				refreshProps();
			} else {
				for (i in 0...objects3d.length) {
					objects3d[i].loadTransform(newState[i]);
					objects3d[i].applyTransform(sceneObjs[i]);
				}
				refreshProps();
			}
			for (o in objects3d)
				o.updateInstance(getContext(o));
		}));
	}

	function canGroupSelection() {
		var elts = curEdit.rootElements;
		if (elts.length == 0)
			return false;

		if (elts.length == 1)
			return true;

		// Only allow grouping of sibling elements
		var parent = elts[0].parent;
		for (e in elts)
			if (e.parent != parent)
				return false;

		return true;
	}

	function groupSelection() {
		if (!canGroupSelection())
			return;

		var elts = curEdit.rootElements;

		var group = new hrt.prefab.l3d.SimGroup(sceneData.getPrefabByName("MissionGroup"));
		group.name = "SimGroup";
		var sceneCtx = getContext(sceneData.getPrefabByName("MissionGroup"));
		group.make(sceneCtx);
		var groupCtx = getContext(group);

		for (prefab in elts) {
			prefab.parent = group;
		}

		// var effectFunc = reparentImpl(elts, group, 0);
		undo.change(Custom(function(undo) {
			if (undo) {
				group.parent = null;
				context.shared.contexts.remove(group);
				// effectFunc(true);
			} else {
				group.parent = sceneData.getPrefabByName("MissionGroup");
				context.shared.contexts.set(group, groupCtx);
				// effectFunc(false);
			}
			if (undo)
				refresh(() -> selectElements([], NoHistory));
			else
				refresh(() -> selectElements([group], NoHistory));
		}));
		refresh(Partial, () -> selectElements([group], NoHistory));
	}

	function onCopy() {
		if (curEdit == null)
			return;
		if (curEdit.rootElements.length == 1) {
			var prefab = curEdit.rootElements[0];
			view.setClipboard(prefab.saveData(), "prefab", {source: view.state.path, name: prefab.name});
		} else {
			var lib = new hrt.prefab.Library();
			for (e in curEdit.rootElements) {
				lib.children.push(e);
			}
			view.setClipboard(lib.saveData(), "library");
		}
	}

	function getDataPath(prefabName:String, ?sourceFile:String) {
		if (sourceFile == null)
			sourceFile = view.state.path;
		var datPath = new haxe.io.Path(sourceFile);
		datPath.ext = "dat";
		return ide.getPath(datPath.toString() + "/" + prefabName);
	}

	function onPaste() {
		var parent:PrefabElement = sceneData.getPrefabByName("MissionGroup");
		var opts:{ref:{source:String, name:String}} = {ref: null};
		var obj = view.getClipboard("prefab", opts);
		if (obj != null) {
			var p = hrt.prefab.Prefab.loadPrefab(obj, parent);
			autoName(p);

			if (opts.ref != null && opts.ref.source != null && opts.ref.name != null) {
				// copy data
				var srcDir = getDataPath(opts.ref.name, opts.ref.source);
				if (sys.FileSystem.exists(srcDir) && sys.FileSystem.isDirectory(srcDir)) {
					var dstDir = getDataPath(p.name);
					function copyRec(src:String, dst:String) {
						if (!sys.FileSystem.exists(dst))
							sys.FileSystem.createDirectory(dst);
						for (f in sys.FileSystem.readDirectory(src)) {
							var file = src + "/" + f;
							if (sys.FileSystem.isDirectory(file)) {
								copyRec(file, dst + "/" + f);
								continue;
							}
							sys.io.File.copy(file, dst + "/" + f);
						}
					}
					copyRec(srcDir, dstDir);
				}
			}

			addElements([p]);
		} else {
			obj = view.getClipboard("library");
			if (obj != null) {
				var lib = hrt.prefab.Prefab.loadPrefab(obj);
				for (c in lib.children) {
					autoName(c);
					parent.children.push(c);
				}
				addElements(lib.children);
			}
		}
	}

	public function isVisible(elt:PrefabElement) {
		if (elt == sceneData)
			return true;
		var o = elt.to(Object3D);
		if (o == null)
			return true;
		return o.visible && !isHidden(o) && (elt.parent != null ? isVisible(elt.parent) : true);
	}

	public function getAllSelectable3D():Array<PrefabElement> {
		var ret = [];
		for (elt in interactives.keys()) {
			var i = interactives.get(elt);
			var p:h3d.scene.Object = Std.downcast(i, h3d.scene.Interactive);
			if (p == null)
				continue;
			while (p != null && p.visible)
				p = p.parent;
			if (p != null)
				continue;
			ret.push(elt);
		}
		return ret;
	}

	public function selectAll() {
		selectElements(getAllSelectable3D());
	}

	public function deselect() {
		selectElements([]);
	}

	public function isSelected(p:PrefabElement) {
		return curEdit != null && curEdit.elements.indexOf(p) >= 0;
	}

	public function setEnabled(elements:Array<PrefabElement>, enable:Bool) {
		var old = [for (e in elements) e.enabled];
		function apply(on) {
			for (i in 0...elements.length) {
				elements[i].enabled = on ? enable : old[i];
				onPrefabChange(elements[i]);
			}
			refreshScene();
		}
		apply(true);
		undo.change(Custom(function(undo) {
			if (undo)
				apply(false);
			else
				apply(true);
		}));
	}

	public function setEditorOnly(elements:Array<PrefabElement>, enable:Bool) {
		var old = [for (e in elements) e.editorOnly];
		function apply(on) {
			for (i in 0...elements.length) {
				elements[i].editorOnly = on ? enable : old[i];
				onPrefabChange(elements[i]);
			}
			refreshScene();
		}
		apply(true);
		undo.change(Custom(function(undo) {
			if (undo)
				apply(false);
			else
				apply(true);
		}));
	}

	public function setInGameOnly(elements:Array<PrefabElement>, enable:Bool) {
		var old = [for (e in elements) e.inGameOnly];
		function apply(on) {
			for (i in 0...elements.length) {
				elements[i].inGameOnly = on ? enable : old[i];
				onPrefabChange(elements[i]);
			}
			refreshScene();
		}
		apply(true);
		undo.change(Custom(function(undo) {
			if (undo)
				apply(false);
			else
				apply(true);
		}));
	}

	public function isHidden(e:PrefabElement) {
		if (e == null)
			return false;
		return hideList.exists(e);
	}

	public function isLocked(e:PrefabElement) {
		while (e != null) {
			if (e.locked)
				return true;
			e = e.parent;
		}
		return false;
	}

	function saveDisplayState() {
		var state = [for (h in hideList.keys()) h.getAbsPath(true)];
		@:privateAccess view.saveDisplayState("hideList", state);
	}

	public function setVisible(elements:Array<PrefabElement>, visible:Bool) {
		for (o in elements) {
			for (c in o.flatten(Object3D)) {
				if (visible)
					hideList.remove(c);
				else
					hideList.set(o, true);
				var el = tree.getElement(c);
				if (el != null)
					applyTreeStyle(c, el);
				applySceneStyle(c);
			}
		}
		saveDisplayState();
	}

	public function setLock(elements:Array<PrefabElement>, locked:Bool, enableUndo:Bool = true) {
		var prev = [for (o in elements) o.locked];
		for (o in elements) {
			o.locked = locked;
			for (c in o.flatten(hrt.prefab.Prefab)) {
				var el = tree.getElement(c);
				applyTreeStyle(c, el);
				applySceneStyle(c);
				toggleInteractive(c, !isLocked(c));
			}
		}
		if (enableUndo) {
			undo.change(Custom(function(redo) {
				for (i in 0...elements.length)
					elements[i].locked = redo ? locked : prev[i];
			}), function() {
				tree.refresh();
				refreshScene();
			});
		}

		saveDisplayState();
		showGizmo = !locked;
		moveGizmoToSelection();
	}

	function isolate(elts:Array<PrefabElement>) {
		var toShow = elts.copy();
		var toHide = [];
		function hideSiblings(elt:PrefabElement) {
			var p = elt.parent;
			for (c in p.children) {
				var needsVisible = c == elt || toShow.indexOf(c) >= 0 || hasChild(c, toShow);
				if (!needsVisible) {
					toHide.push(c);
				}
			}
			if (p != sceneData) {
				hideSiblings(p);
			}
		}
		for (e in toShow) {
			hideSiblings(e);
		}
		setVisible(toHide, false);
	}

	var isDuplicating = false;

	function duplicate(thenMove:Bool) {
		if (curEdit == null)
			return;
		var elements = curEdit.rootElements;
		if (elements == null || elements.length == 0)
			return;
		if (isDuplicating)
			return;
		isDuplicating = true;
		if (gizmo.moving) {
			@:privateAccess gizmo.finishMove();
		}
		var undoes = [];
		var newElements = [];
		var lastElem = elements[elements.length - 1];
		var lastIndex = lastElem.parent.children.indexOf(lastElem) + 1;
		for (elt in elements) {
			var clone = elt.cloneData();
			var index = lastIndex;
			lastIndex += 1;
			clone.parent = elt.parent;
			elt.parent.children.remove(clone);
			elt.parent.children.insert(index, clone);
			autoName(clone);
			makeInstance(clone);
			newElements.push(clone);

			undoes.push(function(undo) {
				if (undo)
					elt.parent.children.remove(clone);
				else
					elt.parent.children.insert(index, clone);
			});
		}

		refreshTree(function() {
			selectElements(newElements);
			tree.setSelection(newElements);
			if (thenMove && curEdit.rootObjects.length > 0) {
				gizmo.startMove(MoveXY, true);
				gizmo.onFinishMove = function() {
					refreshProps();
				}
			}
			isDuplicating = false;
		});
		gizmo.translationMode();

		undo.change(Custom(function(undo) {
			selectElements([], NoHistory);

			var fullRefresh = false;
			if (undo) {
				for (elt in newElements) {
					if (!removeInstance(elt)) {
						fullRefresh = true;
						break;
					}
				}
			}

			for (u in undoes)
				u(undo);

			if (!undo) {
				for (elt in newElements)
					makeInstance(elt);
			}

			refresh(fullRefresh ? Full : Partial);
		}));
	}

	function setTransform(elt:PrefabElement, ?mat:h3d.Matrix, ?position:h3d.Vector) {
		var obj3d = Std.downcast(elt, hrt.prefab.Object3D);
		if (obj3d == null)
			return;
		if (mat != null)
			obj3d.setTransform(mat);
		else {
			obj3d.x = position.x;
			obj3d.y = position.y;
			obj3d.z = position.z;
		}
		var ctx = getContext(obj3d);
		if (ctx != null)
			obj3d.updateInstance(ctx);
	}

	public function deleteElements(elts:Array<PrefabElement>, ?then:Void->Void, doRefresh:Bool = true, enableUndo:Bool = true) {
		var fullRefresh = false;
		var undoes = [];
		for (elt in elts) {
			if (!removeInstance(elt))
				fullRefresh = true;
			var index = elt.parent.children.indexOf(elt);
			elt.parent.children.remove(elt);
			undoes.unshift(function(undo) {
				if (undo)
					elt.parent.children.insert(index, elt);
				else
					elt.parent.children.remove(elt);
			});
		}

		function refreshFunc(then) {
			refresh(fullRefresh ? Full : Partial, then);
			if (!fullRefresh)
				refreshParents(elts);
		}

		if (doRefresh)
			refreshFunc(then != null ? then : () -> selectElements([], NoHistory));

		if (enableUndo) {
			undo.change(Custom(function(undo) {
				if (!undo && !fullRefresh)
					for (e in elts)
						removeInstance(e);

				for (u in undoes)
					u(undo);

				if (undo)
					for (e in elts)
						makeInstance(e);

				refreshFunc(then != null ? then : selectElements.bind(undo ? elts : [], NoHistory));
			}));
		}
	}

	function reparentElement(e:Array<PrefabElement>, to:PrefabElement, index:Int) {
		if (to == null)
			to = sceneData;

		var ref = Std.downcast(to, Reference);
		@:privateAccess if (ref != null && ref.editMode)
			to = ref.ref;

		var effectFunc = reparentImpl(e, to, index);
		undo.change(Custom(function(undo) {
			refresh(effectFunc(undo) ? Full : Partial);
		}));
		refresh(effectFunc(false) ? Full : Partial);
	}

	function makeTransform(mat:h3d.Matrix) {
		var q = new h3d.Quat();
		q.initRotateMatrix(mat);
		var rot = mat.getEulerAngles();
		var x = mat.tx;
		var y = mat.ty;
		var z = mat.tz;
		var s = mat.getScale();
		var scaleX = s.x;
		var scaleY = s.y;
		var scaleZ = s.z;
		return {
			x: x,
			y: y,
			z: z,
			scaleX: scaleX,
			scaleY: scaleY,
			scaleZ: scaleZ,
			rotationX: q.x,
			rotationY: q.y,
			rotationZ: q.z,
			rotationW: q.w
		};
	}

	function reparentImpl(elts:Array<PrefabElement>, toElt:PrefabElement, index:Int):Bool->Bool {
		var effects = [];
		var fullRefresh = false;
		var toRefresh:Array<PrefabElement> = null;
		for (elt in elts) {
			var prev = elt.parent;
			var prevIndex = prev.children.indexOf(elt);

			var obj3d = elt.to(Object3D);
			var preserveTransform = false;
			var toObj = getObject(toElt);
			var obj = getObject(elt);
			var prevState = null, newState = null;
			if (obj3d != null && toObj != null && obj != null && !preserveTransform) {
				var mat = worldMat(obj);
				var parentMat = worldMat(toObj);
				parentMat.invert();
				mat.multiply(mat, parentMat);
				prevState = obj3d.saveTransform();
				newState = makeTransform(mat);
			}

			effects.push(function(undo) {
				if (undo) {
					!removeInstance(elt);
					elt.parent = prev;
					prev.children.remove(elt);
					prev.children.insert(prevIndex, elt);
					if (obj3d != null && prevState != null)
						obj3d.loadTransform(prevState);
				} else {
					!removeInstance(elt);
					elt.parent = toElt;
					toElt.children.remove(elt);
					toElt.children.insert(index, elt);
					if (obj3d != null && newState != null)
						obj3d.loadTransform(newState);
				};
				toRefresh.pushUnique(elt);
				toRefresh.pushUnique(toElt);
				return true;
			});
		}
		return function(undo) {
			var refresh = false;
			toRefresh = [];
			for (f in effects) {
				if (f(undo))
					refresh = true;
			}
			if (!refresh) {
				for (elt in toRefresh) {
					removeInstance(elt);
					makeInstance(elt);
				}
			}
			return refresh;
		}
	}

	function autoName(p:PrefabElement) {
		var uniqueName = false;
		if (p.type == "volumetricLightmap" || p.type == "light")
			uniqueName = true;

		if (!uniqueName && sys.FileSystem.exists(getDataPath(p.name)))
			uniqueName = true;

		var prefix = null;
		if (p.name != null && p.name.length > 0) {
			if (uniqueName)
				prefix = ~/_+[0-9]+$/.replace(p.name, "");
			else
				prefix = p.name;
		} else
			prefix = p.getDefaultName();

		if (uniqueName) {
			prefix += "_";
			var id = 0;
			while (sceneData.getPrefabByName(prefix + id) != null)
				id++;

			p.name = prefix + id;
		} else
			p.name = prefix;

		for (c in p.children) {
			autoName(c);
		}
	}

	function update(dt:Float) {
		saveCam3D();

		@:privateAccess view.saveDisplayState("Camera2D",
			{x: context.shared.root2d.x - scene.s2d.width * 0.5, y: context.shared.root2d.y - scene.s2d.height * 0.5, z: context.shared.root2d.scaleX});
		if (gizmo != null) {
			if (!gizmo.moving) {
				moveGizmoToSelection();
			}
			gizmo.update(dt, localTransform);
		}
		updateBasis();
		event.update(dt);
		for (f in updates)
			f(dt);
		onUpdate(dt);
	}

	public dynamic function onUpdate(dt:Float) {}

	// Override
	function makeEditContext(elts:Array<PrefabElement>):SceneEditorContext {
		var p = elts[0];
		var rootCtx = context;
		while (p != null) {
			var ctx = context.shared.getContexts(p)[0];
			if (ctx != null)
				rootCtx = ctx;
			p = p.parent;
		}
		// rootCtx might not be == context depending on references
		var edit = new SceneEditorContext(rootCtx, elts, this);
		edit.properties = properties;
		edit.scene = scene;
		return edit;
	}

	function getNewRecentContextMenu(current, ?onMake:PrefabElement->Void = null):Array<hide.comp.ContextMenu.ContextMenuItem> {
		var parent = current == null ? sceneData : current;
		var grecent = [];
		var recents:Array<String> = ide.currentConfig.get("sceneeditor.newrecents", []);
		for (g in recents) {
			var pmodel = hrt.prefab.Library.getRegistered().get(g);
			if (pmodel != null && checkAllowParent({cl: g, inf: pmodel.inf}, parent))
				grecent.push(getNewTypeMenuItem(g, parent, onMake));
		}
		return grecent;
	}

	// Override
	function getNewContextMenu(current:PrefabElement, ?onMake:PrefabElement->Void = null, ?groupByType = true):Array<hide.comp.ContextMenu.ContextMenuItem> {
		var newItems = new Array<hide.comp.ContextMenu.ContextMenuItem>();
		var allRegs = hrt.prefab.Library.getRegistered().copy();
		allRegs.remove("reference");
		allRegs.remove("unknown");
		var parent = current == null ? sceneData : current;

		var groups = [];
		var gother = [];

		for (g in (view.config.get("sceneeditor.newgroups") : Array<String>)) {
			var parts = g.split("|");
			var cl:Dynamic = Type.resolveClass(parts[1]);
			if (cl == null)
				continue;
			groups.push({
				label: parts[0],
				cl: cl,
				group: [],
			});
		}
		for (ptype in allRegs.keys()) {
			var pinf = allRegs.get(ptype);
			if (ptype == "UiDisplay")
				trace("break");

			if (!checkAllowParent({cl: ptype, inf: pinf.inf}, parent))
				continue;
			if (ptype == "shader") {
				newItems.push(getNewShaderMenu(parent, onMake));
				continue;
			}

			var m = getNewTypeMenuItem(ptype, parent, onMake);
			if (!groupByType)
				newItems.push(m);
			else {
				var found = false;
				for (g in groups)
					if (hrt.prefab.Library.isOfType(ptype, g.cl)) {
						g.group.push(m);
						found = true;
						break;
					}
				if (!found)
					gother.push(m);
			}
		}
		function sortByLabel(arr:Array<hide.comp.ContextMenu.ContextMenuItem>) {
			arr.sort(function(l1, l2) return Reflect.compare(l1.label, l2.label));
		}
		for (g in groups)
			if (g.group.length > 0) {
				sortByLabel(g.group);
				newItems.push({label: g.label, menu: g.group});
			}
		sortByLabel(gother);
		sortByLabel(newItems);
		if (gother.length > 0) {
			if (newItems.length == 0)
				return gother;
			newItems.push({label: "Other", menu: gother});
		}

		return newItems;
	}

	function getNewTypeMenuItem(ptype:String, parent:PrefabElement, onMake:PrefabElement->Void, ?label:String, ?objectName:String,
			?path:String):hide.comp.ContextMenu.ContextMenuItem {
		var pmodel = hrt.prefab.Library.getRegistered().get(ptype);
		return {
			label: label != null ? label : pmodel.inf.name,
			click: function() {
				function make(?sourcePath) {
					if (ptype == "UiDisplay")
						trace("Break");
					var p = Type.createInstance(pmodel.cl, [parent]);
					@:privateAccess p.type = ptype;
					if (sourcePath != null)
						p.source = sourcePath;
					if (objectName != null)
						p.name = objectName;
					else
						autoName(p);
					if (onMake != null)
						onMake(p);
					var recents:Array<String> = ide.currentConfig.get("sceneeditor.newrecents", []);
					recents.remove(p.type);
					recents.unshift(p.type);
					var recentSize:Int = view.config.get("sceneeditor.recentsize");
					if (recents.length > recentSize)
						recents.splice(recentSize, recents.length - recentSize);
					ide.currentConfig.set("sceneeditor.newrecents", recents);
					return p;
				}

				if (pmodel.inf.fileSource != null) {
					if (path != null) {
						var p = make(path);
						addElements([p]);
						var recents:Array<String> = ide.currentConfig.get("sceneeditor.newrecents", []);
						recents.remove(p.type);
					} else {
						ide.chooseFile(pmodel.inf.fileSource, function(path) {
							addElements([make(path)]);
						});
					}
				} else
					addElements([make()]);
			},
			icon: pmodel.inf.icon,
		};
	}

	static var globalShaders:Array<Class<hxsl.Shader>> = [
		hrt.shader.DissolveBurn,
		hrt.shader.Bloom,
		hrt.shader.UVDebug,
		hrt.shader.GradientMap,
		hrt.shader.HeightGradient,
		hrt.shader.ParticleFade,
		hrt.shader.ParticleColorLife,
		hrt.shader.ParticleColorRandom,
		hrt.shader.MaskColorAlpha,
		hrt.shader.Spinner,
		hrt.shader.MeshWave,
		hrt.shader.TextureRotate,
		hrt.shader.GradientMapLife,
	];

	function getNewShaderMenu(parentElt:PrefabElement, ?onMake:PrefabElement->Void):hide.comp.ContextMenu.ContextMenuItem {
		function isClassShader(path:String) {
			return Type.resolveClass(path) != null || StringTools.endsWith(path, ".hx");
		}

		var shModel = hrt.prefab.Library.getRegistered().get("shader");
		var graphModel = hrt.prefab.Library.getRegistered().get("shgraph");
		var custom = {
			label: "Custom...",
			click: function() {
				ide.chooseFile(shModel.inf.fileSource.concat(graphModel.inf.fileSource), function(path) {
					var cl = isClassShader(path) ? shModel.cl : graphModel.cl;
					var p = Type.createInstance(cl, [parentElt]);
					p.source = path;
					autoName(p);
					if (onMake != null)
						onMake(p);
					addElements([p]);
				});
			},
			icon: shModel.inf.icon,
		};

		function classShaderItem(path):hide.comp.ContextMenu.ContextMenuItem {
			var name = path;
			if (StringTools.endsWith(name, ".hx")) {
				name = new haxe.io.Path(path).file;
			} else {
				name = name.split(".").pop();
			}
			return getNewTypeMenuItem("shader", parentElt, onMake, name, name, path);
		}

		function graphShaderItem(path):hide.comp.ContextMenu.ContextMenuItem {
			var name = new haxe.io.Path(path).file;
			return getNewTypeMenuItem("shgraph", parentElt, onMake, name, name, path);
		}

		var menu:Array<hide.comp.ContextMenu.ContextMenuItem> = [];

		var shaders:Array<String> = hide.Ide.inst.currentConfig.get("fx.shaders", []);
		for (sh in globalShaders) {
			var name = Type.getClassName(sh);
			if (!shaders.contains(name)) {
				shaders.push(name);
			}
		}

		for (path in shaders) {
			var strippedSlash = StringTools.endsWith(path, "/") ? path.substr(0, -1) : path;
			var fullPath = ide.getPath(strippedSlash);
			if (isClassShader(path)) {
				menu.push(classShaderItem(path));
			} else if (StringTools.endsWith(path, ".shgraph")) {
				menu.push(graphShaderItem(path));
			} else if (sys.FileSystem.exists(fullPath) && sys.FileSystem.isDirectory(fullPath)) {
				for (c in sys.FileSystem.readDirectory(fullPath)) {
					var relPath = ide.makeRelative(fullPath + "/" + c);
					if (isClassShader(relPath)) {
						menu.push(classShaderItem(relPath));
					} else if (StringTools.endsWith(relPath, ".shgraph")) {
						menu.push(graphShaderItem(relPath));
					}
				}
			}
		}

		menu.sort(function(l1, l2) return Reflect.compare(l1.label, l2.label));
		menu.unshift(custom);

		return {
			label: "Shader",
			menu: menu
		};
	}

	public function getZ(x:Float, y:Float, ?paintOn:hrt.prefab.Prefab) {
		var offset = 1000000;
		var ray = h3d.col.Ray.fromValues(x, y, offset, 0, 0, -1);
		var dist = projectToGround(ray, paintOn);
		if (dist >= 0) {
			return offset - dist;
		}
		return 0.;
	}

	var groundPrefabsCache:Array<PrefabElement> = null;
	var groundPrefabsCacheTime:Float = -1e9;

	function getGroundPrefabs():Array<PrefabElement> {
		var now = haxe.Timer.stamp();
		if (now - groundPrefabsCacheTime > 5) {
			function getAll(data:PrefabElement) {
				var all = data.findAll((p) -> p);
				for (a in all.copy()) {
					var r = Std.downcast(a, hrt.prefab.Reference);
					if (r != null) {
						var sub = @:privateAccess r.ref;
						if (sub != null)
							all = all.concat(getAll(sub));
					}
				}
				return all;
			}
			var all = getAll(sceneData);
			var grounds = [
				for (p in all)
					if (p.getHideProps().isGround || (p.name != null && p.name.toLowerCase() == "ground")) p
			];
			var results = [];
			for (g in grounds)
				results = results.concat(getAll(g));
			groundPrefabsCache = results;
			groundPrefabsCacheTime = now;
		}
		return groundPrefabsCache.copy();
	}

	public function projectToGround(ray:h3d.col.Ray, ?paintOn:hrt.prefab.Prefab) {
		var minDist = -1.;

		var saveR = ray.clone();

		var selectablePrefabs = getAllSelectable3D();
		for (s in selectablePrefabs) {
			var int:h3d.scene.Interactive = cast getInteractive(s);
			if (int != null && int.preciseShape != null) {
				var intPar = int.parent; // Cause we messed up
				var m = @:privateAccess intPar.invPos;

				ray.transform(m);
				var hit = int.preciseShape.rayIntersection(ray, true);
				if (hit > 0) {
					var pt = ray.getPoint(hit);
					pt.transform(int.getAbsPos());
					var dist = pt.sub(ray.getPos()).length();
					if (minDist < 0 || dist < minDist)
						minDist = dist;
				}
				ray.load(saveR);
			}
		}

		for (elt in (paintOn == null ? getGroundPrefabs() : [paintOn])) {
			var obj = Std.downcast(elt, Object3D);
			if (obj == null)
				continue;
			var ctx = getContext(elt);
			if (ctx == null)
				continue;

			var lray = ray.clone();
			lray.transform(ctx.local3d.getInvPos());
			var dist = obj.localRayIntersection(ctx, lray);
			if (dist > 0) {
				var pt = lray.getPoint(dist);
				pt.transform(ctx.local3d.getAbsPos());
				var dist = pt.sub(ray.getPos()).length();
				if (minDist < 0 || dist < minDist)
					minDist = dist;
			}
		}
		if (minDist >= 0)
			return minDist;

		var zPlane = h3d.col.Plane.Z(0);
		var pt = ray.intersect(zPlane);
		if (pt != null) {
			minDist = pt.sub(ray.getPos()).length();
			var dirToPt = pt.sub(ray.getPos());
			if (dirToPt.dot(ray.getDir()) < 0)
				return -1;
		}

		return minDist;
	}

	public function screenDistToGround(sx:Float, sy:Float, ?paintOn:hrt.prefab.Prefab):Null<Float> {
		var camera = scene.s3d.camera;
		var ray = camera.rayFromScreen(sx, sy);
		var dist = projectToGround(ray, paintOn);
		if (dist >= 0)
			return dist + camera.zNear;
		return null;
	}

	public function screenToGround(sx:Float, sy:Float, ?paintOn:hrt.prefab.Prefab) {
		var camera = scene.s3d.camera;
		var ray = camera.rayFromScreen(sx, sy);
		var dist = projectToGround(ray, paintOn);
		if (dist >= 0) {
			return ray.getPoint(dist);
		}
		return null;
	}

	public function worldToScreen(wx:Float, wy:Float, wz:Float) {
		var camera = scene.s3d.camera;
		var pt = camera.project(wx, wy, wz, scene.s2d.width, scene.s2d.height);
		return new h2d.col.Point(pt.x, pt.y);
	}

	public function worldMat(?obj:Object, ?elt:PrefabElement) {
		if (obj != null) {
			if (obj.defaultTransform != null) {
				var m = obj.defaultTransform.clone();
				m.invert();
				m.multiply(m, obj.getAbsPos());
				return m;
			} else {
				return obj.getAbsPos().clone();
			}
		} else {
			var mat = new h3d.Matrix();
			mat.identity();
			var o = Std.downcast(elt, Object3D);
			while (o != null) {
				mat.multiply(mat, o.getTransform());
				o = o.parent.to(hrt.prefab.Object3D);
			}
			return mat;
		}
	}

	function getClosestVertex(colliders:Array<PolygonBuffer>, meshes:Array<Mesh>, ray:Ray):CustomPivot {
		var best = -1.;
		var bestVertex:CustomPivot = null;
		for (idx in 0...colliders.length) {
			var c = colliders[idx];
			var m = meshes[idx];
			var r = ray.clone();
			r.transform(m.getInvPos());
			var rdir = new FPoint(r.lx, r.ly, r.lz);
			var r0 = new FPoint(r.px, r.py, r.pz);
			@:privateAccess var i = c.startIndex;
			@:privateAccess for (t in 0...c.triCount) {
				var i0 = c.indexes[i++] * 3;
				var p0 = new FPoint(c.buffer[i0++], c.buffer[i0++], c.buffer[i0]);
				var i1 = c.indexes[i++] * 3;
				var p1 = new FPoint(c.buffer[i1++], c.buffer[i1++], c.buffer[i1]);
				var i2 = c.indexes[i++] * 3;
				var p2 = new FPoint(c.buffer[i2++], c.buffer[i2++], c.buffer[i2]);

				var e1 = p1.sub(p0);
				var e2 = p2.sub(p0);
				var p = rdir.cross(e2);
				var det = e1.dot(p);
				if (det < hxd.Math.EPSILON)
					continue; // backface culling (negative) and near parallel (epsilon)

				var invDet = 1 / det;
				var T = r0.sub(p0);
				var u = T.dot(p) * invDet;

				if (u < 0 || u > 1)
					continue;

				var q = T.cross(e1);
				var v = rdir.dot(q) * invDet;

				if (v < 0 || u + v > 1)
					continue;

				var t = e2.dot(q) * invDet;

				if (t < hxd.Math.EPSILON)
					continue;

				if (best < 0 || t < best) {
					best = t;
					var ptIntersection = r.getPoint(t);
					var pI = new FPoint(ptIntersection.x, ptIntersection.y, ptIntersection.z);
					inline function distanceFPoints(a:FPoint, b:FPoint):Float {
						var dx = a.x - b.x;
						var dy = a.y - b.y;
						var dz = a.z - b.z;
						return dx * dx + dy * dy + dz * dz;
					}
					var test0 = distanceFPoints(p0, pI);
					var test1 = distanceFPoints(p1, pI);
					var test2 = distanceFPoints(p2, pI);
					var locBestVertex:FPoint;
					if (test0 <= test1 && test0 <= test2) {
						locBestVertex = p0;
					} else if (test1 <= test0 && test1 <= test2) {
						locBestVertex = p1;
					} else {
						locBestVertex = p2;
					}
					bestVertex = {elt: null, mesh: m, locPos: new Vector(locBestVertex.x, locBestVertex.y, locBestVertex.z)};
				}
			}
		}
		return bestVertex;
	}

	static function isReference(what:PrefabElement):Bool {
		return what != null && what.to(hrt.prefab.Reference) != null;
	}

	static function getPivot(objects:Array<Object>) {
		if (customPivot != null) {
			return customPivot.mesh.localToGlobal(customPivot.locPos.toPoint());
		}
		var pos = new h3d.col.Point();
		for (o in objects) {
			pos = pos.add(o.getAbsPos().getPosition().toPoint());
		}
		pos.scale(1.0 / objects.length);
		return pos;
	}

	static function getPivot2D(objects:Array<h2d.Object>) {
		var b = new h2d.col.Bounds();
		for (o in objects)
			b.addBounds(o.getBounds());
		return b;
	}

	public static function hasParent(elt:PrefabElement, list:Array<PrefabElement>) {
		for (p in list) {
			if (isParent(elt, p))
				return true;
		}
		return false;
	}

	public static function hasChild(elt:PrefabElement, list:Array<PrefabElement>) {
		for (p in list) {
			if (isParent(p, elt))
				return true;
		}
		return false;
	}

	public static function isParent(elt:PrefabElement, parent:PrefabElement) {
		var p = elt.parent;
		while (p != null) {
			if (p == parent)
				return true;
			p = p.parent;
		}
		return false;
	}

	static function getParentGroup(elt:PrefabElement) {
		while (elt != null) {
			if (elt.type == "object")
				return elt;
			elt = elt.parent;
		}
		return null;
	}
}
