; This example demonstrates toggling filters on a scene and source, even if filter names are the same
;
; You will need:
; - a scene called "Scene"
; - a source (scene item) called "Display capture"
; - and two "Color Correction" filter for both the scene and the source

#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends OBSWebSocket {

	filterStatusOnScene := false
	filterStatusOnSource := false

	AfterIdentified() {
		this.GetSourceFilter("Scene", "Color Correction", "scene-cc")
		this.GetSourceFilter("Display Capture", "Color Correction", "source-cc")
		this.GetSceneItemList("Scene")
	}

	GetSourceFilterResponse(res) {
		if (res.d.requestId = "scene-cc") {
			this.filterStatusOnScene := res.d.responseData.filterEnabled
		}
		if (res.d.requestId = "source-cc") {
			this.filterStatusOnSource := res.d.responseData.filterEnabled
		}
	}

	GetSceneItemListResponse(res) {
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/")

; change scene filter
F11::{
	obsc.filterStatusOnScene := !obsc.filterStatusOnScene
	obsc.SetSourceFilterEnabled("Scene", "Color Correction", obsc.Boolean(obsc.filterStatusOnScene))
}

; change source/scene item filter
F12:: {
	obsc.filterStatusOnSource := !obsc.filterStatusOnSource
	obsc.SetSourceFilterEnabled("Display Capture", "Color Correction", obsc.Boolean(obsc.filterStatusOnSource))
}