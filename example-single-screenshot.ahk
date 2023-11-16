#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {
	startScreenShot(sceneName) {
		this.SaveSourceScreenshot(sceneName, "jpg", "c:\OBSscreenShots\screenshot.jpg")
	}
}

obsc := new MyOBSController("ws://127.0.0.1:4455/", "")

F11::obsc.startScreenShot("Scene1")
F12::obsc.startScreenShot("Scene2")

