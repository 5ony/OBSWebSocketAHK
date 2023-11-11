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

}

obsc := MyOBSController("ws://127.0.0.1:4455/")

F12::{
	global
	if (obsc.sceneItemId = -1)
		return
	obsc.isVisible := !obsc.isVisible
	obsc.SetSceneItemEnabled(obsc.sceneName, obsc.sceneItemId, obsc.Boolean(obsc.isVisible))
}