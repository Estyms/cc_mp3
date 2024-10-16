-- SPOTIFIAK - Estym
LOADING = 0
PLAYING = 1
PAUSED = 2

local settings = {
    base_url = "",
    state = LOADING,
    current_song = "",
}

local function get_speakers(name)
    if name then
        local speaker = peripheral.wrap(name)
        if speaker == nil then
            error(("Speaker %q does not exist"):format(name), 0)
            return
        elseif not peripheral.hasType(name, "speaker") then
            error(("%q is not a speaker"):format(name), 0)
        end

        return { speaker }
    else
        local speakers = { peripheral.find("speaker") }
        if #speakers == 0 then
            error("No speakers attached", 0)
        end
        return speakers
    end
end

function play_song(url, monitor)

    settings.state = LOADING

    if not url then
        error("Invalid url", 0)
    end

    local speaker = get_speakers(monitor)[1]
    speaker.stop()

    local handle, err
    if http and url:match("^https?://") then
        handle, err = http.get(url)
    end

    if not handle then
        printError("Could not play audio:")
        error(err, 0)
    end

    local start = handle.read(4)
    local pcm = false
    local size = 16 * 1024 - 4
    if start == "RIFF" then
        handle.read(4)
        if handle.read(8) ~= "WAVEfmt " then
            handle.close()
            error("Could not play audio: Unsupported WAV file", 0)
        end

        local fmtsize = ("<I4"):unpack(handle.read(4))
        local fmt = handle.read(fmtsize)
        local format, channels, rate, _, _, bits = ("<I2I2I4I4I2I2"):unpack(fmt)
        if not ((format == 1 and bits == 8) or (format == 0xFFFE and bits == 1)) then
            handle.close()
            error("Could not play audio: Unsupported WAV file", 0)
        end
        if channels ~= 1 or rate ~= 48000 then
            print("Warning: Only 48 kHz mono WAV files are supported. This file may not play correctly.")
        end
        if format == 0xFFFE then
            local guid = fmt:sub(25)
            if guid ~= "\x3A\xC1\xFA\x38\x81\x1D\x43\x61\xA4\x0D\xCE\x53\xCA\x60\x7C\xD1" then -- DFPWM format GUID
                handle.close()
                error("Could not play audio: Unsupported WAV file", 0)
            end
            size = size + 4
        else
            pcm = true
            size = 16 * 1024 * 8
        end

        repeat
            local chunk = handle.read(4)
            if chunk == nil then
                handle.close()
                error("Could not play audio: Invalid WAV file", 0)
            elseif chunk ~= "data" then -- Ignore extra chunks
                local size = ("<I4"):unpack(handle.read(4))
                handle.read(size)
            end
        until chunk == "data"

        handle.read(4)
        start = nil
    end

    local decoder = require "cc.audio.dfpwm".make_decoder()
    settings.state = PLAYING
    while true do
        if settings.state == PAUSED then
            sleep(1)
            goto continue
        end
        local chunk = handle.read(size)
        if not chunk then break end
        if start then
            chunk, start = start .. chunk, nil
            size = size + 4
        end

        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
        ::continue::
    end

    handle.close()
end

local function clear_screen()
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(2)
    print("SPOTIFIAK - Estym")
    term.setTextColor(1)
    term.setCursorPos(1,4)
end



local function wait_for_input()
    local count
    while settings.state == LOADING do
        clear_screen()
        write("Loading : " .. settings.current_song)
        textutils.slowWrite("...", 1)
        sleep(1)
    end

    while true do
        clear_screen()
        if settings.state == PAUSED then
            print("Paused : " .. settings.current_song)
        else
            print("Playing : " .. settings.current_song)
        end

        print()

        print("Press P to pause")
        print("Press Q to stop")

        local event, key, help = os.pullEvent("key")
        if keys.getName(key) == 'q' then
            break
        end

        if keys.getName(key) == 'p' then
            if settings.state == PAUSED then
                settings.state = PLAYING
            else
                settings.state = PAUSED
            end
        end
    end
    sleep(1)
end

local function play()
    play_song(settings.base_url .. "/?song=" .. textutils.urlEncode(settings.current_song))
end

while true do
    clear_screen()
    write("Enter song: ")
    settings.current_song = read()

    if settings.current_song == "!quit" then
        term.clear()
        term.setCursorPos(1,1)
        break
    end

    parallel.waitForAny(play, wait_for_input)
end
