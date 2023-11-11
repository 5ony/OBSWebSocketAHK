/**
 * Bar_sony twitch channel controller script
 *
 * 🔃 Updated: 2023-11-10 (YYYY-MM-DD)
 *
 * ⚠ Requirements:
 *   Latest version of AutoHotkey (v2.0+)
 *   ObsWebSocket.ahk (and its requirements) - https://github.com/5ony/OBSWebSocketAHK
 *
 * ❓ What does this script do:
 *  - when muting my microphone, it will show a GUI with red background and will set the
 *    LED strips to red. If there is no IP address like that, this can slow the whole script.
 *  - unmuting will remove the GUI and set the LED strip to green temporarily
 *  - un/muting can happen with hotkey or in OBS.
 *  - if the mic is muted when OBS and this script starts, the red GUI is shown
 *  - numpad keys activate some items (gif memes) in order.
 *    The order is not random, but sequential to show variance.
 *  - all sceneitems and some named inputs state is tracked and synchrnoized,
 *    even though it is not necessarily needed. However, I have nested scenes, where I show
 *    a scene item, then disabling it (the meme part). So in order to do that, I just read
 *    every scene items from every scenes.
 *  - some housekeeping is added (when changing profile, removing or adding scenes/items),
 *    but if there were any organization on the scenes, it is just better to restart the script.
 *
 *
 * 🚧 To Do:
 *  - if an input name is changed, let's change in the inputs variable as well (InputNameChangedEvent)
 *  - handle InputActiveStateChangedEvent and InputShowStateChangedEvent
 *
 * 🔗 Links:
 *   GitHub: https://github.com/5ony/OBSWebSocketAHK
 *   Buy me a coffee: https://ko-fi.com/barsony
 */

#Requires AutoHotkey >=2.0-
#Include lib/OBSWebSocket.ahk

showNumpadHelper()

sceneNames := {
	gamingSceneName: "🎮📷 Gaming with cam [PgDn]",
	 memeSceneName : "Effect - Gaming - meme",
	          empty: "Empty",
	       starting: "▶ Stream start - [F11]",
	         ending: "⏹ Stream end",
	       breaking: "⏸ Gaming szünet [End]"
}

class MyOBSController extends ObsWebSocket {

	currentProgramSceneName := ""
	scenes := Map()
	inputs := Map()
	_initedScenes := Map()
	isInited := false
	microphoneName := "🎤Mikrofon"
	state := ""

	AfterIdentified() {
		this._initedScenes := Map()
		this.GetSceneList()

		this.inputs := Map()
		this.GetInputList()
	}

	; we have to read all scenes first then all items one by one
	GetSceneListResponse(data) {
		this.currentProgramSceneName := data.d.responseData.currentProgramSceneName
		For Key, sceneData in data.d.responseData.scenes {
			this.scenes[sceneData.sceneName] := Map()
			this._initedScenes[sceneData.sceneName] := 0
			this.GetSceneItemList(sceneData.sceneName, sceneData.sceneName)
		}
	}

	; read all scene items of one scene
	GetSceneItemListResponse(data) {
		receivedSceneName := data.d.requestId
		this._initedScenes[receivedSceneName] := 1
		For Key, sceneItemData in data.d.responseData.sceneItems
		{
			this.scenes[receivedSceneName][sceneItemData.sourceName] := sceneItemData
		}

		if (this.isAllScenesInited()) {
			isInited := true
		}
	}

	; check if all scenes are read
	isAllScenesInited() {
		For sceneName, scene in this.scenes {
			if (!this._initedScenes[sceneName]) {
				return false
			}
		}
		return true
	}

	; set default muted states of certain input devices
	; except the named microphone, where we will get the muted status
	GetInputListResponse(data) {
		For index, inputItem in data.d.responseData.inputs {
			if (inputItem.inputName = this.microphoneName) {
				this.GetInputMute(inputItem.inputName, inputItem.inputName)
			} else if (inputItem.inputName = "Audio - Discord" || inputItem.inputName = "Audio - Game" || inputItem.inputName = "Audio - Vivaldi") {
				this.SetInputMute(inputItem.inputName, this.Boolean(false))
			} else if (inputItem.inputName = "Mic/Aux" || inputItem.inputName = "Desktop Audio") {
				this.SetInputMute(inputItem.inputName, this.Boolean(true))
			}
		}
	}

	GetInputMuteResponse(data) {
		inputName := data.d.requestId
		this.inputs[data.d.requestId] := data.d.responseData.inputMuted

		; show a gui depending on the named microphone status
		if (inputName = this.microphoneName) {
			this.showMutedGUI(data.d.responseData.inputMuted)
		}
	}

	; ---- housekeeping functions
	; scene/sceneitem/input changed, name changes, profile changes
	CurrentSceneCollectionChangedEvent(data) {
		this.AfterIdentified()
	}
	CurrentProfileChangedEvent(data) {
		this.AfterIdentified()
	}
	CurrentProgramSceneChangedEvent(data) {
		this.currentProgramSceneName := data.d.eventData.sceneName
	}
	SceneItemCreatedEvent(data) {
		; creating a sceneItem will reinitialize/reread the scene where the enabling/disabling happened
		this._initedScenes[data.d.eventData.sceneName] := 0
		isInited := false
		this.GetSceneItemList(data.d.eventData.sceneName, data.d.eventData.sceneName)
	}
	SceneItemRemovedEvent(data) {
		; no need to read the whole list, but some housekeeping is needed
		this.scenes[data.d.eventData.sceneName].Delete(data.d.eventData.sourceName)
	}
	SceneNameChangedEvent(data) {
		; copy data from old local variables to a new one with a new name
		oldSceneName := data.d.eventData.oldSceneName
		sceneName := data.d.eventData.sceneName
		this._initedScenes[sceneName] := this._initedScenes[oldSceneName]
		this._initedScenes.Delete(oldSceneName)
		this.scenes[sceneName] := this.scenes[oldSceneName]
		this.scenes.Delete(oldSceneName)
	}
	InputNameChangedEvent(data) {
		; TODO
	}

	; ---- Enabling/disabling/muting events here
	SceneItemEnableStateChangedEvent(data) {
		sceneName := data.d.eventData.sceneName
		sceneItemName := this.findSceneItemById(sceneName, data.d.eventData.sceneItemId)
		if (this.scenes[sceneName][sceneItemName].sceneItemId = data.d.eventData.sceneItemId) {
			this.scenes[sceneName][sceneItemName].sceneItemEnabled := data.d.eventData.sceneItemEnabled
			; if you need to check whether a sceneItem of a certain scene is enabled/disabled, here is the place
			; msgBox % this.scenes[sceneName][sceneItemName].sceneItemEnabled
		}
	}

	InputMuteStateChangedEvent(data) {
		this.inputs[data.d.eventData.inputName] := data.d.eventData.inputMuted
		; if you need to check whether an input is muted/unmuted, here is the place
		if (data.d.eventData.inputName = this.microphoneName) {
			this.showMutedGUI(data.d.eventData.inputMuted)
		}
	}

	InputActiveStateChangedEvent(data) {
		; TODO
		;data.d.eventData.inputName
		;data.d.eventData.videoActive
	}
	InputShowStateChangedEvent(data) {
		; TODO
		;data.d.eventData.inputName
		;data.d.eventData.videoShowing
	}

	findSceneItemById(sceneName, sceneItemId) {
		if (!this.scenes[sceneName]) {
			return 0
		}
		For sceneItemName, sceneItem in this.scenes[sceneName] {
			if (sceneItem.sceneItemId = sceneItemId) {
				return sceneItem.sourceName
			}
		}
		return 0
	}

	; ---- Scene and scene item change helpers
	toggleSceneItem(sceneName, sceneItemName, isVisible := -1) {
		if (!this.scenes[sceneName] || !this.scenes[sceneName][sceneItemName]) {
			return
		}
		this.SetSceneItemEnabled(sceneName, this.scenes[sceneName][sceneItemName].sceneItemId, this.Boolean(isVisible))
	}

	sceneItemShow(sceneName, sceneItem) {
		this.toggleSceneItem(sceneName, sceneItem, 1)
	}

	sceneItemHide(sceneName, sceneItem) {
		this.toggleSceneItem(sceneName, sceneItem, 0)
	}

	showSceneDelayed(sceneName, sceneItem, delayTime) {
		this.sceneItemShow(sceneName, sceneItem)
		Sleep(delayTime)
		this.sceneItemHide(sceneName, sceneItem)
	}

	changeScene(sceneName) {
		this.SetCurrentProgramScene(sceneName)
	}

	; shows a mute sign with red background in top right of the secondary screen
	showMutedGUI(isMuted) {
		static ShowMutedState := 0
		if (isMuted) {
			if (ShowMutedState) {
				ShowMutedState.Show()
				return
			}
			ShowMutedState := Gui()
			ShowMutedState.Opt("-Border -Caption +Disabled +AlwaysOnTop +ToolWindow")
			ShowMutedState.MarginX := 0
			ShowMutedState.MarginY := 0
			ShowMutedState.BackColor := "FF0000"
			ShowMutedState.SetFont("s64 cFFFFFF", "Segoe UI Emoji")
			ShowMutedState.Add("Text", "", "🔇")
			ShowMutedState.Show("x-120 y50 NoActivate")
			this.sendColorToLedStrip("C0074FF0000")
		} else {
			if (ShowMutedState) {
				ShowMutedState.Destroy()
			}
			this.sendColorToLedStrip("C007400FF00")
			Sleep(100)
			this.sendColorToLedStrip("R")
		}
	}

	; updates LED strip color
	sendColorToLedStrip(ledControlParams) {
		Try {
			whr := ComObject("WinHttp.WinHttpRequest.5.1")
			whr.SetTimeouts(500, 500, 100, 100)
			whr.Open("GET", "http://192.168.1.116?led=" . ledControlParams)
			whr.Send()
		} Catch Error as err
		{
			; noop, no success = no problem
		}
	}

	streamingStart() {
		this.SetCurrentProgramScene("Empty")
		Sleep(1000)
		this.StartStream()
		Sleep(2000)
		this.SetCurrentProgramScene("▶ Stream start - [F11]")
		Sleep(96000) ; 1:35
		this.SetCurrentProgramScene("🎮📷 Gaming with cam [PgDn]")
	}

	streamingEnd() {
		this.SetCurrentProgramScene("⏹ Stream end")
		Sleep(30000) ; 0:30
		this.StopStream()
	}
}

showGifMeme(sceneItemPreName, sceneItemCount) {
	global
	seq := seq + 1
	sceneItemName := sceneItemPreName . (Mod(seq, sceneItemCount) + 1) . ".gif"
	obsc.showSceneDelayed(sceneNames.memeSceneName, sceneItemName, 4000)
}

showNumpadHelper() {
	Run("E:\Munka\obs-websocket-ahk-dev\barsony-handcrafted-keys.jpg")
	WinWaitActive("ahk_exe i_view64.exe")
	WinMove(-827, 146, 221, 412)
}

events := MyOBSController.EventSubscription.Config | MyOBSController.EventSubscription.Scenes | MyOBSController.EventSubscription.SceneItems | MyOBSController.EventSubscription.InputActiveStateChanged | MyOBSController.EventSubscription.InputShowStateChanged | MyOBSController.EventSubscription.Inputs
obsc := MyOBSController("ws://127.0.0.1:4455/","", events)

; a sequential counter for not showing the same meme in a row in a meme group
seq := 0

; changing scenes
#Insert::obsc.streamingStart()
#Delete::obsc.streamingEnd()

; muting audio inputs
+NumpadAdd::obsc.SetInputMute("🎤Mikrofon", obsc.Boolean(false))
NumpadAdd::obsc.SetInputMute("🎤Mikrofon", obsc.Boolean(true))
+NumpadSub::obsc.SetInputMute("Audio - Vivaldi", obsc.Boolean(false))
NumpadSub::obsc.SetInputMute("Audio - Vivaldi", obsc.Boolean(true))
+NumpadMult::obsc.SetInputMute("Audio - Discord", obsc.Boolean(false))
NumpadMult::obsc.SetInputMute("Audio - Discord", obsc.Boolean(true))
+NumpadDiv::obsc.SetInputMute("Audio - Game", obsc.Boolean(false))
NumpadDiv::obsc.SetInputMute("Audio - Game", obsc.Boolean(true))

; kill
Numpad1::{
	global
	seq := seq + 1
	if (Mod(seq, 3) = 0)
		obsc.showSceneDelayed(sceneNames.memeSceneName, "meme - yeahboi", 2000)
	if (Mod(seq, 3) = 1)
		obsc.showSceneDelayed(sceneNames.memeSceneName, "meme - nice", 2500)
	if (Mod(seq, 3) = 2)
		obsc.showSceneDelayed(sceneNames.memeSceneName, "meme - kaboom-kaboom", 3000)
	return
}
; 👊 execute / hit
Numpad2::showGifMeme("hit_", 7)

; 🤔 confused
Numpad3::showGifMeme("confused_", 19)

; 😨 panic
Numpad4::{
	global
	seq := seq + 1
	if (!Mod(seq, 8)) {
		obsc.showSceneDelayed(sceneNames.memeSceneName, "meme - hit markers", 3500)
	} else {
		obsc.showSceneDelayed(sceneNames.memeSceneName, "panic_" . (Mod(seq, 3) + 1) . ".gif", 4000)
	}
	return
}

; 🏃‍ running away
Numpad5::showGifMeme("running_away_", 4)

; 💀 dead
Numpad6::{
	global
	seq := seq + 1
	if (Mod(seq, 4) = 0)
		obsc.showSceneDelayed(sceneNames.memeSceneName, "meme - to be continued", 10000)
	if (Mod(seq, 4) = 1)
		obsc.showSceneDelayed(sceneNames.memeSceneName, "meme - emotional damage", 4000)
	if (Mod(seq, 4) = 2)
		obsc.showSceneDelayed(sceneNames.memeSceneName, "meme - coffin dance", 11000)
	if (Mod(seq, 4) = 3) {
		obsc.SetCurrentProgramScene("Effect - Gaming - we'll be right back")
		Sleep(4000)
		obsc.SetCurrentProgramScene(sceneNames.gamingSceneName)
	}
	return
}
; 🥇 golden loot
Numpad8::showGifMeme("gold_loot_", 7)

; 👜 carry
Numpad9::showGifMeme("carry_", 7)

