#NoEnv
SetBatchLines, -1

#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {}

obsc := new MyOBSController("ws://127.0.0.1:4455/")

F1::
	obsc.StopVirtualCam()
	obsc.SetCurrentSceneCollection("Untitled")
	Sleep, 1000
	obsc.StartVirtualCam()
return
F2::
	obsc.StopVirtualCam()
	obsc.SetCurrentSceneCollection("handcrafted bar-sony")
	Sleep, 1000
	obsc.StartVirtualCam()
return
