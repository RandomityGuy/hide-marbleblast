package hide.view;

import hrt.mis.MisParser;
import hrt.mis.McsParser;
import hide.view.CameraController.CamController;

using Lambda;

import hxd.Math;
import hxd.Key as K;
import hrt.prefab.Prefab as PrefabElement;
import hrt.prefab.Object3D;
import hrt.prefab.l3d.Instance;

class FiltersPopup extends hide.comp.Popup {
	var editor:Prefab;

	var gizmoToggle:Bool;

	var inputEls:Map<String, Element> = [];

	public function new(?parent:Element, ?root:Element, editor:Prefab, filters:Map<String, Bool>, type:String) {
		super(parent, root);
		this.editor = editor;
		popup.addClass("settings-popup");
		popup.css("max-width", "300px");

		var form_div = new Element("<div>").addClass("form-grid").appendTo(popup);

		{
			for (typeid in filters.keys()) {
				var on = filters[typeid];
				var input = new Element('<input type="checkbox" id="$typeid" value="$typeid"/>');
				if (on)
					input.get(0).toggleAttribute("checked", true);

				inputEls.set(typeid, input);

				input.change((e) -> {
					var on = !filters[typeid];
					filters.set(typeid, on);

					switch (type) {
						case "Graphics":
							@:privateAccess editor.applyGraphicsFilter(typeid, on);
						case "Scene":
							@:privateAccess editor.applySceneFilter(typeid, on);
					}
				});
				form_div.append(input);
				var nameCap = typeid.substr(0, 1).toUpperCase() + typeid.substr(1);
				form_div.append(new Element('<label for="$typeid" class="left">$nameCap</label>'));
			}
		}

		{
			var dd = new Element('<br><input type="button" value="Toggle Gizmos"/>').appendTo(form_div);
			dd.on("click", function(_) {
				filters.set("trigger", gizmoToggle);
				filters.set("marker", gizmoToggle);
				filters.set("path", gizmoToggle);
				filters.set("pathnode", gizmoToggle);

				inputEls["trigger"].get(0).toggleAttribute("checked", gizmoToggle);
				inputEls["marker"].get(0).toggleAttribute("checked", gizmoToggle);
				inputEls["path"].get(0).toggleAttribute("checked", gizmoToggle);
				inputEls["pathnode"].get(0).toggleAttribute("checked", gizmoToggle);

				@:privateAccess editor.applySceneFilter("trigger", gizmoToggle);
				@:privateAccess editor.applySceneFilter("marker", gizmoToggle);
				@:privateAccess editor.applySceneFilter("path", gizmoToggle);
				@:privateAccess editor.applySceneFilter("pathnode", gizmoToggle);

				gizmoToggle = !gizmoToggle;
			});
		}
	}
}

class TimePopup extends hide.comp.Popup {
	var editor:Prefab;

	var wasPlaying = false;

	public function new(?parent:Element, ?root:Element, editor:Prefab) {
		super(parent, root);
		this.editor = editor;
		popup.addClass("settings-popup");
		popup.css("max-width", "300px");

		wasPlaying = @:privateAccess editor.playAnims;
		@:privateAccess editor.playAnims = false;

		var form_div = new Element("<div>").addClass("form-grid").appendTo(popup);
		var timeEl = new Element('
		<label>Time</label>
		<input type="number" style="cursor: ew-resize" value="${@:privateAccess editor.totalElapsedTime}"/>
		<br/>
		<input type="button" value="Reset"/>');
		var dragging = false;
		var startX = 0;
		timeEl.appendTo(form_div);
		var inpEl:js.html.InputElement = cast timeEl.get(2);
		inpEl.addEventListener("mousedown", (e) -> {
			dragging = true;
			startX = e.clientX;
			var startVal = Std.parseFloat(inpEl.value);

			var moveListener = (e) -> {
				if (dragging) {
					var dx = e.clientX - startX;
					inpEl.value = '${startVal + Std.int(dx * 0.1)}';
					editor.setAnimTime(Std.parseFloat(inpEl.value));
				}
			}

			var mouseUpListener;
			mouseUpListener = (e) -> {
				dragging = false;
				js.Browser.document.removeEventListener('mousemove', moveListener);
				js.Browser.document.removeEventListener('mouseup', mouseUpListener);
			}

			js.Browser.document.addEventListener('mousemove', moveListener);
			js.Browser.document.addEventListener("mouseup", mouseUpListener);
		});
		var resetEl:js.html.InputElement = cast timeEl.get(6);
		resetEl.addEventListener("click", (e) -> {
			inpEl.value = "0";
			editor.setAnimTime(0);
		});
	}

	override function close() {
		super.close();
		@:privateAccess editor.playAnims = wasPlaying;
	}
}

@:access(hide.view.Prefab)
private class PrefabSceneEditor extends hide.comp.SceneEditor {
	var parent:Prefab;

	public function new(view, data) {
		super(view, data);
		parent = cast view;
		this.localTransform = false; // TODO: Expose option
	}

	override function refresh(?mode, ?callback) {
		parent.onRefresh();
		super.refresh(mode, callback);
	}

	override function update(dt) {
		super.update(dt);
		parent.onUpdate(dt);
	}

	override function onSceneReady() {
		super.onSceneReady();
		parent.onSceneReady();
	}

	override function applyTreeStyle(p:PrefabElement, el:Element, ?pname:String) {
		super.applyTreeStyle(p, el, pname);
		parent.applyTreeStyle(p, el, pname);
	}

	override function applySceneStyle(p:PrefabElement) {
		parent.applySceneStyle(p);
	}

	override function onPrefabChange(p:PrefabElement, ?pname:String) {
		super.onPrefabChange(p, pname);
		parent.onPrefabChange(p, pname);
	}

	override function getNewContextMenu(current:PrefabElement, ?onMake:PrefabElement->Void = null, ?groupByType = true) {
		var newItems = super.getNewContextMenu(current, onMake, groupByType);
		var recents = getNewRecentContextMenu(current, onMake);

		function setup(p:PrefabElement) {
			autoName(p);
			haxe.Timer.delay(addElements.bind([p]), 0);
		}

		function addNewInstances() {
			var items = new Array<hide.comp.ContextMenu.ContextMenuItem>();
			newItems.unshift({
				label: "Instance",
				menu: items
			});
		};
		addNewInstances();
		newItems.unshift({
			label: "Recents",
			menu: recents,
		});
		return newItems;
	}

	override function getAvailableTags(p:PrefabElement) {
		return cast ide.currentConfig.get("sceneeditor.tags");
	}
}

class Prefab extends FileView {
	public var sceneEditor:PrefabSceneEditor;

	var data:hrt.prefab.Library;

	var tools:hide.comp.Toolbar;

	var layerToolbar:hide.comp.Toolbar;
	var layerButtons:Map<PrefabElement, hide.comp.Toolbar.ToolToggle>;

	var resizablePanel:hide.comp.ResizablePanel;

	var grid:h3d.scene.Graphics;

	var gridStep:Float = 0.;
	var gridSize:Int;
	var showGrid = false;

	// autoSync
	var autoSync:Bool;
	var currentVersion:Int = 0;
	var lastSyncChange:Float = 0.;
	var sceneFilters:Map<String, Bool>;
	var graphicsFilters:Map<String, Bool>;
	var viewModes:Map<String, Bool>;
	var statusText:h2d.Text;
	var posToolTip:h2d.Text;

	var scene(get, null):hide.comp.Scene;

	var totalElapsedTime:Float = 0;
	var playAnims:Bool = false;
	var camPathAnimation:Bool = false;
	var camPathAnimationDummy:hrt.prefab.l3d.TorqueObject;
	var camPathRenderObj:h3d.scene.Object;
	var camPathCameraClassSave:Class<hide.view.CameraController.CameraControllerBase>;

	function get_scene()
		return sceneEditor.scene;

	public var properties(get, null):hide.comp.PropsEditor;

	function get_properties()
		return sceneEditor.properties;

	override function destroy() {
		super.destroy();
		if (hide.Ide.inst.getViews(Prefab).length == 0) {
			var cviews = hide.Ide.inst.getViews(hide.view.CreatorView);
			for (v in cviews) {
				v.close();
			}
			haxe.Timer.delay(() -> {
				hide.Ide.inst.open("hide.view.Welcome", {});
			}, 500);
		}
	}

	override function onDisplay() {
		if (sceneEditor != null)
			sceneEditor.dispose();

		hide.Ide.inst.open("hide.view.CreatorView", {}); // Open the creator

		data = new hrt.prefab.Library();

		var path = getPath();
		var content = sys.io.File.getContent(path);

		var isMis = StringTools.endsWith(path, ".mis");
		if (isMis) {
			var parser = new MisParser(content, path);
			var misfile = parser.parse();
			data.loadData(misfile.toHeapsJSON()); // stupid indirection
		} else if (StringTools.endsWith(path, ".mcs")) {
			var parser = new McsParser(content, path);
			var misfile = parser.parse();
			data.loadData(misfile.toHeapsJSON()); // stupid indirection
		} else {
			data.loadData(haxe.Json.parse(content));
		}
		currentSign = ide.makeSignature(content);

		element.html('
			<div class="flex vertical">
				<div id="prefab-toolbar"></div>

				<div class="scene-partition" style="display: flex; flex-direction: row; flex: 1; overflow: hidden;">
					<div class="heaps-scene"></div>
					<div class="tree-column">
						<div class="flex vertical">
							<div class="hide-toolbar">
								<div class="toolbar-label">
									<div class="icon ico ico-sitemap"></div>
									Scene
								</div>
								<div class="button collapse-btn" title="Collapse all">
									<div class="icon ico ico-reply-all"></div>
								</div>

								<div class="button combine-btn layout-btn" title="Toggle columns layout">
									<div class="icon ico ico-compress"></div>
								</div>
								<div class="button separate-btn layout-btn" title="Toggle columns layout">
									<div class="icon ico ico-expand"></div>
								</div>

								<div
									class="button hide-cols-btn close-btn"
									title="Hide Tree & Props (${config.get("key.sceneeditor.toggleLayout")})"
								>
									<div class="icon ico ico-chevron-right"></div>
								</div>
							</div>

							<div class="hide-scenetree"></div>
						</div>
					</div>

					<div class="props-column">
						<div class="hide-toolbar">
							<div class="toolbar-label">
								<div class="icon ico ico-sitemap"></div>
								Properties
							</div>
						</div>
							<div class="hide-scroll"></div>
					</div>

					<div
						class="button show-cols-btn close-btn"
						title="Show Tree & Props (${config.get("key.sceneeditor.toggleLayout")})"
					>
						<div class="icon ico ico-chevron-left"></div>
					</div>
				</div>
			</div>
		');

		tools = new hide.comp.Toolbar(null, element.find("#prefab-toolbar"));
		layerToolbar = new hide.comp.Toolbar(null, element.find(".layer-buttons"));
		currentVersion = undo.currentID;

		sceneEditor = new PrefabSceneEditor(this, data);
		element.find(".hide-scenetree").first().append(sceneEditor.tree.element);
		element.find(".hide-scroll").first().append(properties.element);
		element.find(".heaps-scene").first().append(scene.element);

		var treeColumn = element.find(".tree-column").first();
		resizablePanel = new hide.comp.ResizablePanel(Horizontal, treeColumn);
		resizablePanel.saveDisplayKey = "treeColumn";
		resizablePanel.onResize = () -> @:privateAccess if (scene.window != null) scene.window.checkResize();

		sceneEditor.tree.element.addClass("small");

		refreshColLayout();
		element.find(".combine-btn").first().click((_) -> setCombine(true));
		element.find(".separate-btn").first().click((_) -> setCombine(false));

		element.find(".show-cols-btn").first().click(showColumns);
		element.find(".hide-cols-btn").first().click(hideColumns);

		element.find(".collapse-btn").click(function(e) {
			sceneEditor.collapseTree();
		});

		keys.register("sceneeditor.toggleLayout", () -> {
			if (element.find(".tree-column").first().css('display') == 'none')
				showColumns();
			else
				hideColumns();
		});

		refreshSceneFilters();
		refreshGraphicsFilters();
		refreshViewModes();
	}

	function refreshColLayout() {
		var config = ide.ideConfig;
		if (config.sceneEditorLayout == null) {
			config.sceneEditorLayout = {
				colsVisible: true,
				colsCombined: false,
			};
		}
		setCombine(config.sceneEditorLayout.colsCombined);

		if (config.sceneEditorLayout.colsVisible)
			showColumns();
		else
			hideColumns();
		if (resizablePanel != null)
			resizablePanel.setSize();
	}

	override function onActivate() {
		if (element == null)
			return;
		if (sceneEditor != null)
			refreshColLayout();
	}

	public function hideColumns(?_) {
		element.find(".tree-column").first().hide();
		element.find(".props-column").first().hide();
		element.find(".splitter").first().hide();
		element.find(".show-cols-btn").first().show();
		ide.ideConfig.sceneEditorLayout.colsVisible = false;
		@:privateAccess ide.config.global.save();
		@:privateAccess if (scene.window != null)
			scene.window.checkResize();
	}

	public function showColumns(?_) {
		element.find(".tree-column").first().show();
		element.find(".props-column").first().show();
		element.find(".splitter").first().show();
		element.find(".show-cols-btn").first().hide();
		ide.ideConfig.sceneEditorLayout.colsVisible = true;
		@:privateAccess ide.config.global.save();
		@:privateAccess if (scene.window != null)
			scene.window.checkResize();
	}

	function setCombine(val) {
		var fullscene = element.find(".scene-partition").first();
		var props = element.find(".props-column").first();
		fullscene.toggleClass("reduced-columns", val);
		if (val) {
			element.find(".hide-scenetree").first().parent().append(props);
			element.find(".combine-btn").first().hide();
			element.find(".separate-btn").first().show();
			resizablePanel.setSize();
		} else {
			fullscene.append(props);
			element.find(".combine-btn").first().show();
			element.find(".separate-btn").first().hide();
		}
		ide.ideConfig.sceneEditorLayout.colsCombined = val;
		@:privateAccess ide.config.global.save();
		@:privateAccess if (scene.window != null)
			scene.window.checkResize();
	}

	public function onSceneReady() {
		refreshSceneFilters();
		refreshGraphicsFilters();
		refreshViewModes();
		tools.saveDisplayKey = "Prefab/toolbar";
		statusText = new h2d.Text(hxd.res.DefaultFont.get(), scene.s2d);
		statusText.setPosition(5, 5);
		statusText.visible = false;

		/*gridStep = @:privateAccess sceneEditor.gizmo.moveStep;*/
		sceneEditor.updateGrid = function() {
			updateGrid();
		};
		var toolsDefs = new Array<hide.comp.Toolbar.ToolDef>();

		toolsDefs.push({
			id: "perspectiveCamera",
			title: "Perspective camera",
			icon: "video-camera",
			type: Button(() -> resetCamera(false))
		});
		toolsDefs.push({
			id: "camSettings",
			title: "Camera Settings",
			icon: "camera",
			type: Popup((e:hide.Element) -> new hide.comp.CameraControllerEditor(sceneEditor, null, e))
		});

		toolsDefs.push({
			id: "topCamera",
			title: "Top camera",
			icon: "video-camera",
			iconStyle: {transform: "rotateZ(90deg)"},
			type: Button(() -> resetCamera(true))
		});

		toolsDefs.push({
			id: "",
			title: "",
			icon: "",
			type: Separator
		});

		toolsDefs.push({
			id: "snapToGroundToggle",
			title: "Snap to ground",
			icon: "anchor",
			type: Toggle((v) -> sceneEditor.snapToGround = v)
		});

		toolsDefs.push({
			id: "",
			title: "",
			icon: "",
			type: Separator
		});

		toolsDefs.push({
			id: "translationMode",
			title: "Gizmo translation Mode",
			icon: "arrows",
			type: Button(@:privateAccess sceneEditor.gizmo.translationMode)
		});
		toolsDefs.push({
			id: "rotationMode",
			title: "Gizmo rotation Mode",
			icon: "refresh",
			type: Button(@:privateAccess sceneEditor.gizmo.rotationMode)
		});
		toolsDefs.push({
			id: "scalingMode",
			title: "Gizmo scaling Mode",
			icon: "expand",
			type: Button(@:privateAccess sceneEditor.gizmo.scalingMode)
		});

		toolsDefs.push({
			id: "",
			title: "",
			icon: "",
			type: Separator
		});

		toolsDefs.push({
			id: "toggleSnap",
			title: "Snap Toggle",
			icon: "magnet",
			type: Toggle((v) -> {
				sceneEditor.snapToggle = v;
				sceneEditor.updateGrid();
			})
		});
		toolsDefs.push({
			id: "snap-menu",
			title: "",
			icon: "",
			type: Popup((e) -> new hide.comp.SceneEditor.SnapSettingsPopup(null, e, sceneEditor))
		});

		toolsDefs.push({
			id: "",
			title: "",
			icon: "",
			type: Separator
		});

		toolsDefs.push({
			id: "localTransformsToggle",
			title: "Local transforms",
			icon: "compass",
			type: Toggle((v) -> sceneEditor.localTransform = v)
		});

		toolsDefs.push({
			id: "",
			title: "",
			icon: "",
			type: Separator
		});

		toolsDefs.push({
			id: "gridToggle",
			title: "Toggle grid",
			icon: "th",
			type: Toggle((v) -> {
				showGrid = v;
				updateGrid();
			})
		});
		toolsDefs.push({
			id: "axisToggle",
			title: "Toggle model axis",
			icon: "cube",
			type: Toggle((v) -> {
				sceneEditor.showBasis = v;
				sceneEditor.updateBasis();
			})
		});
		toolsDefs.push({
			id: "iconVisibility",
			title: "Toggle 3d icons visibility",
			icon: "image",
			type: Toggle((v) -> {
				hide.Ide.inst.show3DIcons = v;
			}),
			defaultValue: true
		});
		toolsDefs.push({
			id: "iconVisibility-menu",
			title: "",
			icon: "",
			type: Popup((e) -> new hide.comp.SceneEditor.IconVisibilityPopup(null, e, sceneEditor))
		});

		var texContent:Element = null;
		toolsDefs.push({
			id: "sceneInformationToggle",
			title: "Scene information",
			icon: "info-circle",
			type: Toggle((b) -> statusText.visible = b),
			rightClick: () -> {
				if (texContent != null) {
					texContent.remove();
					texContent = null;
				}
				new hide.comp.ContextMenu([
					{
						label: "Show Texture Details",
						click: function() {
							var memStats = scene.engine.mem.stats();
							var texs = @:privateAccess scene.engine.mem.textures;
							var list = [
								for (t in texs)
									{
										n: '${t.width}x${t.height}  ${t.format}  ${t.name}',
										size: t.width * t.height
									}
							];
							list.sort((a, b) -> Reflect.compare(b.size, a.size));
							var content = new Element('<div tabindex="1" class="overlay-info"><h2>Scene info</h2><pre></pre></div>');
							new Element(element[0].ownerDocument.body).append(content);
							var pre = content.find("pre");
							pre.text([for (l in list) l.n].join("\n"));
							texContent = content;
							content.blur(function(_) {
								content.remove();
								texContent = null;
							});
						}
					}
				]);
			}
		});
		toolsDefs.push({
			id: "autoSyncToggle",
			title: "Auto synchronize",
			icon: "refresh",
			type: Toggle((b) -> autoSync = b)
		});
		// toolsDefs.push({
		// 	id: "wireframeToggle",
		// 	title: "Wireframe",
		// 	icon: "connectdevelop",
		// 	type: Toggle((b) -> {
		// 		sceneEditor.setWireframe(b);
		// 	}),
		// });
		// toolsDefs.push({
		// 	id: "jointsToggle",
		// 	title: "Joints",
		// 	icon: "share-alt",
		// 	type: Toggle((b) -> {
		// 		sceneEditor.setJoints(b, null);
		// 	}),
		// });
		// toolsDefs.push({
		// 	id: "backgroundColor",
		// 	title: "Background Color",
		// 	type: Color(function(v) {
		// 		scene.engine.backgroundColor = v;
		// 		updateGrid();
		// 	})
		// });

		toolsDefs.push({
			id: "",
			title: "",
			icon: "",
			type: Separator
		});

		toolsDefs.push({
			id: "help",
			title: "help",
			icon: "question",
			type: Popup((e) -> new hide.comp.SceneEditor.HelpPopup(null, e, sceneEditor))
		});

		toolsDefs.push({
			id: "minfo",
			title: "Mission Info",
			icon: "info",
			type: Popup((e) -> {
				var mifind = data.find(x -> x.name == "MissionInfo" ? x : null);
				if (mifind != null) {
					var micast = cast(mifind, hrt.prefab.l3d.ScriptObject);
					if (micast != null) {
						var mi = new hrt.mis.MissionInfo();
						mi.fromMissionInfo(micast);
						mi._gameType = hrt.mis.TorqueConfig.gameType;
						return new hide.comp.MissionInfoEditor(null, e, mi);
					}
				}
				return null;
			})
		});

		toolsDefs.push({
			id: "",
			title: "",
			icon: "",
			type: Separator
		});

		toolsDefs.push({
			id: "animControl",
			title: "Play Animations",
			icon: "play",
			type: Toggle((b) -> playAnims = b)
		});

		toolsDefs.push({
			id: "anim-menu",
			title: "",
			icon: "",
			type: Popup((e) -> new TimePopup(null, e, this))
		});

		toolsDefs.push({
			id: "",
			title: "",
			icon: "",
			type: Separator
		});

		// toolsDefs.push({
		// 	id: "viewModes",
		// 	title: "View Modes",
		// 	type: Popup((e) -> new hide.comp.SceneEditor.ViewModePopup(null, e, Std.downcast(@:privateAccess scene.s3d.renderer, h3d.scene.pbr.Renderer)))
		// });

		// toolsDefs.push({
		// 	id: "",
		// 	title: "",
		// 	icon: "",
		// 	type: Separator
		// });

		// toolsDefs.push({id: "graphicsFilters", title: "Graphics filters", type: Popup((e) -> new FiltersPopup(null, e, this, graphicsFilters, "Graphics"))});

		// toolsDefs.push({
		// 	id: "",
		// 	title: "",
		// 	icon: "",
		// 	type: Separator
		// });

		toolsDefs.push({id: "sceneFilters", title: "Scene filters", type: Popup((e) -> new FiltersPopup(null, e, this, sceneFilters, "Scene"))});

		toolsDefs.push({
			id: "",
			title: "",
			icon: "",
			type: Separator
		});

		// toolsDefs.push({
		// 	id: "renderProps",
		// 	title: "Render props",
		// 	type: Popup((e) -> new hide.comp.SceneEditor.RenderPropsPopup(null, e, sceneEditor, true))
		// });

		// toolsDefs.push({
		// 	id: "",
		// 	title: "",
		// 	icon: "",
		// 	type: Separator
		// });

		// toolsDefs.push({id: "sceneSpeed", title: "Speed", type: Range((v) -> scene.speed = v)});

		// toolsDefs.push({
		// 	id: "",
		// 	title: "",
		// 	icon: "",
		// 	type: Separator
		// });

		// toolsDefs.push({id: "test", title : "Hello", icon : "", type : Popup((e : hide.Element) -> new hide.comp.CameraControllerEditor(sceneEditor, null,e))});

		tools.makeToolbar(toolsDefs, config, keys);

		posToolTip = new h2d.Text(hxd.res.DefaultFont.get(), scene.s2d);
		posToolTip.dropShadow = {
			dx: 1,
			dy: 1,
			color: 0,
			alpha: 0.5
		};

		var gizmo = @:privateAccess sceneEditor.gizmo;

		var onSetGizmoMode = function(mode:hide.view.l3d.Gizmo.EditMode) {
			tools.element.find("#translationMode").get(0).toggleAttribute("checked", mode == Translation);
			tools.element.find("#rotationMode").get(0).toggleAttribute("checked", mode == Rotation);
			tools.element.find("#scalingMode").get(0).toggleAttribute("checked", mode == Scaling);
		};

		gizmo.onChangeMode = onSetGizmoMode;
		onSetGizmoMode(gizmo.editMode);

		updateStats();
		updateGrid();
		initGraphicsFilters();
		initSceneFilters();
		sceneEditor.onRefresh = () -> {
			initGraphicsFilters();
			initSceneFilters();
		}
	}

	function updateStats() {
		if (statusText.visible) {
			var memStats = scene.engine.mem.stats();
			@:privateAccess
			var lines:Array<String> = [
				'Scene objects: ${scene.s3d.getObjectsCount()}',
				'Interactives: ' + sceneEditor.interactives.count(),
				'Contexts: ' + sceneEditor.context.shared.contexts.count(),
				'Triangles: ${scene.engine.drawTriangles}',
				'Buffers: ${memStats.bufferCount}',
				'Textures: ${memStats.textureCount}',
				'FPS: ${Math.round(scene.engine.realFps)}',
				'Draw Calls: ${scene.engine.drawCalls}',
			];
			statusText.text = lines.join("\n");
		}
		haxe.Timer.delay(function() sceneEditor.event.wait(0.5, updateStats), 0);
	}

	function resetCamera(top:Bool) {
		var targetPt = new h3d.col.Point(0, 0, 0);
		var curEdit = sceneEditor.curEdit;
		var bounds = sceneEditor.scene.s3d.getBounds();
		targetPt = bounds.getCenter();
		if (curEdit != null && curEdit.rootObjects.length > 0) {
			targetPt = curEdit.rootObjects[0].getAbsPos().getPosition().toPoint();
		}
		if (top)
			sceneEditor.cameraController.set(200, Math.PI / 2, 0.001, targetPt);
		else
			sceneEditor.cameraController.set(200, -4.7, 0.8, targetPt);
		sceneEditor.cameraController.toTarget();
	}

	override function getDefaultContent() {
		return haxe.io.Bytes.ofString(ide.toJSON(new hrt.prefab.Library().saveData()));
	}

	override function canSave() {
		return data != null;
	}

	override function save() {
		if (!canSave())
			return;

		var path = getPath();
		var content = sys.io.File.getContent(path);

		var isMis = StringTools.endsWith(path, ".mis");
		var isMcs = StringTools.endsWith(path, ".mcs");

		var savecontent;

		if (isMis || isMcs) {
			var exporter = new hrt.mis.MisExporter(data.saveData(), content, isMcs);
			savecontent = exporter.convert();
		} else {
			savecontent = ide.toJSON(data.saveData());
		}
		var newSign = ide.makeSignature(savecontent);
		if (newSign != currentSign)
			haxe.Timer.delay(saveBackup.bind(savecontent), 0);
		currentSign = newSign;
		sys.io.File.saveContent(getPath(), savecontent);
		super.save();
	}

	function updateGrid() {
		if (grid != null) {
			grid.remove();
			grid = null;
		}

		if (!showGrid)
			return;

		grid = new h3d.scene.Graphics(scene.s3d);
		grid.scale(1);
		grid.material.mainPass.setPassName("debuggeom");

		if (sceneEditor.snapToggle) {
			gridStep = sceneEditor.snapMoveStep;
		} else {
			gridStep = ide.currentConfig.get("sceneeditor.gridStep");
		}
		gridSize = ide.currentConfig.get("sceneeditor.gridSize");

		var col = h3d.Vector.fromColor(scene.engine.backgroundColor);
		var hsl = col.toColorHSL();

		var mov = 0.1;

		if (sceneEditor.snapToggle) {
			mov = 0.2;
			hsl.y += (1.0 - hsl.y) * 0.2;
		}
		if (hsl.z > 0.5)
			hsl.z -= mov;
		else
			hsl.z += mov;

		col.makeColor(hsl.x, hsl.y, hsl.z);

		grid.lineStyle(1.0, col.toColor(), 1.0);
		for (i in 0...(hxd.Math.floor(gridSize / gridStep) + 1)) {
			grid.moveTo(i * gridStep, 0, 0);
			grid.lineTo(i * gridStep, gridSize, 0);

			grid.moveTo(0, i * gridStep, 0);
			grid.lineTo(gridSize, i * gridStep, 0);
		}
		grid.lineStyle(0);
		grid.setPosition(-1 * gridSize / 2, -1 * gridSize / 2, 0);
	}

	public function setAnimTime(t:Float) {
		totalElapsedTime = t;
		for (obj in data.getAll(hrt.prefab.Object3D, true)) {
			var ctx = sceneEditor.getContext(obj);
			obj.tick(ctx, totalElapsedTime, 0);
		}
		// Update camera path
		if (camPathAnimation) {}
	}

	function onUpdate(dt:Float) {
		if (K.isDown(K.ALT)) {
			posToolTip.visible = true;
			var proj = sceneEditor.screenToGround(scene.s2d.mouseX, scene.s2d.mouseY);
			posToolTip.text = proj != null ? '${Math.fmt(proj.x)}, ${Math.fmt(proj.y)}, ${Math.fmt(proj.z)}' : '???';
			posToolTip.setPosition(scene.s2d.mouseX, scene.s2d.mouseY - 12);
		} else {
			posToolTip.visible = false;
		}

		if (autoSync && (currentVersion != undo.currentID || lastSyncChange != properties.lastChange)) {
			save();
			lastSyncChange = properties.lastChange;
			currentVersion = undo.currentID;
		}
		if (playAnims) {
			totalElapsedTime += dt;
			for (obj in data.getAll(hrt.prefab.Object3D, true)) {
				var ctx = sceneEditor.getContext(obj);
				obj.tick(ctx, totalElapsedTime, dt);
			}
			// Update camera path
			if (camPathAnimation) {
				var campos = camPathRenderObj.getAbsPos().getPosition();
				var rotmat = camPathRenderObj.getRotationQuat().toMatrix();
				var rotfront = rotmat.front();
				var rotside = rotmat.right();
				rotmat._11 = rotside.x;
				rotmat._12 = rotside.y;
				rotmat._13 = rotside.z;
				rotmat._21 = -rotfront.x;
				rotmat._22 = -rotfront.y;
				rotmat._23 = -rotfront.z;
				var rot = new h3d.Quat();
				rot.initRotateMatrix(rotmat);

				var flightController = cast(sceneEditor.cameraController, hide.view.CameraController.FlightController);
				if (flightController != null) {
					@:privateAccess flightController.currentFlightPos.load(campos);
					@:privateAccess flightController.currentFlightRot.load(rot);
					@:privateAccess flightController.targetFlightPos.load(campos);
					@:privateAccess flightController.targetFlightRot.load(rot);
				}
			}
		}
	}

	function onRefresh() {}

	override function onDragDrop(items:Array<String>, isDrop:Bool) {
		return sceneEditor.onDragDrop(items, isDrop);
	}

	function applyGraphicsFilter(typeid:String, enable:Bool) {
		saveDisplayState("graphicsFilters/" + typeid, enable);

		var r:h3d.scene.Renderer = scene.s3d.renderer;
		var all = data.getAll(hrt.prefab.Object3D, true);
		for (obj in all) {
			if (obj.getDisplayFilters().contains(typeid)) {
				var ctx = scene.editor.getContext(obj);
				if (ctx != null)
					obj.updateInstance(ctx);
			}
		}

		switch (typeid) {
			case "shadows":
				r.shadows = enable;
			default:
		}
	}

	function applySceneFilter(typeid:String, visible:Bool) {
		saveDisplayState("sceneFilters/" + typeid, visible);
		var all = [];
		if (typeid != 'light')
			all = data.getAll(hrt.prefab.Prefab, true);
		else
			all = data.flatten(hrt.prefab.Prefab);
		for (p in all) {
			if (typeid == "pathnode") {
				// special handling ew
				if (p is hrt.prefab.l3d.StaticShape) {
					var so = cast(p, hrt.prefab.l3d.StaticShape);
					if (["pathnode", "bezierhandle"].contains(so.customFieldProvider.toLowerCase())) {
						for (ctx in sceneEditor.getContexts(so)) {
							ctx.local3d.visible = visible;
						}
					}
				}
			} else {
				if (p.type == typeid || p.getCdbType() == typeid) {
					sceneEditor.applySceneStyle(p);
				}
			}
		}
	}

	function refreshSceneFilters() {
		var filters:Array<String> = ide.currentConfig.get("sceneeditor.filterTypes");
		filters = filters.copy();
		sceneFilters = new Map();
		for (f in filters) {
			sceneFilters.set(f, getDisplayState("sceneFilters/" + f) != false);
		}
	}

	function initGraphicsFilters() {
		for (typeid in graphicsFilters.keys()) {
			applyGraphicsFilter(typeid, graphicsFilters.get(typeid));
		}
	}

	function initSceneFilters() {
		for (typeid in sceneFilters.keys()) {
			applySceneFilter(typeid, sceneFilters.get(typeid));
		}
	}

	function refreshGraphicsFilters() {
		var filters:Array<String> = ["shadows"];
		var all = data.getAll(hrt.prefab.Object3D, true);
		for (obj in all) {
			var objFilters = obj.getDisplayFilters();
			for (f in filters) {
				objFilters.remove(f);
			}
			filters = filters.concat(objFilters);
		}
		filters = filters.copy();
		graphicsFilters = new Map();
		for (f in filters) {
			graphicsFilters.set(f, getDisplayState("graphicsFilters/" + f) != false);
		}
	}

	function refreshViewModes() {
		var filters:Array<String> = [
			"LIT", "Full", "Albedo", "Normal", "Roughness", "Metalness", "Emissive", "AO", "Shadows", "Performance"
		];
		viewModes = new Map();
		for (f in filters) {
			viewModes.set(f, false);
		}
	}

	function filtersToMenuItem(filters:Map<String, Bool>, type:String):Array<hide.comp.ContextMenu.ContextMenuItem> {
		var content:Array<hide.comp.ContextMenu.ContextMenuItem> = [];
		var initDone = false;
		for (typeid in filters.keys()) {
			if (type == "View") {
				content.push({
					label: typeid,
					click: function() {
						var r = Std.downcast(scene.s3d.renderer, h3d.scene.pbr.Renderer);
						if (r == null)
							return;
						var slides = @:privateAccess r.slides;
						if (slides == null)
							return;
						switch (typeid) {
							case "LIT":
								r.displayMode = Pbr;
							case "Full":
								r.displayMode = Debug;
								slides.shader.mode = Full;
							case "Albedo":
								r.displayMode = Debug;
								slides.shader.mode = Albedo;
							case "Normal":
								r.displayMode = Debug;
								slides.shader.mode = Normal;
							case "Roughness":
								r.displayMode = Debug;
								slides.shader.mode = Roughness;
							case "Metalness":
								r.displayMode = Debug;
								slides.shader.mode = Metalness;
							case "Emissive":
								r.displayMode = Debug;
								slides.shader.mode = Emmissive;
							case "AO":
								r.displayMode = Debug;
								slides.shader.mode = AO;
							case "Shadows":
								r.displayMode = Debug;
								slides.shader.mode = Shadow;
							case "Performance":
								r.displayMode = Performance;
							default:
						}
					}
				});
			} else {
				content.push({
					label: typeid,
					checked: filters[typeid],
					click: function() {
						var on = !filters[typeid];
						filters.set(typeid, on);
						if (initDone)
							switch (type) {
								case "Graphics":
									applyGraphicsFilter(typeid, on);
								case "Scene":
									applySceneFilter(typeid, on);
							}

						content.find(function(item) return item.label == typeid).checked = on;
					}
				});
			}
		}
		initDone = true;
		return content;
	}

	function applyTreeStyle(p:PrefabElement, el:Element, pname:String) {}

	function onPrefabChange(p:PrefabElement, ?pname:String) {}

	function applySceneStyle(p:PrefabElement) {
		var prefabView = Std.downcast(p, hrt.prefab.Library); // don't use "to" (Reference)
		if (prefabView != null && prefabView.parent == null) {
			updateGrid();
			return;
		}

		var obj3d = p.to(Object3D);
		if (obj3d != null) {
			var visible = obj3d.visible && !sceneEditor.isHidden(obj3d) && sceneFilters.get(p.type) != false;
			if (visible) {
				var cdbType = p.getCdbType();
				if (cdbType != null && sceneFilters.get(cdbType) == false)
					visible = false;
			}
			for (ctx in sceneEditor.getContexts(obj3d)) {
				ctx.local3d.visible = visible;
			}
		}
		var color = getDisplayColor(p);
		if (color != null) {
			color = (color & 0xffffff) | 0xa0000000;
			var box = p.to(hrt.prefab.l3d.Box);
			if (box != null) {
				var ctx = sceneEditor.getContext(box);
				box.setColor(ctx, color);
			}
			var poly = p.to(hrt.prefab.l3d.Polygon);
			if (poly != null) {
				var ctx = sceneEditor.getContext(poly);
				poly.setColor(ctx, color);
			}
		}
	}

	function getDisplayColor(p:PrefabElement):Null<Int> {
		var typeId = p.getCdbType();
		if (typeId != null) {
			var colors = ide.currentConfig.get("sceneeditor.colors");
			var color = Reflect.field(colors, typeId);
			if (color != null) {
				return Std.parseInt("0x" + color.substr(1)) | 0xff000000;
			}
		}
		return null;
	}

	public function doCameraPathAnimation() {
		var camPath1 = cast(data.getPrefabByName("camerapath1"), hrt.prefab.l3d.StaticShape);
		if (camPath1 != null) {
			camPathAnimation = true;
			if (camPathAnimationDummy == null) {
				camPathAnimationDummy = new hrt.prefab.l3d.TorqueObject();
				camPathAnimationDummy.parent = data;
				camPathAnimationDummy.dynamicFields.push({field: "path", value: "camerapath1"});
				sceneEditor.addElements([camPathAnimationDummy]);
				camPathRenderObj = new h3d.scene.Object(scene.s3d);

				var ctx = sceneEditor.getContext(camPathAnimationDummy);
				camPathAnimationDummy.buildAnimators(camPathRenderObj, ctx);
				camPathCameraClassSave = Type.getClass(sceneEditor.cameraController);
				sceneEditor.switchCamController(hide.view.CameraController.FlightController);
			}
		}
	}

	public function stopCameraPathAnimation() {
		camPathAnimation = false;
		if (camPathAnimationDummy != null) {
			var ctx = sceneEditor.getContext(camPathAnimationDummy);
			camPathAnimationDummy.removeInstance(ctx);
			sceneEditor.deleteElements([camPathAnimationDummy]);
			camPathAnimationDummy = null;
			camPathRenderObj.remove();
			camPathRenderObj = null;

			sceneEditor.switchCamController(camPathCameraClassSave);
		}
	}

	static var _ = FileTree.registerExtension(Prefab, ["prefab"], {icon: "sitemap", createNew: "Prefab"});
	static var _2 = FileTree.registerExtension(Prefab, ["mis"], {icon: "sitemap", createNew: "Prefab"});
	static var _3 = FileTree.registerExtension(Prefab, ["mcs"], {icon: "sitemap", createNew: "Prefab"});
	static var _1 = FileTree.registerExtension(Prefab, ["l3d"], {icon: "sitemap"});
}
