" vim-srt-sync
" Author: Gyorgy Andorka <gyorgy.andorka@protonmail.com>
" License: The Unlicense


if exists('g:loaded_srt_sync') | finish | endif
let g:loaded_srt_sync = 1

command! -nargs=? ShiftSrt call s:ShiftSrt('<args>')

let s:timecode_p = '\v\d{2}:\d{2}:\d{2},\d{3}'
let s:timecode_line_p = '\v^' . s:timecode_p . ' --\> ' . s:timecode_p . '\s*$'

fun! s:ShiftSrt(input)
    let input = a:input
    if input == ""
        let input = trim(input('shift timecodes by: '))
        " then <Esc> suffices instead of <C-c>
        if len(input) == 0 | return | endif
    endif

    let [hours, mins, secs, millis] = s:ParseInput(input)

    let shift = ((hours * s:millis_per_hour)
                \ + (mins * s:millis_per_min)
                \ + (secs * s:millis_per_sec)
                \ + millis)
    if input[0] == '-' | let shift = -shift | endif
    if shift != 0
        call s:ShiftLines(shift)
    else
        redraw | echo 'Cannot apply: malformed input'
    endif
endfun

fun! s:ParseInput(input)
    let hours = matchstr(a:input, '\d\+h')
    let mins = matchstr(a:input, '\d\+m')
    let secs = matchstr(a:input, '\d\+s')
    let millis = matchstr(a:input, '\v\d+(\d|[hms])@!')
    return map([hours, mins, secs, millis], {_, val -> str2nr(val)})
endfun

fun! s:ShiftLines(shift)
    let saved_view = winsaveview()
    redraw | echo "Shifting timecodes..."
    try
        for line_num in range(1, line('$'))
            let line = (getline(line_num))
            if line =~ s:timecode_line_p
                let shifted_line = s:ShiftedLine(line, a:shift)
                exe 'keepjumps keeppatterns ' . line_num . 's/.*/\=shifted_line/'
            endif
        endfor
        redraw | echo ""
    " We can assume this error will be thrown right at the very first
    " timecode line, if at all, so no state change to worry about.
    catch 'illegal timecode value'
        redraw | echo 'Cannot apply: the given time shift would result'
                    \ . ' in negative timecode value(s)'
    finally
        call winrestview(saved_view)
    endtry
endfun

fun! s:ShiftedLine(timecode_line, shift)
    return substitute(a:timecode_line, s:timecode_p,
                \ '\=s:ShiftedTimecode(submatch(0), a:shift)', 'g')
endfun

fun! s:ShiftedTimecode(timecode, shift)
    let new_time = s:TimecodeToMillis(a:timecode) + a:shift
    if new_time < 0 | throw 'illegal timecode value' | endif
    return s:MillisToTimecode(new_time)
endfun

fun! s:TimecodeToMillis(timecode)
    let [hours_mins_secs, millis] = split(a:timecode, ',')
    let [hours, mins, secs] = split(hours_mins_secs, ':')
    return (hours * s:millis_per_hour)
                \ + (mins * s:millis_per_min)
                \ + (secs * s:millis_per_sec)
                \ + millis
endfun

fun! s:MillisToTimecode(n)
    fun! PadZeros(slots_to_fill, val)
        let padding_zeros = repeat('0', a:slots_to_fill - len(string(a:val)))
        return padding_zeros . a:val
    endfun

    let hours = float2nr(floor(a:n / s:millis_per_hour))
    let mins = float2nr(floor(a:n / s:millis_per_min)) % s:mins_per_hour
    let secs = float2nr(floor(a:n / s:millis_per_sec)) % s:secs_per_min
    let millis = a:n % s:millis_per_sec
    let [hours, mins, secs] = map([hours, mins, secs], {_, val -> PadZeros(2, val)})
    let millis = PadZeros(3, millis)
    return hours . ':' . mins . ':' . secs . ',' . millis
endfun

let s:millis_per_sec = 1000
let s:millis_per_min = 1000 * 60
let s:millis_per_hour = 1000 * 60 * 60
let s:secs_per_min = 60
let s:mins_per_hour = 60

