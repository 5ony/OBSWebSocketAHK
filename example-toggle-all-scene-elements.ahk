#NoEnv
SetBatchLines, -1

#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	sceneName := "Scene"
	sceneItemsByName := {}

	AfterIdentified() {
		this.GetSceneItemList(this.sceneName)
	}

	GetSceneItemListResponse(data) {
		For Key, sceneItemData in data.d.responseData.sceneItems
		{
			this.sceneItemsByName[sceneItemData.sourceName] := {enabled: sceneItemData.sceneItemEnabled, id: sceneItemData.sceneItemId, name: sceneItemData.sourceName}
		}
	}

	toggleSceneItem(sceneItem) {
		if (!this.sceneItemsByName[sceneItem]) {
			return
		}
		this.sceneItemsByName[sceneItem].enabled := !this.sceneItemsByName[sceneItem].enabled
		this.SetSceneItemEnabled(this.sceneName, this.sceneItemsByName[sceneItem].id, this.Boolean(this.sceneItemsByName[sceneItem].enabled))
	}

}

obsc := new MyOBSController("ws://192.168.1.68:4455/")

F9::obsc.toggleSceneItem("Video Capture Device")
F10::obsc.toggleSceneItem("Audio Input Capture")
F11::obsc.toggleSceneItem("Image")
F12::obsc.toggleSceneItem("Display Capture")
