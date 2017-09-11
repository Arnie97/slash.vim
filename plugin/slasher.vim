" The MIT License (MIT)
"
" Copyright (c) 2016 Junegunn Choi
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.

function! slasher#wrap(seq)
  if mode() == 'c' && stridx('/?', getcmdtype()) < 0
    return a:seq
  endif
  silent! autocmd! slash
  return a:seq.":set hlsearch\<CR>\<plug>(slash-trailer)"
endfunction

function! slasher#immobile_wrap(seq)
  if mode() == 'c' && stridx('/?', getcmdtype()) < 0
    return a:seq
  endif
  silent! autocmd! slash
  return a:seq.":set hlsearch\<CR>\<plug>(slash-trailer-without-move)"
endfunction

function! slasher#immobile_star(seq)
  let b:slash_old_register = @s
  if mode() == 'v' && index(['*', '#'], a:seq) >= 0
    let b:slash_repeated_move = 'visual'
    return "\"sy:call setreg('/', slasher#escape(@s))\<CR>:let @s = b:slash_old_register\<CR>"
  elseif mode() == 'n' && index(['*', '#'], a:seq) >= 0
    let b:slash_repeated_move = 'normal'
    return ":call setreg('/', '\\<'.expand('<cword>').'\\>')\<CR>"
  elseif mode() == 'n' && index(['g*', 'g#'], a:seq) >= 0
    let b:slash_repeated_move = 'normal'
    return ":call setreg('/', expand('<cword>'))\<CR>"
  else
    return ''
  endif
endfunction

function! slasher#revert_search_direction(key)
  if a:key ==# 'n'
    return 'N'
  elseif a:key ==# 'N'
    return 'n'
  elseif
    return a:key
  endif
endfunction

function! slasher#star_to_forward_backward(key)
  if a:key ==# '*'
    return 'n'
  elseif a:key ==# '#'
    return 'N'
  else
    return a:key
  endif
endfunction

function! slasher#immobile(seq)
  let repeated_move = get(b:, 'slash_repeated_move', '')

  if repeated_move ==# 'normal'
    return slasher#wrap(a:seq)
  elseif repeated_move ==# 'visual'
    return slasher#wrap(slasher#star_to_forward_backward(a:seq))
  endif

  let s:winline = winline()
  return slasher#immobile_wrap(slasher#immobile_star(a:seq))
endfunction

function! slasher#disable_highlight()
  if exists('b:changing_text')
    unlet! b:changing_text
    return
  endif

  set nohlsearch
  let b:slash_repeated_move = ''
  autocmd! slash
endfunction

function! slasher#create_autocmd()
  augroup slash
    autocmd!
    autocmd InsertLeave * let b:changing_text = 1
    autocmd CursorMoved * call slasher#disable_highlight()
  augroup END
endfunction

function! slasher#trailer()
  call slasher#create_autocmd()

  let seq = foldclosed('.') != -1 ? 'zo' : ''
  if exists('s:winline')
    let sdiff = winline() - s:winline
    unlet s:winline
    if sdiff > 0
      let seq .= sdiff."\<c-e>"
    elseif sdiff < 0
      let seq .= -sdiff."\<c-y>"
    endif
  endif
  let after = len(maparg("<plug>(slash-after)", mode())) ? "\<plug>(slash-after)" : ''
  return seq . after
endfunction

function! slasher#trailer_without_move()
  call slasher#create_autocmd()
  return ''
endfunction

function! slasher#trailer_on_leave()
  augroup slash
    autocmd!
    autocmd InsertLeave * call slasher#trailer()
  augroup END
  return ''
endfunction

function! slasher#escape(contents)
  return '\V'.substitute(escape(a:contents, '\/'), "\n", '\\n', 'g')
endfunction

function! slasher#blink(times, delay)
  let s:blink = { 'ticks': 2 * a:times, 'delay': a:delay }

  function! s:blink.tick(_)
    let self.ticks -= 1
    let active = self == s:blink && self.ticks > 0

    if !self.clear() && active && &hlsearch
      let [line, col] = [line('.'), col('.')]
      let w:blink_id = matchadd('IncSearch',
            \ printf('\%%%dl\%%>%dc\%%<%dc', line, max([0, col-2]), col+2))
    endif
    if active
      call timer_start(self.delay, self.tick)
    endif
  endfunction

  function! s:blink.clear()
    if exists('w:blink_id')
      call matchdelete(w:blink_id)
      unlet w:blink_id
      return 1
    endif
  endfunction

  call s:blink.clear()
  call s:blink.tick(0)
  return ''
endfunction

map      <expr> <plug>(slash-trailer) slasher#trailer()
map      <expr> <plug>(slash-trailer-without-move) slasher#trailer_without_move()
imap     <expr> <plug>(slash-trailer) slasher#trailer_on_leave()
cnoremap        <plug>(slash-cr)      <cr>
noremap         <plug>(slash-prev)    <c-o>
inoremap        <plug>(slash-prev)    <nop>

cmap <silent><expr> <cr> slasher#wrap("\<cr>")
map  <silent><expr> n    slasher#wrap('n')
map  <silent><expr> N    slasher#wrap('N')
map  <silent><expr> gd   slasher#wrap('gd')
map  <silent><expr> gD   slasher#wrap('gD')
map  <silent><expr> *    slasher#immobile('*')
map  <silent><expr> #    slasher#immobile('#')
map  <silent><expr> g*   slasher#immobile('g*')
map  <silent><expr> g#   slasher#immobile('g#')
xmap <silent><expr> *    slasher#immobile('*')
xmap <silent><expr> #    slasher#immobile('#')
