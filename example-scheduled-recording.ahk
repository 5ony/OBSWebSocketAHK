﻿#Requires AutoHotkey >=2.0-
#Include "lib/ObsWebSocket.ahk"

class MyOBSController extends ObsWebSocket {

	AfterIdentified() {
		this.timeToStart := 201500 ; 20:15:00, which is 8:15:00pm. If you want the script to start at 7:00:00am, change it to 70000
		this.timeToStop :=  this.timeToStart + 5 ; will record 5 seconds
		; timers are funky in classes, see https://www.autohotkey.com/docs/v2/lib/SetTimer.htm#ExampleClass
		this.startTimer := ObjBindMethod(this,"ScheduledStart")
		this.stopTimer := ObjBindMethod(this,"ScheduledStop")
		SetTimer(this.startTimer, 500)
	}

	StopRecordResponse(data) {
		outputPath := data.d.responseData.outputPath
		MsgBox("Recorded to " outputPath)
	}

	ScheduledStart() {
		timeNow := FormatTime(, "HHmmss")
		If (this.timeToStop <= timeNow) {
			SetTimer(this.startTimer, 0)
			MsgBox("Stop time already passed")
			this.Disconnect()
			ExitApp
		}
		If (timeNow >= this.timeToStart && timeNow <= this.timeToStart + 2) {
			SetTimer(this.startTimer,0)
			this.StartRecord()
			SetTimer(this.stopTimer, 500)
		}
	}

	ScheduledStop() {
		timeNow := FormatTime(, "HHmmss")
		If (timeNow >= this.timeToStop && timeNow <= this.timeToStop + 2) {
			this.StopRecord()
			SetTimer(this.stopTimer,0)
			this.Disconnect()
			ExitApp
		}
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/")

; this is just for keeping the script alive
F24:: x := 1