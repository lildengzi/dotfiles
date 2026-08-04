import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string navidromeUrl: pluginData.navidromeUrl ?? ""
    property string navidromeUser: pluginData.navidromeUser ?? ""
    property string navidromePassword: pluginData.navidromePassword ?? ""
    property bool cachingEnabled: pluginData.cachingEnabled ?? true
    property string playerWhitelist: pluginData.playerWhitelist ?? ""

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    property var allPlayers: MprisController.availablePlayers

    readonly property var sourcePriority: {
        var raw = [
            pluginData.source1 ?? "navidrome",
            pluginData.source2 ?? "lrclib",
            pluginData.source3 ?? "musixmatch",
            pluginData.source4 ?? "lrcapi"
            ];

        var seen = ({}), out = []
        for (var v of raw) {
            if (v && !seen[v]) {
                seen[v] = true;
                out.push(_sourceToEnum(v))
            }
        }
        return out
    }

    // -------------------------------------------------------------------------
    // Enum namespaces
    // -------------------------------------------------------------------------

    // Chip-visible statuses for navidromeStatus, lrclibStatus, and cacheStatus.
    // Values are globally unique so all three properties share one _chipMeta map.
    QtObject {
        id: status
        readonly property int none: 0
        readonly property int searching: 1
        readonly property int found: 2
        readonly property int notFound: 3
        readonly property int error: 4
        readonly property int skippedConfig: 5
        readonly property int skippedFound: 6
        readonly property int skippedPlain: 7
        readonly property int cacheHit: 11
        readonly property int cacheMiss: 12
        readonly property int cacheDisabled: 13
    }

    // Lyrics-fetch lifecycle.
    QtObject {
        id: lyricState
        readonly property int idle: 0
        readonly property int loading: 1
        readonly property int synced: 2
        readonly property int notFound: 3
    }

    // Lyrics sources.
    QtObject {
        id: lyricSrc
        readonly property int none: 0
        readonly property int navidrome: 1
        readonly property int lrclib: 2
        readonly property int cache: 3
        readonly property int musixmatch: 4
        readonly property int lrcapi: 5
    }

    function _sourceToEnum(source) {
        switch (source) {
        case "navidrome":   return lyricSrc.navidrome
        case "lrclib":      return lyricSrc.lrclib
        case "cache":       return lyricSrc.cache
        case "musixmatch":  return lyricSrc.musixmatch
        case "lrcapi":      return lyricSrc.lrcapi
        default:            return lyricSrc.none
        }
    }

    // -------------------------------------------------------------------------
    // Lyrics state
    // -------------------------------------------------------------------------

    property var lyricsLines: []
    property int currentLineIndex: -1
    property bool lyricsLoading: lyricStatus === lyricState.loading
    property string _lastFetchedTrack: ""
    property string _lastFetchedArtist: ""
    property var _cancelActiveFetch: null

    // Chip status properties
    property int navidromeStatus: status.none
    property int lrclibStatus: status.none
    property int lrcapiStatus: status.none
    property int musixmatchStatus: status.none
    property int cacheStatus: status.none

    // Fetch state and source
    property int lyricStatus: lyricState.idle
    property int lyricSource: lyricSrc.none

    // Track current song info
    property string currentTitle: activePlayer?.trackTitle ?? ""
    property string currentArtist: activePlayer?.trackArtist ?? ""
    property string currentAlbum: activePlayer?.trackAlbum ?? ""
    property real currentDuration: activePlayer?.length ?? 0

    // Current lyric line for bar pill display
    property string currentLyricText: {
        if (lyricsLoading)
            return "Searching lyrics…";
        if (lyricsLines.length > 0 && currentLineIndex >= 0)
            return lyricsLines[currentLineIndex].text || "♪ ♪ ♪";
        if (currentTitle)
            return currentTitle;
        return "No lyrics";
    }

    property bool _configValid: navidromeUrl !== "" && navidromeUser !== "" && navidromePassword !== ""

    on_ConfigValidChanged: {
        console.info("[LiveLyrics] Navidrome configured: " + (_configValid ? "yes (" + navidromeUrl + ")" : "no"));
        if (activePlayer && currentTitle)
            fetchDebounceTimer.restart();
    }

    // Debounce timer — avoids double-fetch when title and artist change simultaneously
    Timer {
        id: fetchDebounceTimer
        interval: 300
        onTriggered: root.fetchLyricsIfNeeded()
    }
    onCurrentTitleChanged: fetchDebounceTimer.restart()
    onCurrentArtistChanged: fetchDebounceTimer.restart()

    // Force-update toggle to poll MPRIS position
    property bool _forceUpdate: false

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _resetLyricsState() {
        lyricsLines = [];
        currentLineIndex = -1;
        navidromeStatus = status.none;
        lrclibStatus = status.none;
        lrcapiStatus = status.none;
        musixmatchStatus = status.none;
        cacheStatus = status.none;
        lyricStatus = lyricState.loading;
        lyricSource = lyricSrc.none;
        _advanceChain = null;
    }

    // Called by a source handler when it finishes. found === true means synced
    // lyrics were stored and the chain stops here; found === false advances to
    // the next source in priority order.
    property var _advanceChain: null

    function _sourceDone(found) {
        var next = root._advanceChain;
        root._advanceChain = null;
        if (next)
            next(found);
    }

    // Maps a lyricSrc enum to its chip-status property.
    function _setSourceStatus(source, statusVal) {
        switch (source) {
        case lyricSrc.navidrome:   navidromeStatus = statusVal;  break;
        case lyricSrc.lrclib:      lrclibStatus = statusVal;     break;
        case lyricSrc.lrcapi:      lrcapiStatus = statusVal;     break;
        case lyricSrc.musixmatch:  musixmatchStatus = statusVal; break;
        }
    }

    // Reads the current chip-status for a source enum. Used by the popout cards;
    function _sourceStatus(source) {
        switch (source) {
        case lyricSrc.navidrome:   return navidromeStatus;
        case lyricSrc.lrclib:      return lrclibStatus;
        case lyricSrc.lrcapi:      return lrcapiStatus;
        case lyricSrc.musixmatch:  return musixmatchStatus;
        case lyricSrc.cache:       return cacheStatus;
        default:                   return status.none;
        }
    }

    // Display metadata (icon + label) for a source enum.
    function _sourceMeta(source) {
        switch (source) {
        case lyricSrc.navidrome:   return { icon: "cloud",         label: "navidrome"  };
        case lyricSrc.lrclib:      return { icon: "library_music", label: "lrclib"     };
        case lyricSrc.lrcapi:      return { icon: "Genres",        label: "lrcapi"     };
        case lyricSrc.musixmatch:  return { icon: "music_note",    label: "musixmatch" };
        case lyricSrc.cache:       return { icon: "cached",        label: "cache"      };
        default:                   return { icon: "help",          label: "unknown"    };
        }
    }

    // -------------------------------------------------------------------------
    // Cache helpers
    // -------------------------------------------------------------------------

    function _fnv1a32(str) {
        var hash = 0x811c9dc5;
        for (var i = 0; i < str.length; i++) {
            hash = ((hash ^ str.charCodeAt(i)) * 0x01000193) >>> 0;
        }
        return ("00000000" + hash.toString(16)).slice(-8);
    }

    function _cacheKey(title, artist) {
        return _fnv1a32((title + "\x00" + artist).toLowerCase());
    }

    readonly property string _cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache") || "") + "/dms-plugin-livelyrics"

    function _cacheFilePath(title, artist) {
        return _cacheDir + "/" + _cacheKey(title, artist) + ".json";
    }

    // Static one-shot timer for XHR request timeouts
    Timer {
        id: xhrTimeoutTimer
        repeat: false
        property var onTimeout: null
        onTriggered: if (onTimeout)
            onTimeout()
    }

    // Static one-shot timer for retry delays
    Timer {
        id: xhrRetryTimer
        repeat: false
        property var onRetry: null
        onTriggered: if (onRetry)
            onRetry()
    }

    // Cache directory creation
    property bool _cacheDirReady: false

    Process {
        id: mkdirProcess
        command: ["mkdir", "-p", root._cacheDir]
        running: false
    }

    function _ensureCacheDir() {
        if (_cacheDirReady)
            return;
        _cacheDirReady = true;
        mkdirProcess.running = true;
    }

    // Cache read using FileView
    Component {
        id: cacheReaderComponent
        FileView {
            property var callback
            blockLoading: true
            preload: true
            onLoaded: {
                try {
                    callback(JSON.parse(text()));
                } catch (e) {
                    callback(null);
                }
                destroy();
            }
            onLoadFailed: {
                callback(null);
                destroy();
            }
        }
    }

    function readFromCache(title, artist, callback) {
        cacheReaderComponent.createObject(root, {
            path: _cacheFilePath(title, artist),
            callback: callback
        });
    }

    // Cache write using FileView
    Component {
        id: cacheWriterComponent
        FileView {
            property string cTitle
            property string cArtist
            blockWrites: false
            atomicWrites: true
            onSaved: {
                console.info("[LiveLyrics] Cache: written for \"" + cTitle + "\" by " + cArtist + " (" + path + ")");
                destroy();
            }
            onSaveFailed: {
                console.warn("[LiveLyrics] Cache: failed to write for \"" + cTitle + "\"");
                destroy();
            }
        }
    }

    function writeToCache(title, artist, lines, source) {
        _ensureCacheDir();
        var writer = cacheWriterComponent.createObject(root, {
            path: _cacheFilePath(title, artist),
            cTitle: title,
            cArtist: artist
        });
        writer.setText(JSON.stringify({
            lines: lines,
            source: source
        }));
    }

    // -------------------------------------------------------------------------
    // Fetch orchestration
    // -------------------------------------------------------------------------

    function fetchLyricsIfNeeded() {
        var player = root.activePlayer;
        var whitelist = root.playerWhitelist.split(",").map(function(s) { return s.trim(); });
        if (!player)
            return;
        var identity = player.identity || "";
        var isMusicPlayer = false;
        for (var i = 0; i < whitelist.length; i++) {
            if (identity.toLowerCase().includes(whitelist[i])) {
                isMusicPlayer = true;
                break;
            }
        }
        if (!isMusicPlayer)
        {
            _resetLyricsState();
            return;
        }

        if (!currentTitle)
            return;

        if (currentTitle === _lastFetchedTrack && currentArtist === _lastFetchedArtist)
            return;

        // Cancel any in-flight XHR before starting fresh
        if (_cancelActiveFetch) {
            _cancelActiveFetch();
            _cancelActiveFetch = null;
        }

        _lastFetchedTrack = currentTitle;
        _lastFetchedArtist = currentArtist;
        _resetLyricsState();

        console.info("[LiveLyrics] ▶ Track changed: \"" + currentTitle + "\" by " + currentArtist + (currentAlbum ? " [" + currentAlbum + "]" : ""));

        var capturedTitle = currentTitle;
        var capturedArtist = currentArtist;

        console.info("[LiveLyrics] Sources: " + root.sourcePriority);

        // Walk sourcePriority in priority order, one source at a time. Each
        // source calls _sourceDone(found): found === true stops the chain (lyrics
        // were stored), found === false advances to the next source.
        function _realFetch() {
            var sources = root.sourcePriority;
            var i = 0;

            function step() {
                // Track changed mid-chain — abandon quietly.
                if (capturedTitle !== root._lastFetchedTrack || capturedArtist !== root._lastFetchedArtist)
                    return;

                if (i >= sources.length) {
                    // Every source exhausted without synced lyrics.
                    root.lyricStatus = lyricState.notFound;
                    root._cancelActiveFetch = null;
                    console.info("[LiveLyrics] ✗ No synced lyrics from any source");
                    return;
                }

                var source = sources[i++];
                root._advanceChain = function (found) {
                    if (found) {
                        root._cancelActiveFetch = null;
                        for (var j = i; j < sources.length; j++)
                            root._setSourceStatus(sources[j], status.skippedFound);
                        return;
                    }
                    step();
                };

                console.info("[LiveLyrics] Source: " + source);
                switch (source) {
                case lyricSrc.musixmatch:  root._fetchFromMusixmatch(capturedTitle, capturedArtist); break;
                case lyricSrc.lrclib:      root._fetchFromLrclib(capturedTitle, capturedArtist);     break;
                case lyricSrc.navidrome:   root._fetchFromNavidrome(capturedTitle, capturedArtist);  break;
                case lyricSrc.lrcapi:      root._fetchFromLrcApi(capturedTitle, capturedArtist);     break;
                default:                   root._sourceDone(false);                                  break;
                }
            }

            step();
        }

        if (cachingEnabled) {
            readFromCache(capturedTitle, capturedArtist, function (cached) {
                // Guard: track may have changed while the file read was in progress
                if (capturedTitle !== root._lastFetchedTrack || capturedArtist !== root._lastFetchedArtist)
                    return;
                if (cached && cached.lines && cached.lines.length > 0) {
                    root.lyricsLines = cached.lines;
                    root.lyricStatus = lyricState.synced;
                    root.lyricSource = cached.source > 0 ? cached.source : lyricSrc.cache;
                    root.cacheStatus = status.cacheHit;
                    // Mark only the selected live sources as skipped (cache served it).
                    for (var s of root.sourcePriority)
                        root._setSourceStatus(s, status.skippedFound);
                    console.info("[LiveLyrics] ✓ Cache: lyrics loaded for \"" + capturedTitle + "\" (" + cached.lines.length + " lines)");
                    return;
                }
                root.cacheStatus = status.cacheMiss;
                _realFetch();
            });
        } else {
            cacheStatus = status.cacheDisabled;
            _realFetch();
        }
    }

    // -------------------------------------------------------------------------
    // XMLHttpRequest helper
    // -------------------------------------------------------------------------

    function _xhrGet(url, timeoutMs, onSuccess, onError, customHeaders) {
        var retriesLeft = 2;
        var retryDelay = 3000;
        var attempt = 0;
        var cancelled = false;
        var currentXhr = null;

        function _attempt() {
            attempt++;
            currentXhr = new XMLHttpRequest();
            var done = false;

            xhrTimeoutTimer.stop();
            xhrTimeoutTimer.interval = timeoutMs;
            xhrTimeoutTimer.onTimeout = function () {
                if (!done && !cancelled) {
                    done = true;
                    currentXhr.abort();
                    _retry("timeout");
                }
            };
            xhrTimeoutTimer.start();

            currentXhr.onreadystatechange = function () {
                if (currentXhr.readyState !== XMLHttpRequest.DONE || done || cancelled)
                    return;
                done = true;
                xhrTimeoutTimer.stop();
                if (currentXhr.status === 0) {
                    _retry("network error (status 0)");
                    return;
                }
                var responseBody = (currentXhr.responseText || "").trim();
                if (responseBody.length === 0) {
                    _retry("empty response (HTTP " + currentXhr.status + ")");
                    return;
                }
                onSuccess(currentXhr.responseText, currentXhr.status);
            };
            currentXhr.open("GET", url);
            if (customHeaders) {
                for (var key in customHeaders)
                    currentXhr.setRequestHeader(key, customHeaders[key]);
            } else {
                currentXhr.setRequestHeader("User-Agent", "DankMaterialShell LiveLyrics/1.0.0 (https://gitlab.com/noahpolimon/dms-plugin-livelyrics)");
                currentXhr.setRequestHeader("Accept", "application/json");
            }
            currentXhr.send();
        }

        function _retry(errMsg) {
            if (cancelled)
                return;
            if (retriesLeft > 0) {
                retriesLeft--;
                console.warn("[LiveLyrics] _xhrGet: " + errMsg + " — retrying (attempt " + (attempt + 1) + ", " + retriesLeft + " left): " + url);
                xhrRetryTimer.stop();
                xhrRetryTimer.interval = retryDelay;
                xhrRetryTimer.onRetry = _attempt;
                xhrRetryTimer.start();
            } else {
                onError(errMsg);
            }
        }

        _attempt();

        // Return a cancel function the caller can invoke to abort the entire chain
        return function cancel() {
            cancelled = true;
            xhrTimeoutTimer.stop();
            xhrRetryTimer.stop();
            if (currentXhr)
                currentXhr.abort();
            console.info("[LiveLyrics] ⊘ XHR cancelled: " + url);
        };
    }

    // -------------------------------------------------------------------------
    // Navidrome fetch
    // -------------------------------------------------------------------------

    // Builds a Navidrome REST URL with common auth params appended
    function _navidromeUrl(endpoint, extraParams) {
        var base = navidromeUrl.replace(/\/+$/, "") + "/rest/" + endpoint;
        var auth = "u=" + encodeURIComponent(navidromeUser) + "&p=" + encodeURIComponent(navidromePassword) + "&v=1.16.1&c=DankMaterialShell&f=json";
        return base + "?" + (extraParams ? extraParams + "&" : "") + auth;
    }

    function _fetchFromNavidrome(expectedTitle, expectedArtist) {
        if (!_configValid) {
            navidromeStatus = status.skippedConfig;
            console.info("[LiveLyrics] Navidrome: skipped (server not configured)");
            root._sourceDone(false);
            return;
        }

        navidromeStatus = status.searching;
        console.info("[LiveLyrics] Navidrome: searching for \"" + expectedTitle + "\" by " + expectedArtist);

        var searchUrl = _navidromeUrl("search3", "query=" + encodeURIComponent(expectedTitle) + "&songCount=5&albumCount=0&artistCount=0");
        console.log("[LiveLyrics] Navidrome: search URL = " + searchUrl);

        root._cancelActiveFetch = _xhrGet(searchUrl, 15000, function (responseText, httpStatus) {
            var rawData = (responseText || "").trim();
            console.log("[LiveLyrics] Navidrome: search response length = " + rawData.length);
            if (rawData.length === 0) {
                root.navidromeStatus = status.error;
                console.warn("[LiveLyrics] Navidrome: empty search response (HTTP " + httpStatus + ")");
                root._sourceDone(false);
                return;
            }
            try {
                var result = JSON.parse(rawData);
                var songs = result["subsonic-response"]?.searchResult3?.song;
                if (!songs || songs.length === 0) {
                    root.navidromeStatus = status.notFound;
                    console.info("[LiveLyrics] ✗ Navidrome: no matching songs found for \"" + expectedTitle + "\"");
                    root._sourceDone(false);
                    return;
                }

                // Prefer exact title match, fall back to first result
                var songId = songs[0].id;
                for (var i = 0; i < songs.length; i++) {
                    if (songs[i].title.toLowerCase() === expectedTitle.toLowerCase()) {
                        songId = songs[i].id;
                        break;
                    }
                }

                console.log("[LiveLyrics] Navidrome: song matched (id: " + songId + "), fetching lyrics…");
                root._fetchNavidromeLyrics(songId, expectedTitle, expectedArtist);
            } catch (e) {
                root.navidromeStatus = status.error;
                console.warn("[LiveLyrics] Navidrome: failed to parse search response — " + e);
                console.warn("[LiveLyrics] Navidrome: raw data: " + rawData.substring(0, 200));
                root._sourceDone(false);
            }
        }, function (errMsg) {
            root.navidromeStatus = status.error;
            console.warn("[LiveLyrics] Navidrome: search request failed — " + errMsg);
            root._sourceDone(false);
        });
    }

    function _fetchNavidromeLyrics(songId, expectedTitle, expectedArtist) {
        var lyricsUrl = _navidromeUrl("getLyricsBySongId", "id=" + encodeURIComponent(songId));
        console.log("[LiveLyrics] Navidrome: lyrics URL = " + lyricsUrl);

        root._cancelActiveFetch = _xhrGet(lyricsUrl, 15000, function (responseText, httpStatus) {
            var rawData = (responseText || "").trim();
            console.log("[LiveLyrics] Navidrome: lyrics response length = " + rawData.length);
            if (rawData.length === 0) {
                root.navidromeStatus = status.error;
                console.warn("[LiveLyrics] Navidrome: empty lyrics response (HTTP " + httpStatus + ")");
                root._sourceDone(false);
                return;
            }
            try {
                var result = JSON.parse(rawData);
                var lyricsList = result["subsonic-response"]?.lyricsList?.structuredLyrics;
                if (!lyricsList || lyricsList.length === 0) {
                    root.navidromeStatus = status.notFound;
                    console.info("[LiveLyrics] ✗ Navidrome: no lyrics available for \"" + expectedTitle + "\"");
                    root._sourceDone(false);
                    return;
                }

                var synced = null;
                var unsynced = null;
                for (var i = 0; i < lyricsList.length; i++) {
                    if (lyricsList[i].synced) {
                        synced = lyricsList[i];
                        break;
                    } else {
                        unsynced = lyricsList[i];
                    }
                }

                if (synced && synced.line) {
                    var lines = synced.line.map(function (l) {
                        return {
                            time: (l.start || 0) / 1000,
                            text: l.value || ""
                        };
                    });
                    root.lyricsLines = lines;
                    root.navidromeStatus = status.found;
                    root.lyricStatus = lyricState.synced;
                    root.lyricSource = lyricSrc.navidrome;
                    console.info("[LiveLyrics] ✓ Navidrome: synced lyrics found (" + lines.length + " lines) for \"" + expectedTitle + "\"");
                    if (root.cachingEnabled)
                        root.writeToCache(expectedTitle, expectedArtist, lines, lyricSrc.navidrome);
                    root._sourceDone(true);
                } else if (unsynced && unsynced.line) {
                    root.navidromeStatus = status.skippedPlain;
                    console.info("[LiveLyrics] ✗ Navidrome: only plain lyrics found for \"" + expectedTitle + "\" (skipping, synced only)");
                    root._sourceDone(false);
                } else {
                    root.navidromeStatus = status.notFound;
                    console.info("[LiveLyrics] ✗ Navidrome: lyrics structure empty for \"" + expectedTitle + "\"");
                    root._sourceDone(false);
                }
            } catch (e) {
                root.navidromeStatus = status.error;
                console.warn("[LiveLyrics] Navidrome: failed to parse lyrics response — " + e);
                console.warn("[LiveLyrics] Navidrome: raw data: " + rawData.substring(0, 200));
                root._sourceDone(false);
            }
        }, function (errMsg) {
            root.navidromeStatus = status.error;
            console.warn("[LiveLyrics] Navidrome: lyrics request failed — " + errMsg);
            root._sourceDone(false);
        });
    }

    // -------------------------------------------------------------------------
    // lrclib.net fetch
    // -------------------------------------------------------------------------

    function _fetchFromLrclib(expectedTitle, expectedArtist) {
        lrclibStatus = status.searching;
        console.info("[LiveLyrics] lrclib: searching for \"" + expectedTitle + "\" by " + expectedArtist);

        var url = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(expectedArtist) + "&track_name=" + encodeURIComponent(expectedTitle);
        if (currentAlbum)
            url += "&album_name=" + encodeURIComponent(currentAlbum);
        if (currentDuration > 0)
            url += "&duration=" + Math.round(currentDuration);

        root._cancelActiveFetch = _xhrGet(url, 20000, function (responseText, httpStatus) {
            var rawData = (responseText || "").trim();
            console.log("[LiveLyrics] lrclib: response length = " + rawData.length);
            if (rawData.length === 0) {
                root.lrclibStatus = status.error;
                console.warn("[LiveLyrics] lrclib: empty response (HTTP " + httpStatus + ")");
                root._sourceDone(false);
                return;
            }
            try {
                var result = JSON.parse(rawData);
                if (result.statusCode === 404 || result.error) {
                    root.lrclibStatus = status.notFound;
                    console.info("[LiveLyrics] ✗ lrclib: no lyrics found for \"" + expectedTitle + "\"");
                    root._sourceDone(false);
                } else if (result.syncedLyrics) {
                    root.lyricsLines = root.parseLrc(result.syncedLyrics);
                    root.lrclibStatus = status.found;
                    root.lyricStatus = lyricState.synced;
                    root.lyricSource = lyricSrc.lrclib;
                    console.info("[LiveLyrics] ✓ lrclib: synced lyrics found (" + root.lyricsLines.length + " lines) for \"" + expectedTitle + "\"");
                    if (root.cachingEnabled)
                        root.writeToCache(expectedTitle, expectedArtist, root.lyricsLines, lyricSrc.lrclib);
                    root._sourceDone(true);
                } else if (result.plainLyrics) {
                    root.lrclibStatus = status.skippedPlain;
                    console.info("[LiveLyrics] ✗ lrclib: only plain lyrics found for \"" + expectedTitle + "\" (skipping, synced only)");
                    root._sourceDone(false);
                } else {
                    root.lrclibStatus = status.notFound;
                    console.info("[LiveLyrics] ✗ lrclib: response contained no lyrics for \"" + expectedTitle + "\"");
                    root._sourceDone(false);
                }
            } catch (e) {
                root.lrclibStatus = status.error;
                console.warn("[LiveLyrics] lrclib: failed to parse response — " + e);
                console.warn("[LiveLyrics] lrclib: raw data: " + rawData.substring(0, 200));
                root._sourceDone(false);
            }
        }, function (errMsg) {
            root.lrclibStatus = status.error;
            console.warn("[LiveLyrics] lrclib: request failed — " + errMsg);
            root._sourceDone(false);
        });
    }

    // -------------------------------------------------------------------------
    // api.lrc.cx fetch
    // -------------------------------------------------------------------------

    function _fetchFromLrcApi(expectedTitle, expectedArtist) {
        lrcapiStatus = status.searching;
        console.info("[LiveLyrics] lrcapi: searching for \"" + expectedTitle + "\" by " + expectedArtist);

        var url = "https://api.lrc.cx/lyrics?artist=" + encodeURIComponent(expectedArtist) + "&title=" + encodeURIComponent(expectedTitle);
        if (currentAlbum)
            url += "&album=" + encodeURIComponent(currentAlbum);

        root._cancelActiveFetch = _xhrGet(url, 20000, function (responseText, httpStatus) {
            var rawData = (responseText || "").trim();
            console.log("[LiveLyrics] lrcapi: response length = " + rawData.length);
            if (rawData.length === 0) {
                root.lrcapiStatus = status.error;
                console.warn("[LiveLyrics] lrcapi: empty response (HTTP " + httpStatus + ")");
                root._sourceDone(false);
                return;
            }
            try {
                var lines = parseLrc(rawData);
                if (lines && lines.length > 0) {
                    root.lyricsLines = lines;
                    root.lyricStatus = lyricState.synced;
                    root.lrcapiStatus = status.found;
                    root.lyricSource = lyricSrc.lrcapi;
                    console.info("[LiveLyrics] ✓ lrcapi: synced lyrics found (" + root.lyricsLines.length + " lines) for \"" + expectedTitle + "\"");
                    if (root.cachingEnabled)
                        root.writeToCache(expectedTitle, expectedArtist, root.lyricsLines, lyricSrc.lrcapi);
                    root._sourceDone(true);
                } else {
                    root.lrcapiStatus = status.notFound;
                    root._sourceDone(false);
                }
            } catch (e) {
                root.lrcapiStatus = status.error;
                console.warn("[LiveLyrics] lrcapi: failed to parse response — " + e);
                console.warn("[LiveLyrics] lrcapi: raw data: " + rawData.substring(0, 200));
                root._sourceDone(false);
            }
        }, function (errMsg) {
            root.lrcapiStatus = status.error;
            console.warn("[LiveLyrics] lrcapi: request failed — " + errMsg);
            root._sourceDone(false);
        });
    }

    // -------------------------------------------------------------------------
    // Musixmatch fetch
    // -------------------------------------------------------------------------

    property string _musixmatchToken: pluginData.musixmatchToken ?? ""

    function _musixmatchHeaders() {
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36",
            "Accept": "application/json",
            "Accept-Language": "en-US,en;q=0.9",
            "Origin": "https://www.musixmatch.com",
            "Referer": "https://www.musixmatch.com/"
        };
    }

    function _fetchMusixmatchToken(callback) {
        if (_musixmatchToken) {
            callback(_musixmatchToken);
            return;
        }

        var url = "https://apic-desktop.musixmatch.com/ws/1.1/token.get" + "?user_language=en" + "&app_id=web-desktop-app-v1.0" + "&t=" + Date.now();

        console.info("[LiveLyrics] Musixmatch: fetching token…");

        root._cancelActiveFetch = _xhrGet(url, 15000, function (responseText, httpStatus) {
            try {
                var result = JSON.parse(responseText);
                var body = result.message ? result.message.body : undefined;
                var token = body ? body.user_token : undefined;
                if (token && token !== "undefined" && token !== "") {
                    root._musixmatchToken = token;
                    pluginService.savePluginData("liveLyrics", "musixmatchToken", token);
                    console.info("[LiveLyrics] Musixmatch: token acquired");
                    callback(token);
                } else {
                    console.warn("[LiveLyrics] Musixmatch: empty token in response");
                    callback(null);
                }
            } catch (e) {
                console.warn("[LiveLyrics] Musixmatch: failed to parse token response — " + e);
                callback(null);
            }
        }, function (errMsg) {
            console.warn("[LiveLyrics] Musixmatch: token request failed — " + errMsg);
            callback(null);
        }, _musixmatchHeaders());
    }

    function _fetchFromMusixmatch(expectedTitle, expectedArtist, _tokenRetried) {
        musixmatchStatus = status.searching;
        console.info("[LiveLyrics] Musixmatch: searching for \"" + expectedTitle + "\" by " + expectedArtist);

        _fetchMusixmatchToken(function (token) {
            if (!token) {
                root.musixmatchStatus = status.error;
                console.warn("[LiveLyrics] Musixmatch: no token available, cannot search");
                root._sourceDone(false);
                return;
            }

            // Guard: track may have changed
            if (expectedTitle !== root._lastFetchedTrack || expectedArtist !== root._lastFetchedArtist)
                return;

            var trackUrl = "https://apic-desktop.musixmatch.com/ws/1.1/matcher.track.get" + "?q_track=" + encodeURIComponent(expectedTitle) + "&q_artist=" + encodeURIComponent(expectedArtist) + "&page_size=1&page=1" + "&app_id=web-desktop-app-v1.0" + "&usertoken=" + encodeURIComponent(token) + "&t=" + Date.now();

            root._cancelActiveFetch = root._xhrGet(trackUrl, 15000, function (responseText, httpStatus) {
                try {
                    var result = JSON.parse(responseText);
                    var headerStatusCode = result.message && result.message.header ? result.message.header.status_code : 0;
                    if (headerStatusCode === 401 || headerStatusCode === 402) {
                        console.warn("[LiveLyrics] Musixmatch: auth error (status_code=" + headerStatusCode + ") in matcher.track.get");
                        if (!_tokenRetried) {
                            root._musixmatchToken = "";
                            console.info("[LiveLyrics] Musixmatch: token cleared, retrying with fresh token…");
                            root._fetchFromMusixmatch(expectedTitle, expectedArtist, true);
                        } else {
                            root.musixmatchStatus = status.error;
                            console.warn("[LiveLyrics] Musixmatch: auth error persists after token refresh");
                            root._sourceDone(false);
                        }
                        return;
                    }
                    var track = result.message.body.track;
                    var trackId = track.track_id;
                    if (!trackId) {
                        root.musixmatchStatus = status.notFound;
                        console.info("[LiveLyrics] ✗ Musixmatch: no track found for \"" + expectedTitle + "\"");
                        root._sourceDone(false);
                        return;
                    }

                    var hasSubtitles = track.has_subtitles === 1;
                    var hasLyrics = track.has_lyrics === 1;
                    console.info("[LiveLyrics] Musixmatch: track matched (id: " + trackId + ", has_subtitles: " + hasSubtitles + ", has_lyrics: " + hasLyrics + ")");

                    if (!hasSubtitles) {
                        root.musixmatchStatus = hasLyrics ? status.skippedPlain : status.notFound;
                        console.info("[LiveLyrics] ✗ Musixmatch: track has no synced lyrics (has_subtitles=0) for \"" + expectedTitle + "\"");
                        root._sourceDone(false);
                        return;
                    }

                    console.info("[LiveLyrics] Musixmatch: fetching synced lyrics…");
                    root._fetchMusixmatchLyrics(trackId, token, expectedTitle, expectedArtist);
                } catch (e) {
                    root.musixmatchStatus = status.error;
                    console.warn("[LiveLyrics] Musixmatch: failed to parse track response — " + e);
                    root._sourceDone(false);
                }
            }, function (errMsg) {
                root.musixmatchStatus = status.error;
                console.warn("[LiveLyrics] Musixmatch: track request failed — " + errMsg);
                root._sourceDone(false);
            }, _musixmatchHeaders());
        });
    }

    function _fetchMusixmatchLyrics(trackId, token, expectedTitle, expectedArtist, _tokenRetried) {
        var url = "https://apic-desktop.musixmatch.com/ws/1.1/track.subtitle.get" + "?track_id=" + trackId + "&subtitle_format=lrc" + "&app_id=web-desktop-app-v1.0" + "&usertoken=" + encodeURIComponent(token) + "&t=" + Date.now();

        root._cancelActiveFetch = _xhrGet(url, 15000, function (responseText, httpStatus) {
            // Guard: track may have changed
            if (expectedTitle !== root._lastFetchedTrack || expectedArtist !== root._lastFetchedArtist)
                return;

            try {
                var result = JSON.parse(responseText);
                var headerStatusCode = result.message && result.message.header ? result.message.header.status_code : 0;
                if (headerStatusCode === 401 || headerStatusCode === 402) {
                    console.warn("[LiveLyrics] Musixmatch: auth error (status_code=" + headerStatusCode + ") in track.subtitle.get");
                    if (!_tokenRetried) {
                        root._musixmatchToken = "";
                        console.info("[LiveLyrics] Musixmatch: token cleared, retrying with fresh token…");
                        root._fetchFromMusixmatch(expectedTitle, expectedArtist, true);
                    } else {
                        root.musixmatchStatus = status.error;
                        console.warn("[LiveLyrics] Musixmatch: auth error persists after token refresh");
                        root._sourceDone(false);
                    }
                    return;
                }
                var subtitleBody = result.message.body.subtitle.subtitle_body;
                if (!subtitleBody || subtitleBody.trim() === "") {
                    root.musixmatchStatus = status.notFound;
                    console.info("[LiveLyrics] ✗ Musixmatch: no synced lyrics for \"" + expectedTitle + "\"");
                    root._sourceDone(false);
                    return;
                }

                var lines = root.parseLrc(subtitleBody);
                if (lines.length === 0) {
                    root.musixmatchStatus = status.notFound;
                    console.info("[LiveLyrics] ✗ Musixmatch: failed to parse LRC for \"" + expectedTitle + "\"");
                    root._sourceDone(false);
                    return;
                }

                root.lyricsLines = lines;
                root.musixmatchStatus = status.found;
                root.lyricStatus = lyricState.synced;
                root.lyricSource = lyricSrc.musixmatch;
                console.info("[LiveLyrics] ✓ Musixmatch: synced lyrics found (" + lines.length + " lines) for \"" + expectedTitle + "\"");
                if (root.cachingEnabled)
                    root.writeToCache(expectedTitle, expectedArtist, lines, lyricSrc.musixmatch);
                root._sourceDone(true);
            } catch (e) {
                root.musixmatchStatus = status.error;
                console.warn("[LiveLyrics] Musixmatch: failed to parse lyrics response — " + e);
                root._sourceDone(false);
            }
        }, function (errMsg) {
            root.musixmatchStatus = status.error;
            console.warn("[LiveLyrics] Musixmatch: lyrics request failed — " + errMsg);
            root._sourceDone(false);
        }, _musixmatchHeaders());
    }

    // -------------------------------------------------------------------------
    // LRC parser
    // -------------------------------------------------------------------------

    function parseLrc(lrcText) {
        var timeRegex = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/;
        var result = lrcText.split("\n").reduce(function (acc, rawLine) {
            var line = rawLine.trim();
            if (!line)
                return acc;
            var match = timeRegex.exec(line);
            if (!match)
                return acc;
            var millis = parseInt(match[3]);
            if (match[3].length === 2)
                millis *= 10;
            acc.push({
                time: parseInt(match[1]) * 60 + parseInt(match[2]) + millis / 1000,
                text: line.replace(/\[\d{2}:\d{2}\.\d{2,3}\]/g, "").trim()
            });
            return acc;
        }, []);
        result.sort(function (a, b) {
            return a.time - b.time;
        });
        return result;
    }

    // -------------------------------------------------------------------------
    // Position tracking for synced lyrics
    // -------------------------------------------------------------------------

    Timer {
        id: positionTimer
        interval: 200
        running: activePlayer && lyricsLines.length > 0
        repeat: true
        onTriggered: {
            var pos = activePlayer.position || 0;
            var newIndex = -1;
            for (var i = lyricsLines.length - 1; i >= 0; i--) {
                if (pos >= lyricsLines[i].time) {
                    newIndex = i;
                    break;
                }
            }
            if (newIndex !== currentLineIndex)
                currentLineIndex = newIndex;
        }
    }

    // -------------------------------------------------------------------------
    // Status chip helpers
    // -------------------------------------------------------------------------

    readonly property var _chipMeta: ({
            [status.searching]: {
                color: Theme.secondary,
                icon: "hourglass_top",
                label: "Searching…"
            },
            [status.found]: {
                color: Theme.primary,
                icon: "check_circle",
                label: "Found: Synced lyrics"
            },
            [status.notFound]: {
                color: Theme.warning,
                icon: "cancel",
                label: "Not found"
            },
            [status.error]: {
                color: Theme.error,
                icon: "error",
                label: "Error"
            },
            [status.skippedConfig]: {
                color: Theme.warning,
                icon: "block",
                label: "Skipped: Not configured"
            },
            [status.skippedFound]: {
                color: Theme.warning,
                icon: "block",
                label: "Skipped: Already found"
            },
            [status.skippedPlain]: {
                color: Theme.warning,
                icon: "block",
                label: "Skipped: Plain lyrics"
            },
            [status.cacheHit]: {
                color: Theme.primary,
                icon: "check_circle",
                label: "Hit: Loaded from cache"
            },
            [status.cacheMiss]: {
                color: Theme.warning,
                icon: "cancel",
                label: "Miss: Not in cache"
            },
            [status.cacheDisabled]: {
                color: Theme.surfaceVariantText,
                icon: "do_not_disturb_on",
                label: "Disabled"
            }
        })

    function _chip(val) {
        return _chipMeta[val] ?? {
            color: Theme.surfaceContainerHighest,
            icon: "radio_button_unchecked",
            label: "Idle"
        };
    }

    function chipColor(val) {
        return _chip(val).color;
    }
    function chipIcon(val) {
        return _chip(val).icon;
    }
    function chipLabel(val) {
        return _chip(val).label;
    }

    // -------------------------------------------------------------------------
    // Bar Pills: show current lyric line
    // -------------------------------------------------------------------------

    horizontalBarPill: root.activePlayer ? hPillComponent : null

    Component {
        id: hPillComponent
        Row {
            spacing: Theme.spacingS

            Rectangle {
                width: chipContent.implicitWidth + Theme.spacingS * 2
                height: Theme.fontSizeSmall + Theme.spacingXS
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.primary

                Row {
                    id: chipContent
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? "lyrics" : "pause"
                        size: Theme.fontSizeSmall
                        color: Theme.background
                    }

                    // StyledText {
                    //     text: root.lyricSource === lyricSrc.navidrome ? "Navidrome" : root.lyricSource === lyricSrc.lrclib ? "lrclib" : root.lyricSource === lyricSrc.musixmatch ? "Musixmatch" : ""
                    //     font.pixelSize: Theme.fontSizeSmall
                    //     color: Theme.background
                    //     anchors.verticalCenter: parent.verticalCenter
                    //     maximumLineCount: 1
                    //     elide: Text.ElideRight
                    //     visible: root.lyricsLines.length > 0
                    // }
                }
            }

            Item {
                id: lyricMarquee
                clip: true
                width: Math.min(lyricLineText.contentWidth, 250)
                height: lyricLineText.implicitHeight

                readonly property real overflow: lyricLineText.contentWidth - width
                readonly property bool overflowing: overflow > 0

                function resetScroll() {
                    lyricScroll.stop()
                    lyricLineText.x = 0
                    if (overflowing)
                        lyricScroll.start()
                }

                onWidthChanged: Qt.callLater(resetScroll)
                Component.onCompleted: Qt.callLater(resetScroll)

                StyledText {
                    id: lyricLineText
                    text: root.currentLyricText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    anchors.verticalCenter: parent.verticalCenter

                    onContentWidthChanged: Qt.callLater(lyricMarquee.resetScroll)

                    SequentialAnimation {
                        id: lyricScroll
                        PauseAnimation { duration: 1000 }
                        NumberAnimation {
                            target: lyricLineText; property: "x"
                            to: -lyricMarquee.overflow
                            duration: lyricMarquee.overflow * 15
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: root.activePlayer ? vPillComponent : null

    Component {
        id: vPillComponent
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "lyrics"
                size: Theme.iconSize
                color: root.lyricsLines.length > 0 ? Theme.primary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: "♪"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // -------------------------------------------------------------------------
    // Popout: Now Playing + Lyrics Sources
    // -------------------------------------------------------------------------

    function _formatDuration(seconds) {
        if (seconds <= 0)
            return "—";
        var m = Math.floor(seconds / 60);
        var s = Math.floor(seconds % 60);
        return m + ":" + ("0" + s).slice(-2);
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "Live Lyrics"

            Item {
                width: parent.width
                implicitHeight: popoutLayout.implicitHeight

                Column {
                    id: popoutLayout
                    width: parent.width
                    spacing: Theme.spacingM

                    // ── Now Playing Card ──
                    Rectangle {
                        width: parent.width
                        height: nowPlayingContent.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: root.activePlayer ? Theme.withAlpha(Theme.primary, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, 0.5)

                        Row {
                            id: nowPlayingContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: Theme.spacingM
                            }
                            spacing: Theme.spacingM

                            // Track info column (takes remaining space)
                            Column {
                                width: _coverArt.visible ? parent.width - _coverArt.width - parent.spacing : parent.width
                                spacing: Theme.spacingS

                                // Header row: icon + "Now Playing"
                                Row {
                                    spacing: Theme.spacingS
                                    width: parent.width

                                    DankIcon {
                                        name: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? "play_circle" : "pause_circle"
                                        size: 20
                                        color: root.activePlayer ? Theme.primary : Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: root.activePlayer ? "Now Playing - " + (root.activePlayer.identity || "Unknown Player") : "No Active Player"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.DemiBold
                                        color: root.activePlayer ? Theme.primary : Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Song title
                                StyledText {
                                    width: parent.width
                                    text: root.currentTitle || "—"
                                    font.pixelSize: Theme.fontSizeLarge + 2
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    wrapMode: Text.WordWrap
                                    visible: root.activePlayer
                                }

                                // Artist & Album
                                Column {
                                    width: parent.width
                                    spacing: 2
                                    visible: root.activePlayer

                                    Row {
                                        spacing: Theme.spacingXS
                                        DankIcon {
                                            name: "person"
                                            size: 14
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        StyledText {
                                            text: root.currentArtist || "Unknown Artist"
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                            maximumLineCount: 1
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Row {
                                        spacing: Theme.spacingXS
                                        visible: root.currentAlbum !== ""
                                        DankIcon {
                                            name: "album"
                                            size: 14
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        StyledText {
                                            text: root.currentAlbum
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                            maximumLineCount: 1
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                // Progress bar with timestamps
                                Column {
                                    width: parent.width
                                    spacing: 4
                                    visible: root.activePlayer && root.currentDuration > 0

                                    DankSeekbar {
                                        id: progressSeekbar
                                        width: parent.width
                                        height: 20
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        activePlayer: root.activePlayer
                                    }

                                    // Poll MPRIS position to keep seekbar and time text updated
                                    Timer {
                                        interval: 50
                                        running: root.activePlayer !== null
                                        repeat: true
                                        onTriggered: {
                                            if (progressSeekbar && root.activePlayer) {
                                                try {
                                                    var pos = root.activePlayer.position || 0;
                                                    var len = Math.max(1, root.activePlayer.length || 1);
                                                    progressSeekbar.value = Math.min(1, pos / len);
                                                } catch (e) {}
                                            }
                                            root._forceUpdate = !root._forceUpdate;
                                        }
                                    }

                                    Row {
                                        width: parent.width

                                        StyledText {
                                            id: _currentTime
                                            text: {
                                                void root._forceUpdate; // depend on polling toggle
                                                if (!activePlayer)
                                                    return "0:00";
                                                const rawPos = Math.max(0, activePlayer.position || 0);
                                                const pos = activePlayer.length ? rawPos % Math.max(1, activePlayer.length) : rawPos;
                                                const minutes = Math.floor(pos / 60);
                                                const seconds = Math.floor(pos % 60);
                                                const timeStr = minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
                                                return timeStr;
                                            }
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }

                                        Item {
                                            width: parent.width - _currentTime.implicitWidth - _endTime.implicitWidth
                                            height: 1
                                        }

                                        StyledText {
                                            id: _endTime
                                            text: {
                                                if (!activePlayer || !activePlayer.length)
                                                    return "0:00";
                                                const dur = Math.max(0, activePlayer.length || 0);
                                                const minutes = Math.floor(dur / 60);
                                                const seconds = Math.floor(dur % 60);
                                                return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
                                            }
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }
                            }

                            // Album cover art
                            DankAlbumArt {
                                id: _coverArt
                                width: 80
                                height: 80
                                visible: root.activePlayer && (root.activePlayer.trackArtUrl ?? "") !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                activePlayer: root.activePlayer
                                showAnimation: true
                            }
                        }
                    }

                    // ── Section label ──
                    StyledText {
                        text: "Lyrics Sources"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.surfaceVariantText
                        leftPadding: Theme.spacingXS
                    }

                    // ── Source Cards ──
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        // Cache is always consulted first (before the priority
                        // chain), so it stays pinned at the top.
                        SourceCard {
                            width: parent.width
                            icon: "cached"
                            label: "Cache"
                            sourceStatus: root.cacheStatus
                        }

                        // Live sources, in the user's configured priority order.
                        Repeater {
                            model: root.sourcePriority

                            SourceCard {
                                required property var modelData
                                width: parent.width
                                icon: root._sourceMeta(modelData).icon
                                label: root._sourceMeta(modelData).label
                                sourceStatus: root._sourceStatus(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Reusable source status card
    // -------------------------------------------------------------------------

    component SourceCard: Rectangle {
        id: sourceCard
        property string icon: ""
        property string label: ""
        property int sourceStatus: 0

        height: 44
        radius: Theme.cornerRadius
        color: sourceStatus === 0 ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.3) : Theme.withAlpha(root.chipColor(sourceStatus), 0.06)
        visible: true

        Row {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.spacingM
                rightMargin: Theme.spacingM
            }
            spacing: Theme.spacingS

            // Source icon
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: sourceCard.sourceStatus === 0 ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.5) : Theme.withAlpha(root.chipColor(sourceCard.sourceStatus), 0.15)
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: sourceCard.icon
                    size: 14
                    color: sourceCard.sourceStatus === 0 ? Theme.surfaceVariantText : root.chipColor(sourceCard.sourceStatus)
                }
            }

            // Label
            StyledText {
                text: sourceCard.label
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                width: 90
            }

            // Status chip – fills remaining width
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - parent.spacing * 2 - 28 - 90
                height: 22

                Rectangle {
                    visible: sourceCard.sourceStatus !== 0
                    anchors.fill: parent
                    radius: 11
                    color: Theme.withAlpha(root.chipColor(sourceCard.sourceStatus), 0.15)

                    Row {
                        id: statusChipContent
                        anchors.centerIn: parent
                        spacing: 4

                        DankIcon {
                            name: root.chipIcon(sourceCard.sourceStatus)
                            size: 12
                            color: root.chipColor(sourceCard.sourceStatus)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: root.chipLabel(sourceCard.sourceStatus)
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: root.chipColor(sourceCard.sourceStatus)
                            anchors.verticalCenter: parent.verticalCenter
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }
                }

                // Idle label when no status
                Rectangle {
                    visible: sourceCard.sourceStatus === 0
                    anchors.fill: parent
                    radius: 11
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.3)

                    StyledText {
                        anchors.centerIn: parent
                        text: "Idle"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        maximumLineCount: 1
                    }
                }
            }
        }
    }

    popoutWidth: 380
    popoutHeight: 520

    Component.onCompleted: {
        console.info("[LiveLyrics] Plugin loaded");
    }
}
