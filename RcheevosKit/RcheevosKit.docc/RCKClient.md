# ``Client``

Provides a wrapper around `rc_client_t`.

## Overview



## Topics

### Initialization

- ``Client/init()``

### User Account stuff
- ``Client/delegate``
- ``Client/loginWith(userName:password:)``
- ``Client/loginWith(userName:token:)``
- ``Client/logout()``
- ``Client/isLoggedIn``
- ``Client/loginToken``
- ``Client/userInfo()``
- ``Client/reset()``

### Getters/setters
- ``Client/hardcoreMode``
- ``Client/encoreMode``
- ``Client/useUnofficialAchievements``
- ``Client/spectatorMode``
- ``Client/hasLeaderboards``

### Game Handling
- ``Client/doFrame()``
- ``Client/idling()``
- ``Client/loadGame(from:console:)-6fzag``
- ``Client/loadGame(from:console:)-6gm0s``
- ``Client/changeMedia(to:)-1bzw0``
- ``Client/changeMedia(to:)-5l03g``
- ``Client/isGameLoaded``
- ``Client/unloadGame()``
- ``Client/LoadingGameState``
- ``Client/getLoadingGameState()``
- ``Client/UserGameSummary``
- ``Client/userGameSummary()``
- ``Client/clientCanPause(remainingFrames:)``

### State Saving
- ``Client/captureRetroAchievementsState()``
- ``Client/restoreRetroAchievementsState(from:)``

### Logging
- ``Client/LogLevel``
- ``Client/enableLogging(level:)``

### Achievement Tracking
- ``Client/achievementsList(category:grouping:)``
- ``Client/gameInfo()``
- ``Client/UserProgressEntry``
- ``Client/allUserProgress(for:)``
- ``Client/subsetInfo(_:)``

### Rich Presence
- ``Client/hasRichPresence``
- ``Client/richPresenceMessage``
