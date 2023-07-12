#NoEnv
SetBatchLines, -1

#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {
	score := 0

	AfterIdentified() {
		this.SetScore(this.score)
	}

	SetScore(scoreResult) {
		; because 0 is not a visible string in AHK, we change it to text
		if (!scoreResult) {
			scoreResult := "0"
		}
		this.SetInputSettings("TextItem", {text: "Score: " . scoreResult})
	}

}

obsc := new MyOBSController("ws://127.0.0.1:4455/")

NumpadAdd::
	obsc.score := obsc.score + 1
	obsc.SetScore(obsc.score)
return

NumpadSub::
	obsc.score := obsc.score - 1
	obsc.SetScore(obsc.score)
return