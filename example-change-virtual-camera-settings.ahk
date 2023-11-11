#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

obsc := ObsWebSocket("ws://127.0.0.1:4455/")

; If the virtual camera is off and StopVirtualCam() is called, an error will be thrown (but the script will continue)

F1::{
	global
	obsc.StopVirtualCam()
	obsc.SetCurrentSceneCollection("Untitled")
	Sleep(1000)
	obsc.StartVirtualCam()
}
F2::{
	global
	obsc.StopVirtualCam()
	obsc.SetCurrentSceneCollection("handcrafted bar-sony")
	Sleep(1000)
	obsc.StartVirtualCam()
}