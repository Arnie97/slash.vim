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
"
"
" Disable "search hit BOTTOM, continuing at TOP" message
set shm+=s

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

  return slasher#immobile_wrap(slasher#immobile_star(a:seq))
endfunction

function! slasher#disable_highlight()
  if exists('b:changing_text')
    unlet! b:changing_text
    echo ''
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
  let after = len(maparg("<plug>(slash-after)", mode())) ? "\<plug>(slash-after)" : ''
  return seq . after . ":call slasher#print()\<cr>"
endfunction

function! slasher#trailer_without_move()
  call slasher#create_autocmd()
  return ":call slasher#print()\<cr>"
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

" Setup options.
if !exists('g:searchindex_line_limit')
  let g:searchindex_line_limit=1000000
endif

function! slasher#print()
  let l:dir_char = v:searchforward ? '/' : '?'
  if line('$') > g:searchindex_line_limit
    let l:msg = '[MAX]  ' . l:dir_char . @/
  else
    " If there are no matches, search fails before we get here. The only way
    " we could see zero results is on 'g/' (but that's a reasonable result).
    let [l:current, l:total] = s:MatchCounts()
    let l:msg = '[' . l:current . '/' . l:total . ']  ' . l:dir_char . @/
  endif

  " Flush any delayed screen updates before printing "l:msg".
  " See ":h :echo-redraw".
  redraw | echo l:msg
endfunction

function! s:MatchesInRange(range)
  let gflag = &gdefault ? '' : 'g'
  let output = ''
  redir => output
    silent! execute a:range . 's///en' . gflag
  redir END
  return str2nr(matchstr(output, '\d\+'))
endfunction

" Calculate which match in the current line the 'col' is at.
function! s:MatchInLine() abort
  let line = line('.')
  let col = col('.') - 1

  let cur_line = getline('.')
  let matches = 0
  " The count might be off in edge cases (e.g. regexes that allow empty match,
  " like 'a*'). Unfortunately, Vim's searching functions are so inconsistent
  " that I can't fix this.
  let cur_col = match(cur_line, @/, 0)
  while cur_col <= col && cur_col != -1
    let matches += 1
    let cur_col = match(cur_line, @/, cur_col + 1)
  endwhile

  return matches
endfunction

" Efficiently recalculate number of matches above cursor using values cached
" from the previous run.
function s:MatchesAbove(cached_values)
  " avoid wrapping range at the beginning of file
  if line('.') == 1 | return 0 | endif

  let [old_line, old_result, total] = a:cached_values
  " Find the nearest point from which we can restart match counting (top,
  " bottom, or previously cached line).
  let line = line('.')
  let to_top = line
  let to_old = abs(line - old_line)
  let to_bottom = line('$') - line
  let min_dist = min([to_top, to_old, to_bottom])

  if min_dist == to_top
    return s:MatchesInRange('1,.-1')
  elseif min_dist == to_bottom
    return total - s:MatchesInRange(',$')
  " otherwise, min_dist == to_old, we just need to check relative line order
  elseif old_line < line
    return old_result + s:MatchesInRange(old_line . ',-1')
  elseif old_line > line
    return old_result - s:MatchesInRange(',' . (old_line - 1))
  else " old_line == line
    return old_result
  endif
endfunction

" Return 2-element array, containing current index and total number of matches
" of @/ (last search pattern) in the current buffer.
function! s:MatchCounts()
  " both :s and search() modify cursor position
  let win_view = winsaveview()
  " folds affect range of ex commands (issue #4)
  let save_foldenable = &foldenable
  set nofoldenable

  let in_line = s:MatchInLine()

  let cache_key = [b:changedtick, @/]
  if exists('b:searchindex_cache_key') && b:searchindex_cache_key ==# cache_key
    let before = s:MatchesAbove(b:searchindex_cache_val)
    let total = b:searchindex_cache_val[-1]
  else
    let before = (line('.') == 1 ? 0 : s:MatchesInRange('1,-1'))
    let total = before + s:MatchesInRange(',$')
  endif

  let b:searchindex_cache_val = [line('.'), before, total]
  let b:searchindex_cache_key = cache_key

  let &foldenable = save_foldenable
  call winrestview(win_view)

  return [before + in_line, total]
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
