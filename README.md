# OBS WebSocket for AutoHotKey

Handling OBS Studio via WebSocket with AutoHotKey.

This AutoHotKey library handles OBS websocket version: 5.0.1

Basic functionality tested with OBS Studio 28.0.3 (64 bit)

You will need the following AHK libraries too:

- [G33kDude's Websocket.ahk](https://github.com/G33kDude/WebSocket.ahk)
- [Coco's JSON.ahk](https://github.com/cocobelgica/AutoHotkey-JSON)
- [ahkscript/libcrypt.ahk](https://github.com/ahkscript/libcrypt.ahk)

⚠ This code is under development. I do not expect breaking changes in the near future, and it works as it is right now.

All available OBS websocket functions are implemented, but not all tested.

[OBS websocket documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md) should be the no.1 resource when it comes to actions, events, parameters and data structures.

## 🤔 Why would you want to use this script?

Let be here some inspiration:

- Be right back! - Pressing one key (defined in AHK) to toggle the microphone, and a "Be right back" scene item (working example in this repo)

- activate a scene/item/filter when health is low in a game (by watching health bar pixels) or an effect is on

- changing to a "Score screen" opens a local excel table where results can be displayed, changed and shown to the audience; pressing another hotkey would change back the scene and close the excel

## 🙏 Gratitude

Thanks for [G33kDude's Websocket.ahk](https://github.com/G33kDude/WebSocket.ahk), [Coco's JSON.ahk](https://github.com/cocobelgica/AutoHotkey-JSON), all [ahkscript contributors](https://github.com/ahkscript) and of course OBS websocket and OBS Studio guys.

If you want to support me with a coffee, I thank you for that, you can do it here:

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/N4N6FX30H)

I am open for suggestions! Let me know what you think about this script or how can I improve it. Also, I would love to see what processes you have implemented with this script.

## 💥 Quick setup

- Download these codes, and put them under a lib directory
	- [OBSWebSocket.ahk](https://github.com/5ony/OBSWebSocketAHK/blob/main/lib/OBSWebSocket.ahk)
	- [WebSocket.ahk](https://github.com/G33kDude/WebSocket.ahk/blob/master/WebSocket.ahk)
	- [JSON.ahk](https://github.com/cocobelgica/AutoHotkey-JSON/blob/master/JSON.ahk)
	- [libcrypt.ahk](https://github.com/ahkscript/libcrypt.ahk/blob/master/build/libcrypt.ahk)

- Open OBS Studio, and navigate to Tools -> obs-websocket Settings, and leave the window open.
- Click on Show Connect Info button.
- Remove the Server Password. You can use it with password too, but it might be easier to try it without password. Also, all of the examples are without password.
- Copy the full IP address and port to your AHK script ("localhost:4455" will not be enough).
- You can close the "Websocket connect info" window, but keep the "obs-websocket Settings" window open.
- Create a simple script where the lib directory resides.

```
#Include lib/OBSWebSocket.ahk

obsc := new OBSWebSocket("ws://192.168.1.100:4455/")
```
- You can run your script and the OBS's Connected WebSocket Sessions list should show a new connection.

- For listening to OBS Studio responses and events you might want to create your own class of OBSWebSocket:

```
#Include lib/OBSWebSocket.ahk

class MyOBSController extends OBSWebSocket {
	; your complex functionality comes here
}

obsc := new MyOBSController("ws://192.168.1.100:4455/")

; or, if you are using password:
; obsc := new MyOBSController("ws://192.168.1.100:4455/", "YourPasswordHere")
```

## 🔄 Requests to OBS Studio

Requests towards OBS Studio usually have a response as well. Responses need a separate class method with the name of the request + 'Response'.

For example, checking OBS version:

```
class MyOBSController extends OBSWebSocket {

	AfterIdentified() {
		obsc.GetVersion()
	}

	GetVersionResponse(data) {
		; 🧙 do your magic with data here ✨
	}
}

obsc := new MyOBSController("ws://192.168.1.100:4455/")
```
Note that:
- `obsc.GetVersion()` (or any other method) cannot be called after creating a new OBSWebSocket instance, because the connection is still under negotiation. Connecting to OBS needs time, and when the connection is successful, `AfterIdentified()` method will be called (if it is defined).
- `obsc.GetVersion()` does not return anything in itself, a callback has to be defined as `GetVersionResponse()`

The received data contains the full response from OBS in AutoHotKey object format. For the data structure, consult the [OBS websocket documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md)

Every request is implemented with parameters. Object parameters handle AHK objects, but there is one exception; AHK's true and false values are only shorthands for 1 and 0 values. To circumvent this, true and false values should be handled as strings. To help this, you can use the Boolean() helper function (see example below).

This function will convert every (and I mean EVERY) outbound (towards OBS) string "true" and "false" values to JavaScript's true and false values. Note that because of this limitation, you cannot use "true" or "false" strings as text values when sending requests to OBS.

For example when muting the microphone:

```
obsc.SetInputMute("Mic/Aux", true) ; this will throw error

obsc.SetInputMute("Mic/Aux", "true") ; this is the way

obsc.SetInputMute("Mic/Aux", obsc.Boolean(true)) ; this is even better
```

## ⚡ Event handling

It is possible to subscribe to events coming from OBS at initialization. Check EventSubscription under OBSWebSocket.ahk for all the events. By default, events are dismissed to keep the unnecessary conversation between OBS and AHK on a minimum.

To subscibe to events, list them at the class initialization:
`obsc := new MyOBSController("ws://192.168.1.100:4455/", 0, MyOBSController.EventSubscription.Inputs | MyOBSController.EventSubscription.Scenes)`

Note the bitwise `|`, do not fall into the `||` or `&` or `&&` trap.

Events, similarly to the requests, need a function where data can be received. The function name should be event name + "Event". For example muting an input with `SetInputMute()` will emit an `InputMuteStateChanged` event; to handle that there should be an `InputMuteStateChangedEvent` function (method under your class) to handle the data sent by OBS.

```
class MyOBSController extends OBSWebSocket {
	InputMuteStateChangedEvent(data) {
		inputName := data.d.inputName
		inputMuted := data.d.inputMuted ? "muted 🔇" : "unmuted 🔊"
		MsgBox, %inputName% is now %inputMuted%
	}
}
```

## 🧐 Examples

Note that most (not all) of the examples can be done by defining hotkeys in OBS Studio. These examples are here just to give you the basic synax of triggers, events and responses.

### Toggle a scene (example-toggle-a-scene.ahk)

Simplest script to change scenes. If you do not want to receive any data, and do not care about any events, you do not need to create a new class.

```
#Include lib/OBSWebSocket.ahk

obsws := new OBSWebSocket("ws://192.168.1.100:4455/")
return

Numpad1::
obsws.SetCurrentProgramScene("Gaming with camera")
return

Numpad2::
obsws.SetCurrentProgramScene("Be right back")
return
```

### Toggle filter settings (example-filter-settings.ahk)

You need to add a source "Desktop" and apply a Color Correction and a Sharpen filter to it, otherwise there will be errors.

```
#Include lib/OBSWebSocket.ahk

obsc := new OBSWebSocket("ws://192.168.1.100:4455/")

F12::
	filterSettings := {"brightness":0.0, "color_add":0, "color_multiply":16777215, "contrast":4.0, "gamma":0.0, "hue_shift":180, "opacity":1.0, "saturation":0.0}
	obsc.SetSourceFilterSettings("Desktop", "Color Correction", filterSettings)

	filterSettings := {"sharpness":1.0}
	obsc.SetSourceFilterSettings("Desktop", "Sharpen", filterSettings)
	return
```


### Toggling microphone and scene with AHK hotkey

This script will allow you to toggle between two scenes and toggle the microphone at the same time by pressing F12.

Again, no need for extending the class, if a simple eventless and responseless mechanism is required.

```
#Include lib/OBSWebSocket.ahk

muted := false
obsws := new OBSWebSocket("ws://192.168.1.100:4455/")

F12::
	muted := !muted
	obsws.SetInputMute("Mic/Aux", obsws.Boolean(muted))
	obsws.SetCurrentProgramScene(muted ? "Gaming - muted" : "Gaming")
return
```


### Toggle a scene element (example-toggle-a-scene-element.ahk)

Scene items ("Sources" in OBS Studio) can be manipulated with a valid ID, and not by their names. To read the ID, first we have to find it by name on a given scene.

In the example below we will change the visibility of the "Webcamera" scene item under "Gaming" scene. 

```
#NoEnv
SetBatchLines, -1

#Include lib/OBSWebSocket.ahk

class MyOBSController extends OBSWebSocket {

	isVisible := true
	sceneName := "Gaming"
	sceneItemName := "Webcamera"
	sceneItemId := -1

	AfterIdentified() {
		; we have to get the Item ID under a Scene, because an ID (and not name) is needed for enabling/disabling the item
		this.GetSceneItemId(this.sceneName, this.sceneItemName)
	}

	; Here we receive the Item ID
	GetSceneItemIdResponse(data) {
		this.sceneItemId := data.d.responseData.sceneItemId
	}

}

obsc := new MyOBSController("ws://192.168.1.100:4455/")

F12::
	if (obsc.sceneItemId = -1)
		return
	obsc.isVisible := !obsc.isVisible
	obsc.SetSceneItemEnabled(obsc.sceneName, obsc.sceneItemId, obsc.Boolean(obsc.isVisible))
	return
```

### Toggling microphone with AHK hotkey or in OBS toggles scene (example-toggling-microphone-with-ahk-hotkey-or-obs-toggles-scene.ahk)

This script will allow you to change the scene when the microphone is muted with F12 (defined in this script), by clicking on the speaker icon in OBS, or by using an OBS hotkey.

```
#Include lib/OBSWebSocket.ahk

class MyOBSController extends OBSWebSocket {
	muted := false

	InputMuteStateChangedEvent(data) {
		; check if the mute change is about the microphone
		if (data.d.eventData.inputName = 'Mic/Aux') {
			this.muted := data.d.eventData.inputMuted
			this.SetCurrentProgramScene(this.muted ? "Gaming - muted" : "Gaming")
		}
	}
}

obsc := new MyOBSController("ws://192.168.1.100:4455/", 0, MyOBSController.EventSubscription.Input)

F12::
	obsc.SetInputMute("Mic/Aux", obsc.Boolean(!obsc.muted))
	return
```

In this case `SetInputMute()` will trigger OBS to mute/unmute, and OBS will send an `InputMuteStateChanged` event, which is handled by `EventInputMuteStateChanged()`.

You might think that using a `SetInputMuteResponse()` function would be enough to handle whether the microphone is muted or not, but that is only a response message for the mute request made from the AHK script, which means `SetInputMuteResponse()` would be called ONLY when calling `SetInputMute()` first, so muting/unmuting the input in OBS would not trigger `SetInputMuteResponse()`. By utilizing the event itself, the script above will trigger the scene change, whenever the microphone is muted from AHK or in OBS.

### Toggling microphone or scene triggers scene change and microphone toggle (example-toggling-microphone-or-scene-triggers-scene-change-and-microphone-toggle.ahk)

The difference between this and the previous one is that even if the scene is changed in OBS, now the microphone will be toggled as well, as well as muting/unmuting the microphone changes the active scene. So basically the microphone muted state and the scene visibility will be "linked".

```
#Include lib/OBSWebSocket.ahk

class MyOBSController extends OBSWebSocket {

	muted := false
	beRightBackSceneName := "Be right back"
	gamingSceneName := "Gaming"

	CurrentProgramSceneChangedEvent(data) {
		; check if the scene change should change the microphone too
		if ((data.d.eventData.sceneName = this.beRightBackSceneName && !this.muted) || (data.d.eventData.sceneName = this.gamingSceneName && this.muted)) {
			this.muted := !this.muted
			this.SetInputMute("Mic/Aux", this.Boolean(this.muted))
		}
	}

	InputMuteStateChangedEvent(data) {
		; check if the mute change is about the microphone
		if (data.d.eventData.inputName = "Mic/Aux") {
			; update global muted variable, so AHK have the same muted state as OBS
			this.muted := data.d.eventData.inputMuted
			this.SetCurrentProgramScene(this.muted ? this.beRightBackSceneName : this.gamingSceneName)
		}
	}
}

obsc := new MyOBSController("ws://192.168.1.100:4455/", 0, MyOBSController.EventSubscription.Inputs | MyOBSController.EventSubscription.Scenes)

F12::
	obsc.SetInputMute("Mic/Aux", obsc.Boolean(!obsc.muted))
return
```

The most important thing to notice here is that (after pressing F12) `SetInputMute()` triggers `EventInputMuteStateChanged()` which calls `SetCurrentProgramScene()` which triggers `EventCurrentProgramSceneChanged()` which calls `EventInputMuteStateChanged()` which... do you see the pattern here? It is an infinite loop.
Also, if the scene is changed, the infinite loop starts with `EventCurrentProgramSceneChanged()`, but the effect is the same. The runtime of infinite loops is quite long; I have not measured it yet, but it is close to the end of our known universe, or even worse, blue death of Windows, so let's not do that.

Here we skip the infinite loop by checking the muted state and the active scene. We could even get the active scene and the muted state of the microphone and check all of them at once, but I think it is a good practice not to trust the saved states of AHK variables, but to rely on the real states coming from OBS Studio. It is possible to write a more effective code than this, I just want to keep this here to for clarity (or for complexity?); I advice to run this code in your head, just go get familiar with requests and effect of events. The code below runs without infinite loop.

### Toggling all scene items in one scene (example-toggle-all-scene-elements.ahk)

Imagine the following setup in OBS

![Four scene items in one scene](example-toggle-all-scene-elements.jpg)

The scene name is Scene, and there are four different scene items (sources).
You can enable/disable the selected scene items with this script below with F9-F12.
Note that there is no mechanism implemented here to handle changes coming from OBS.

```
#NoEnv
SetBatchLines, -1

#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	sceneName := "Scene"
	sceneItemsByName := {}

	AfterIdentified() {
		this.GetSceneItemList(this.sceneName)
	}

	GetSceneItemListResponse(data) {
		For Key, sceneItemData in data.d.responseData.sceneItems
		{
			this.sceneItemsByName[sceneItemData.sourceName] := {enabled: sceneItemData.sceneItemEnabled, id: sceneItemData.sceneItemId, name: sceneItemData.sourceName}
		}
	}

	toggleSceneItem(sceneItem) {
		if (!this.sceneItemsByName[sceneItem]) {
			return
		}
		this.sceneItemsByName[sceneItem].enabled := !this.sceneItemsByName[sceneItem].enabled
		this.SetSceneItemEnabled(this.sceneName, this.sceneItemsByName[sceneItem].id, this.Boolean(this.sceneItemsByName[sceneItem].enabled))
	}

}

obsc := new MyOBSController("ws://192.168.1.68:4455/")

F9::obsc.toggleSceneItem("Video Capture Device")
F10::obsc.toggleSceneItem("Audio Input Capture")
F11::obsc.toggleSceneItem("Image")
F12::obsc.toggleSceneItem("Display Capture")
```

## 🔍 Debugging

### ✉ Websocket messages

Messages can be intercepted with [WireShark](https://www.wireshark.org).

Set the adapter to "Adapter for loopback traffic capture", set display filter to websocket. Use the script and if there is any messages between OBS and your script, it will be listed. You can check the message content. If the message content is masked, you can unmask it. Note that you might need the connection phase too for this to unmask the raw data.

### 🙂 Emojis

If you are using emojis (in scene names, input names, or just in general), make sure you save the files with "UTF-8 with BOM" option. This can be set even in Windows Notepad. You might just have been saved from "Scene not found" error messages.

## 🚧 To do (Might do)

* Screenshots from OBS settings, Wireshark and UTF-8 with BOM
* Connection with password
* Internet Explorer (websocket) throws error when connection is interrupted
* Automatic connection retry
* Automatic recovery from errors
* Test all functionalities