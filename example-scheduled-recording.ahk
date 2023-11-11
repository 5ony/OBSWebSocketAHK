#NoEnv
#Persistent
SetBatchLines, -1
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	StopRecordResponse(data) {
		outputPath := data.d.responseData.outputPath
		MsgBox, Recorded to %outputPath%
	}
}

obsc := new MyOBSController("ws://127.0.0.1:4455/")

timeToStart := 201500 ; 20:15:00, which is 8:15:00pm. If you want the script to start at 7:00:00am put change 201500 to 70000
FormatTime, timeToStart,,HHmmss
timeToStart := timeToStart + 5
SetTimer, ScheduledStartFunction, 500
Return

ScheduledStartFunction:
	FormatTime, timeToMeet,,HHmmss
	If (timeToMeet >= timeToStart && timeToMeet <= timeToStart+2) {
		obsc.StartRecord()
		SetTimer, ScheduledStartFunction, Off
		timeToStop := timeToStart + 5 ; will stop recording after 5 seconds
		SetTimer, ScheduledStopFunction, 500
	}
	Return

ScheduledStopFunction:
	FormatTime, timeToMeet,,HHmmss
	If (timeToMeet >= timeToStop && timeToMeet <= timeToStop+2) {
		obsc.StopRecord()
		SetTimer, ScheduledStopFunction, Off
	}
	Return
