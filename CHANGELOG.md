### v2.1.1 - 2024-10-21

- added OBSWebSocketAHK-helper.ahk [OBSWebSocketAHK-helper.md](https://github.com/5ony/OBSWebSocketAHK/blob/main/OBSWebSocketAHK-helper.md)
- renamed DebugConsole() to StartDebugConsole()
- fixed minor bugs in examples

### v2.1.0 - 2024-10-06

- added DebugConsole() to show messages between OBS and AHK (for usage, see [Debugging Message data with internal console](#debugging-message-data-with-internal-console))
- separated change log to CHANGELOG.md

### v2.0.7

- added `SplitRecordFile()`, `CreateRecordChapter()`, `GetSceneItemSource()` methods
- added value restrictions
- added `__Min()`, `__Max()`, `__MinMax()`, `__Debug()` internal methods
- fixed `GetProfileList()`, `GetRecordDirectory()`, `GetGroupList()` parameter list
- added example for transforming a scene item

### v2.0.6

- fixed `SetInputVolume()`

### v2.0.5

- added `SetRecordDirectory()` and `GetSourceFilterKindList()`
- added example about enabling filters
- updated `TriggerHotkeyByName()` with contextName
- updated event codes
- possibility to use UUIDs instead of "names" if required i.e. sceneName vs sceneUuid. If a parameter value, which is a "name" looks like a UUID, it will be used as a UUID. Affected names: sceneName, sourceName, inputName, destinationSceneName, transitionName, currentProgramSceneName, currentPreviewSceneName, currentSceneTransitionName.

### v2.0.4

- added `SetSilentMode()` to enable/disable tray tips.
- modified event functions: "Event" is not required in the name of the function. I.e. instead of `InputMuteStateChangedEvent()` you can use `InputMuteStateChanged()`. At the moment it is backward compatible, but functions with "Event" will be deprecated. If `InputMuteStateChangedEvent()` and `InputMuteStateChanged()` exist in the same script, the former (with Event) will be ignored and latter (without Event) will be executed.

### v2.0.3

- added `RetryConnection()` to retry a closed connection
- added `GetWebSocketState()` to get the standard WebSocket.readyState value
- added `IsWebSocketAlive()` to check whether the connection is opened
- modified `Send()`; if connection is closed, retry connecting and retry sending the same request
- modified error handling, does not exit on error

### v2.0.2

- fixed OpenSourceProjector() wrong and missing parameters

### v2.0.0

- rewritten for AutoHotKey v2.0
- merged websocket handling to remove library dependency
- changed libraries
- changed MsgBox popups to a more elegant TrayTip notification
- added more examples

### 🚧 To do (Might do)

* Create a script to list all input types and filter settings
* Create synchronous calls (if possible)
* Better true/false values
* Screenshots from the OBS setup, Wireshark and UTF-8 with BOM
* Make an example script to be usable in a general OBS scene setup
* Test all functionalities
* Shorter documentation