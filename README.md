vim-slash
=========

vim-slasher (fork of [vim-slash][vim-slash]) provides a set of mappings for enhancing
in-buffer search experience in Vim.

- Automatically clears search highlight when cursor is moved
- Improved-star motion: hit once to highlight, repeat to jump next
- Improved visual star-motion: hit once in visual mode to highlight, repeat to
  move to next highlighted term

Installation
------------

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'junegunn/vim-slash'
```

Comparison with vim-slash
---------------------------

vim-slasher is a fork of [vim-slash][vim-slash] [with additional features rejected by the original author][rejected-features].

It provides:

- Search movement by repeating the star key
- Omits the search text in the status message

Customization
-------------

#### `zz` after search

Places the current match at the center of the window.

```vim
noremap <plug>(slash-after) zz
```

#### Blinking cursor after search using Vim 8 timer

```vim
if has('timers')
  " Blink 2 times with 50ms interval
  noremap <expr> <plug>(slash-after) slasher#blink(2, 50)
endif
```

You can prepend `zz` to the expression: `'zz'.slasher#blink(2, 50)`

Thanks
------

This plugin is based on the amazing work by [Junegunn](https://github.com/junegunn), which brought us
[vim-slash][vim-slash], [vim-plug][vim-plug] and the amazing [fzf][fzf].

[vim-slash]: https://github.com/junegunn/vim-slash]
[rejected-features]: https://github.com/junegunn/vim-slash/pull/9]
[vim-plug]: https://github.com/junegunn/vim-plug]
