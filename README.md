vim-srt-sync
============

Add delay to SRT files from Vim without opening a heavyweight editor or using online tools.


Installation
------------

Source the plugin file in your .vimrc (or use your favorite plugin manager).


Usage
-----
```
:ShiftSrt <time shift>
```

The time shift value can be given as a group of integers, optionally prefixed by
a minus sign. By default, a number is interpreted as a millisecond value.
Hours, minutes, and seconds can be specified by postfixing the number with `h`,
`m`, `s`, respectively. Whitespace and any other characters in the pattern are
skipped altogether.

Examples:
```
:ShiftSrt 750
:ShiftSrt 3s
:ShiftSrt -2m 25s
```

When argument is not given, prompts for input.
