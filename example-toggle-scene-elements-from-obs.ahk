#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	sceneName := "Scene"
	sceneItemsByName := Map()

	AfterIdentified() {
		this.GetSceneItemList(this.sceneName)
	}

	GetSceneItemListResponse(data) {
		; data format is defined here:		
		; https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#getsceneitemlist
		For Key, sceneItemData in data.d.responseData.sceneItems
		{
			this.sceneItemsByName[sceneItemData.sourceName] := {enabled: sceneItemData.sceneItemEnabled, id: sceneItemData.sceneItemId, name: sceneItemData.sourceName}
		}
	}

	findSceneItemNameById(sceneItemId) {
		for (key, value in this.sceneItemsByName) {
			if (sceneItemId = value.id) {
				return value.name
			}
		}
		return ""
	}

	toggleSceneItem(sceneItem) {
		if (!this.sceneItemsByName.Has(sceneItem)) {
			return
		}
		this.sceneItemsByName[sceneItem].enabled := !this.sceneItemsByName[sceneItem].enabled
		this.SetSceneItemEnabled(this.sceneName, this.sceneItemsByName[sceneItem].id, this.Boolean(this.sceneItemsByName[sceneItem].enabled))
	}

	SceneItemEnableStateChangedEvent(data) {
		; data format is defined here:
		; https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#sceneitemenablestatechanged

		; if the scene name is the same as we defined earlier, we can act
		if (data.d.eventData.sceneName = this.sceneName) {

			sceneItemName := this.findSceneItemNameById(data.d.eventData.sceneItemId)
			if (!sceneItemName) {
				return
			}
			; let's save the current scene item visibility, just so AHK will remember it too
			this.sceneItemsByName[sceneItemName].enabled := data.d.eventData.sceneItemEnabled

			; if "Audio Input Capture" scene item is enabled/disabled in OBS, we will trigger "Video Capture Device" to behave the same
			if (data.d.eventData.sceneItemId = this.sceneItemsByName["Audio Input Capture"].id &&
				this.sceneItemsByName["Video Capture Device"].enabled != data.d.eventData.sceneItemEnabled) {
				; note that calling SetSceneItemEnabled will trigger OBS to send a SceneItemEnableStateChanged event
				this.SetSceneItemEnabled(this.sceneName, this.sceneItemsByName["Video Capture Device"].id, this.Boolean(data.d.eventData.sceneItemEnabled))
			}
			if (data.d.eventData.sceneItemId = this.sceneItemsByName["Video Capture Device"].id &&
				this.sceneItemsByName["Audio Input Capture"].enabled != data.d.eventData.sceneItemEnabled) {
				this.SetSceneItemEnabled(this.sceneName, this.sceneItemsByName["Audio Input Capture"].id, this.Boolean(data.d.eventData.sceneItemEnabled))
			}
		}
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/", 0, MyOBSController.EventSubscription.SceneItems )

F9::obsc.toggleSceneItem("Video Capture Device")
F10::obsc.toggleSceneItem("Audio Input Capture")
F11::obsc.toggleSceneItem("Image")
F12::obsc.toggleSceneItem("Display Capture")
