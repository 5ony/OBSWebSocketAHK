#NoEnv
SetBatchLines, -1

#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	state :=

	AfterIdentified() {
		this.GetCurrentProgramScene()
	}

	GetSceneItemListResponse(data) {
		sceneItemIdsByName := {}
		For Key, sceneItemData in data.d.responseData.sceneItems
		{
			sceneItemIdsByName[sceneItemData.sourceName] := sceneItemData.sceneItemId
		}

		; this state check is not needed for a simple script such as this one,
		; but might come handy if the events getting more complex
		if (this.state && this.state.name = "toggleSceneItem") {
			this.SetSceneItemEnabled(this.state.sceneName, sceneItemIdsByName[this.state.sceneItem], this.Boolean(this.state.isVisible))
		}
	}

	toggleSceneItem(sceneName, sceneItem, isVisible := -1) {
		this.state := { name: "toggleSceneItem", sceneName: sceneName, sceneItem: sceneItem, isVisible: isVisible }
		this.GetSceneItemList(sceneName)
	}

	changeScene(sceneName) {
		this.SetCurrentProgramScene(sceneName)
	}

}

obsc := new MyOBSController("ws://127.0.0.1:4455/")

; set active scene to SceneA
Numpad1::
	obsc.changeScene("SceneA")
return

; set active scene to SceneB and set ItemB to visible
Numpad2::
	obsc.changeScene("SceneB")
	Sleep, 100 ; wait for scene change
	obsc.toggleSceneItem("SceneB", "ItemB", true)
return

; set active scene to SceneB and set ItemB to hidden
Numpad3::
	obsc.changeScene("SceneB")
	Sleep, 100 ; wait for scene change
	obsc.toggleSceneItem("SceneB", "ItemB", false)
return

; set ItemC to visible on SceneC, doesn't matter if SceneC is visible or not
Numpad4::
	obsc.toggleSceneItem("SceneC", "ItemC", true)
return

; set ItemC to hidden on SceneC, doesn't matter if SceneC is visible or not
Numpad5::
	obsc.toggleSceneItem("SceneC", "ItemC", false)
return