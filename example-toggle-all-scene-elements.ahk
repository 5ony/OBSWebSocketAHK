#NoEnv
SetBatchLines, -1

#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	sceneName := "Scene"
	sceneItemsByName := {}

	AfterIdentified() {
		; we should save the sceneName, so we pass it as a requestId
		this.GetSceneItemList(this.sceneName, this.sceneName)
	}

	GetSceneItemListResponse(data) {
		this.sceneItemListResponseArrived(data)
	}

	GetGroupSceneItemListResponse(data) {
		this.sceneItemListResponseArrived(data)
	}

	sceneItemListResponseArrived(data) {
		For Key, sceneItemData in data.d.responseData.sceneItems
		{
			; let's save the sceneName as well, because activating scene items
			; under groups will need the group name, which is the sceneName
			this.sceneItemsByName[sceneItemData.sourceName] := sceneItemData
			this.sceneItemsByName[sceneItemData.sourceName].sceneName := data.d.requestId

			; if the scene is a group, it should be 
			if (sceneItemData.isGroup = 1) {
				; we should save the sceneName, so we pass it as a requestId
				this.GetGroupSceneItemList(sceneItemData.sourceName, sceneItemData.sourceName)
			}
		}		
	}

	toggleSceneItem(sceneItem) {
		if (!this.sceneItemsByName[sceneItem]) {
			return
		}
		this.sceneItemsByName[sceneItem].sceneItemEnabled := !this.sceneItemsByName[sceneItem].sceneItemEnabled
		this.SetSceneItemEnabled(this.sceneItemsByName[sceneItem].sceneName, this.sceneItemsByName[sceneItem].sceneItemId, this.Boolean(this.sceneItemsByName[sceneItem].sceneItemEnabled))
	}

}

obsc := new MyOBSController("ws://127.0.0.1:4455/")

F9::obsc.toggleSceneItem("Video Capture Device")
F10::obsc.toggleSceneItem("Audio Input Capture")
F11::obsc.toggleSceneItem("Image")
F12::obsc.toggleSceneItem("Display Capture")
