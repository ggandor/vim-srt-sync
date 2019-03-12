" *****************************************************************************
" Author: Gyorgy Andorka <gyorgy.andorka@protonmail.com>
" License: The Unlicense

" Defines a command that allows synchronizing SRT subtitles when there is no
" time scale difference with the video file. Delay time can be given in
" milliseconds or SRT timecode format, which will be applied to all timestamps
" in the currently opened file.
" *****************************************************************************

command! -nargs=? DelaySrt call s:DelaySrt('<args>')


let s:timecode_p = '\v\d{2}:\d{2}:\d{2},\d{3}'

fun! s:DelaySrt(input)
    let GetInput = {-> trim(input('Delay in milliseconds '
                \ . 'or SRT timecode format (HH:MM:SS,XXX): '))}

    let input = a:input
    if input == ""
        let input = GetInput()
        " then <Esc> suffices instead of <C-c>
        if len(input) == 0 | return | endif
    endif

    let delay = 0
    let signed_int = '\v^-?\d+$'
    let signed_timecode = '\v^-?' . s:timecode_p . '$'
    if input =~ signed_int
        let delay = input
    elseif input =~ signed_timecode
        let delay = (input =~ '^-' ? -1 : 1) * s:TimecodeToMillis(trim(input, '-'))
    else
        redraw | echo 'Cannot apply: malformed input'
        return
    endif

    if delay != 0
        call s:DelayLines(delay)
    endif
endfun

fun! s:DelayLines(delay)
    let timecode_line_p = '\v^' . s:timecode_p . ' --\> ' . s:timecode_p . '\s*$'
    let saved_view = winsaveview()
    redraw | echo "Shifting subtitles..."
    try
        for line_num in range(1, line('$'))
            let line = (getline(line_num))
            if line =~ timecode_line_p
                let delayed_line = s:DelayedLine(line, a:delay)
                exe 'keepjumps keeppatterns ' . line_num . 's/.*/\=delayed_line/'
            endif
        endfor
        redraw | echo ""
    " We can assume this error will be thrown right at the very first
    " timecode line, if at all, so no state change to worry about.
    catch 'illegal timecode value'
        redraw | echo 'Cannot apply: the given delay time would result'
                    \ . ' in negative timecode value(s)'
    finally
        call winrestview(saved_view)
    endtry
endfun

fun! s:DelayedLine(timecode_line, delay)
    return substitute(a:timecode_line, s:timecode_p,
                \ '\=s:DelayedTimecode(submatch(0), a:delay)', 'g')
endfun

fun! s:DelayedTimecode(timecode, delay)
    let new_time = s:TimecodeToMillis(a:timecode) + a:delay
    if new_time < 0
        throw 'illegal timecode value'
    endif
    return s:MillisToTimecode(new_time)
endfun

fun! s:TimecodeToMillis(timecode)
    let [hours_mins_secs, millis] = split(a:timecode, ',')
    let [hours, mins, secs] = split(hours_mins_secs, ':')
    return (hours * s:MILLIS_PER_HOUR)
                \ + (mins * s:MILLIS_PER_MIN)
                \ + (secs * s:MILLIS_PER_SEC)
                \ + millis
endfun

fun! s:MillisToTimecode(n)
    fun! PadZeros(slots_to_fill, val)
        let padding_zeros = repeat('0', a:slots_to_fill - len(string(a:val)))
        return padding_zeros . a:val
    endfun

    let hours = float2nr(floor(a:n / s:MILLIS_PER_HOUR))
    let mins = float2nr(floor(a:n / s:MILLIS_PER_MIN)) % s:MINS_PER_HOUR
    let secs = float2nr(floor(a:n / s:MILLIS_PER_SEC)) % s:SECS_PER_MIN
    let millis = a:n % s:MILLIS_PER_SEC
    let [hours, mins, secs] = map([hours, mins, secs], {_, val -> PadZeros(2, val)})
    let millis = PadZeros(3, millis)
    return hours . ':' . mins . ':' . secs . ',' . millis
endfun

let s:MILLIS_PER_SEC = 1000
let s:MILLIS_PER_MIN = 1000 * 60
let s:MILLIS_PER_HOUR = 1000 * 60 * 60
let s:SECS_PER_MIN = 60
let s:MINS_PER_HOUR = 60

