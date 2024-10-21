#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	isVisible := false
	sceneName := "Scene1"
	sceneItemName := "Image"
	sceneItemId := -1

	AfterIdentified() {
		; we have to get the Item ID under a Scene, because an ID (and not name) is needed for enabling/disabling the item
		this.GetSceneItemId(this.sceneName, this.sceneItemName)
	}

	; Here we receive the Item ID
	GetSceneItemIdResponse(data) {
		this.sceneItemId := data.d.responseData.sceneItemId
		this.toggleSceneItem(false)
	}

	toggleSceneItem(isVisible) {
		if (this.sceneItemId = -1)
			return
		this.SetSceneItemEnabled(this.sceneName, this.sceneItemId, this.Boolean(isVisible))
	}

	startScreenShot(sceneName) {
		this.SaveSourceScreenshot(sceneName, "jpg", "e:/Munka/OBSWebSocketAHK/screenshots/screenshot.jpg")
	}

	SaveSourceScreenshotResponse(data) {
		this.isVisible := !this.isVisible
		this.toggleSceneItem(this.isVisible)
	}
}

obsc := MyOBSController("ws://127.0.0.1:4455/", "")

#1::obsc.startScreenShot("Scene1")
#2:: {
	obsc.isVisible := false
	obsc.toggleSceneItem(obsc.isVisible)
}

