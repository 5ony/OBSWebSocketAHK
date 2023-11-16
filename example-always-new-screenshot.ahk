#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {
	fnIndex := 0

	startScreenShot(sceneName) {
		this.fnIndex += 1

		; directory should be already created
		fileName := "c:\OBSscreenshots\screenshot" . this.fnIndex . ".jpg"

		; we use the fileName as a requestId, so we will know which file is used for screenshot
		requestId := fileName 
		this.SaveSourceScreenshot(sceneName, "jpg", fileName, 0, 0, 0, requestId)
	}

	SaveSourceScreenshotResponse(data) {
		; ItemAC is an image source already on the current scene
		this.SetInputSettings("ItemAC", {file: data.d.requestId})
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/", "")

F11::obsc.startScreenShot("SceneA")
F12::obsc.startScreenShot("SceneB")

