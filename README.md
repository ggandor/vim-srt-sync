vim-srt-sync
============

Add delay to SRT files from Vim without opening a heavyweight editor or using online tools.


Installation
------------

Source the plugin file in your .vimrc (or use your favorite plugin manager).


Usage
-----
```vim
:call DelaySrt()
``` 
Delay time can be given in milliseconds or as a string in SRT timecode format. When argument is not given, prompts for input.
