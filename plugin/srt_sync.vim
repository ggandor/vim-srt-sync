" *****************************************************************************
" Author: Gyorgy Andorka <gyorgy.andorka@protonmail.com>
" License: The Unlicense

" Defines a command that allows synchronizing SRT subtitles when there is no
" time scale difference with the video file. Delay time can be given in
" milliseconds or SRT timecode format, which will be applied to all timestamps
" in the currently opened file.
" *****************************************************************************

" Public {{{

" I don't yet really understand why, but the final `redraw!` command does not
" work properly if placed inside the function (the command line is cleared all
" right, but there is a funny side effect which looks like as if a visual
" selection is applied to the whole screen). So here is a command instead
" (might be more convenient anyway).
command! -nargs=? DelaySrt call s:DelaySrt('<args>')
            \ | redraw! | echo s:errormsg | let s:errormsg = ""

" }}}

" Local {{{

let s:errormsg = ""

fun! s:DelaySrt(delay)
    let delay = a:delay
    if delay == ""
        let delay = trim(input('Delay in milliseconds'
                    \ . ' or SRT timecode format (HH:MM:SS,MIL): '))
        if len(delay) == 0 | return | endif  " then <Esc> suffices instead of <C-c>
    endif

    let timecode = '\v^-?\d{2}:\d{2}:\d{2},\d{3}$'
    let signed_int = '\v^-?\d+$'
    if delay =~ timecode
        let opt_neg = (delay =~ '^-' ? -1 : 1)
        let delay = s:TimecodeStringToMillis(delay) * opt_neg
    elseif delay !~ signed_int
        let s:errormsg = 'Cannot apply: malformed input' | return
    endif
    if delay == 0 | return | endif

    try
        redraw | echo "Shifting subtitles..."
        call s:ApplyDelay(delay)
    catch 'illegal timecode value'
        " We can assume this error will be thrown right at the very first
        " timecode line, if at all, so no state change to worry about.
        let s:errormsg = 'Cannot apply: the given delay time would result'
                    \ . ' in negative timecode value(s)'
        return
    endtry
endfun

fun! s:ApplyDelay(delay)
    let timecode = '\d{2}:\d{2}:\d{2},\d{3}'
    let timecode_line = '\v^'.timecode.' --\> '.timecode.'\s*$'
    let saved_view = winsaveview()
    try
        for line_num in range(1, line('$'))
            let line = (getline(line_num))
            if line =~ timecode_line
                let delayed_line = s:DelayedLine(line, a:delay)
                exe 'keepjumps '.line_num.'substitute/.*/\=delayed_line/'
            endif
        endfor
    catch 'illegal timecode value'
        throw v:exception
    finally
        call histdel('search', -1)
        call winrestview(saved_view)
    endtry
endfun

fun! s:DelayedLine(line, delay)
    let timecodes = split(a:line, ' --> ')
    let timecodes = s:Map(timecodes, function('trim'))
    let times = s:Map(timecodes, function('s:TimecodeStringToMillis'))
    try
        let new_times = s:Map(times, function('s:AddDelay', [a:delay]))
    catch 'illegal timecode value'
        throw v:exception
    endtry
    let new_timecodes = s:Map(new_times, function('s:MillisToTimecodeString'))
    let [new_start, new_end] = new_timecodes
    return new_start.' --> '.new_end
endfun

fun! s:AddDelay(delay, time)
    let new_time = a:time + a:delay
    if new_time < 0 | throw 'illegal timecode value' | endif
    return new_time
endfun

fun! s:TimecodeStringToMillis(timecode_string)
    let [hours_mins_secs, millis] = split(a:timecode_string, ',')
    let [hours, mins, secs] = split(hours_mins_secs, ':')
    return (hours * s:MILLIS_PER_HOUR)
                \ + (mins * s:MILLIS_PER_MIN)
                \ + (secs * s:MILLIS_PER_SEC)
                \ + millis
endfun

fun! s:MillisToTimecodeString(num)
    fun! PadZeros(slots, val)
        let zeros = repeat('0', a:slots - len(string(a:val)))
        return zeros . a:val
    endfun

    let hours = float2nr(floor(a:num / s:MILLIS_PER_HOUR))
    let mins = float2nr(floor(a:num / s:MILLIS_PER_MIN)) % s:MINS_PER_HOUR
    let secs = float2nr(floor(a:num / s:MILLIS_PER_SEC)) % s:SECS_PER_MIN
    let millis = a:num % s:MILLIS_PER_SEC 

    let [hours, mins, secs] = s:Map([hours, mins, secs], function('PadZeros', [2]))
    let millis = PadZeros(3, millis)

    return hours.':'.mins.':'.secs.','.millis
endfun

" More convenient than the built-in destructive version,
" which feeds key-value pairs.
fun! s:Map(vals, fn)
    let new_vals = []
    for val in a:vals
        call add(new_vals, a:fn(val))
    endfor
    return new_vals
endfun

" Constants
let s:MILLIS_PER_SEC = 1000
let s:MILLIS_PER_MIN = 1000 * 60
let s:MILLIS_PER_HOUR = 1000 * 60 * 60
let s:SECS_PER_MIN = 60
let s:MINS_PER_HOUR = 60

" }}}

