#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	sceneName := "Scene"
	sceneItemName := "Image"
	sceneItemId := 0
	sceneItemTransform := {}

	AfterIdentified() {
		; for transforming a scene item, we need to know the scene ID, so we request it here
		this.GetSceneItemId(this.sceneName, this.sceneItemName)
	}

	GetSceneItemIdResponse(data) {
		this.__Debug(data)
		this.sceneItemId := data.d.responseData.sceneItemId
		; let's request for the base transform values
		this.GetSceneItemTransform(this.sceneName, this.sceneItemId)
	}

	GetSceneItemTransformResponse(data) {
		this.__Debug(data)
		; copying only those properties which we want to set
		this.sceneItemTransform.positionX := data.d.responseData.sceneItemTransform.positionX
		this.sceneItemTransform.positionY := data.d.responseData.sceneItemTransform.positionY
		this.sceneItemTransform.rotation := data.d.responseData.sceneItemTransform.rotation
		this.sceneItemTransform.scaleX := data.d.responseData.sceneItemTransform.scaleX
		this.sceneItemTransform.scaleY := data.d.responseData.sceneItemTransform.scaleY
	}

	moveItem(deltaX, deltaY) {
		this.sceneItemTransform.positionX := this.sceneItemTransform.positionX + deltaX
		this.sceneItemTransform.positionY := this.sceneItemTransform.positionY + deltaY
		this.SetSceneItemTransform(this.sceneName, this.sceneItemId, this.sceneItemTransform)
	}

	rotateItem(deltaRotation) {
		this.sceneItemTransform.rotation := this.sceneItemTransform.rotation + deltaRotation
		if (this.sceneItemTransform.rotation < 0) {
			this.sceneItemTransform.rotation := this.sceneItemTransform.rotation + 360
		}
		if (this.sceneItemTransform.rotation > 360) {
			this.sceneItemTransform.rotation := this.sceneItemTransform.rotation - 360
		}
		this.SetSceneItemTransform(this.sceneName, this.sceneItemId, this.sceneItemTransform)
	}

	scaleItem(deltaScaleX, deltaScaleY) {
		this.sceneItemTransform.scaleX := this.sceneItemTransform.scaleX + deltaScaleX
		this.sceneItemTransform.scaleY := this.sceneItemTransform.scaleY + deltaScaleY
		this.SetSceneItemTransform(this.sceneName, this.sceneItemId, this.sceneItemTransform)
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/")

Numpad1::obsc.moveItem(-5,5)
Numpad2::obsc.moveItem(0,5)
Numpad3::obsc.moveItem(5,5)
Numpad4::obsc.moveItem(-5,0)
Numpad6::obsc.moveItem(5,0)
Numpad7::obsc.moveItem(-5,-5)
Numpad8::obsc.moveItem(0,-5)
Numpad9::obsc.moveItem(5,-5)
NumpadAdd::obsc.rotateItem(5)
NumpadSub::obsc.rotateItem(-5)
NumpadMult::obsc.scaleItem(0.1, 0.1)
NumpadDiv::obsc.scaleItem(-0.1, -0.1)
