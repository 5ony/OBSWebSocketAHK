#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	sceneName := "Scene"
	sceneItemsByName := Map()

	AfterIdentified() {
		this.GetFullSceneItemList(this.sceneName)
	}

	GetFullSceneItemListResponse(data) {
		For Key, sceneItemData in data.d.responseData.sceneItems
		{
			this.sceneItemsByName[sceneItemData.sourceName] := sceneItemData
		}
	}

	toggleSceneItem(sceneItem) {
		if (!this.sceneItemsByName.Has(sceneItem)) {
			return
		}
		this.sceneItemsByName[sceneItem].sceneItemEnabled := !this.sceneItemsByName[sceneItem].sceneItemEnabled
		this.SetSceneItemEnabled(this.sceneItemsByName[sceneItem].sceneName, this.sceneItemsByName[sceneItem].sceneItemId, this.Boolean(this.sceneItemsByName[sceneItem].sceneItemEnabled))
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/")

F9::obsc.toggleSceneItem("Video Capture Device")
F10::obsc.toggleSceneItem("Audio Input Capture")
F11::obsc.toggleSceneItem("Image")
F12::obsc.toggleSceneItem("Display Capture")
