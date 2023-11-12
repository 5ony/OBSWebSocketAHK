#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends OBSWebSocket {

	isVisible := true
	sceneName := "SceneA"
	sceneItemName := "ItemAC"
	sceneItemId := -1

	AfterIdentified() {
		; we have to get the Item ID under a Scene, because an ID (and not name) is needed for enabling/disabling the item
		this.GetSceneItemId(this.sceneName, this.sceneItemName)
	}

	; Here we receive the Item ID
	GetSceneItemIdResponse(data) {
		this.sceneItemId := data.d.responseData.sceneItemId
	}

	toggleSceneItem() {
		if (this.sceneItemId = -1)
			return
		this.isVisible := !this.isVisible
		this.SetSceneItemEnabled(this.sceneName, this.sceneItemId, this.Boolean(this.isVisible))
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/")

F12::obsc.toggleSceneItem()