#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {
	score := 0

	AfterIdentified() {
		this.SetScore(this.score)
	}

	SetScore(scoreResult) {
		; because 0 should be shown as a text, and number 0 is not a visible string in AHK,
		; we need to change the number to string
		this.SetInputSettings("TextItem", {text: "Score: " . String(scoreResult)})
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/")

NumpadAdd:: {
	global
	obsc.score := obsc.score + 1
	obsc.SetScore(obsc.score)
}

NumpadSub:: {
	global
	obsc.score := obsc.score - 1
	obsc.SetScore(obsc.score)
}