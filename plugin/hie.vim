" Barry Arthur, Feb 2015
" A plugin for quickly editing notes

let s:hie_idx = 'hie.idx'

function! s:hie_root()
  return fnamemodify(findfile(s:hie_idx, '.,;'), ':p:h')
endfunction

function! s:idx_path()
  return s:hie_root() . '/' . s:hie_idx
endfunction

function! s:read_hie_idx()
  let idx_path = s:idx_path()
  if ! filereadable(idx_path)
    return []
  else
    return readfile(idx_path)
  endif
endfunction

function! s:write_hie_idx(entries)
  let idx_path = s:idx_path()
  let status = writefile(a:entries, idx_path)
  if status == -1
    throw 'Hie: Unable to write index file: ' . idx_path
  endif
endfunction

let s:term_stack = []

function! s:minify(term)
  return strpart(a:term, 0, 10)
endfunction

function! Hie_term_stack()
  if len(s:term_stack) > 3
    let s = extend(map(s:term_stack[:-3], 's:minify(v:val)'), s:term_stack[-2:])
  else
    let s = s:term_stack
  endif
  return join(s, ' > ')
endfunction

function! s:push_term(term)
  call add(s:term_stack, a:term)
endfunction

function! Hie_pop_term()
  let l =  len(s:term_stack)
  if l > 1
    call remove(s:term_stack, -1)
    let term = remove(s:term_stack, -1)
    call Hie_edit_index_term(term)
  elseif l == 1
    call remove(s:term_stack, -1)
    exe 'edit ' . s:hie_idx
  endif
endfunction

function! s:update_idx_buffer()
  let bn = bufnr(s:hie_idx)
  if bn != -1
    let alt = bufnr('%')
    exe 'buffer ' . bn
    edit!
    exe 'buffer ' . alt
  endif
endfunction

function! Hie_edit_index_term(term)
  let seq = s:find_index_for_term(a:term)
  if seq == -1
    let seq = s:next_seq()
    let entries = s:read_hie_idx()
    call add(entries, seq . "\t" . a:term)
    call s:write_hie_idx(entries)
    silent! call s:update_idx_buffer()
    silent! call Hie_edit_index_seq(seq)
    call append(0, [a:term, repeat('=', len(a:term))])
  else
    silent! call Hie_edit_index_seq(seq)
  endif
  call s:push_term(a:term)
endfunction

function! Hie_terms_search(term)
  return filter(s:read_hie_idx(), 'v:val =~ "^\\S\\+\\t" . a:term . "\\s*$"')
endfunction

function! s:find_index_for_term(term)
  let matches = Hie_terms_search(a:term)
  if empty(matches)
    return -1
  else
    return matchstr(matches[-1], '^\S\+')
  endif
endfunction

function! s:max_data_seq()
  return max(map(filter(glob('data/**/*', 0, 1), '!isdirectory(v:val)'), 'str2nr(fnamemodify(v:val, ":t"), 16)'))
endfunction

function! X()
  return s:max_data_seq()
endfunction

function! s:max_idx_seq()
  return max(map(s:read_hie_idx(), 'str2nr(matchstr(v:val, "^\\S\\+"), 16)'))
endfunction

function! Y()
  return s:max_idx_seq()
endfunction

function! s:next_seq()
  let seq = max([s:max_data_seq(), s:max_idx_seq()])
  return printf("%x", seq + 1)
endfunction

function! s:index_to_path(idx)
  return substitute(a:idx, '^', s:hie_root() . '/data/_' . a:idx[0] . '/', '')
endfunction

function! Hie_edit_index_seq(idx)
  exe 'edit ' . s:index_to_path(a:idx)
endfunction

function! Hie_index_controller()
  nnoremap <buffer> <c-]> :call Hie_edit_index_term(matchstr(getline('.'), '^\S\+\t\s*\zs.*'))<cr>
  nmap     <buffer> gf    <c-]>
  setlocal statusline=[Hie]\ %{Hie_term_stack()}
  setlocal conceallevel=3 concealcursor=nc
  set ft=hieidx
  call Hie_highlight_terms()
endfunction

function! Hie_filetype_controller()
  setlocal conceallevel=3 concealcursor=nc
  setlocal statusline=[Hie]\ %{Hie_term_stack()}
  call Hie_highlight_terms()
  xnoremap <buffer> <c-]> y:call Hie_edit_index_term(expand(@@))<cr>
  nnoremap <buffer> <c-]> :call Hie_edit_index_term(expand('<cword>'))<cr>
  nmap     <buffer> gf    <c-]>
  nnoremap <buffer> <c-t> :call Hie_pop_term()<cr>
endfunction

function! Hie_init()
  if ! exists("*mkdir")
    echohl Error
    echom 'Hie: Cannot create data directory structure becasue Vim lacks mkdir()'
    echohl None
    return
  endif
  for d in range(16)
    call mkdir('data/_' . printf("%x", d), "p", 0700)
  endfor
  call Hie_index_controller()
  call Hie_edit_index_term('Welcome')
  call Hie_filetype_controller()
  call append(3, ["Usage notes", "go", "here"])
  write!
endfunction

augroup Hie
  au!
  exe 'au BufNewFile ' . s:hie_idx . ' silent! call Hie_init()'
  exe 'au BufEnter '   . s:hie_idx . ' call Hie_index_controller()'
  au BufRead,BufNewFile */data/_[0-9a-f]/* call Hie_filetype_controller()
  au BufEnter           */data/_[0-9a-f]/* call Hie_highlight_terms()
augroup END

exe 'command! -nargs=0 -bar Hie silent! edit ' . s:idx_path()


if ! exists('g:hie_highlight_terms')
  let g:hie_highlight_terms = 1
endif

try | silent hi HieTerm  | catch /^Vim\%((\a\+)\)\=:E411/ | hi HieTerm cterm=underline gui=underline | endtry

function! Hie_highlight_terms()
  if g:hie_highlight_terms
    let syn_matches = []
    for line in s:read_hie_idx()
      if line =~ '^\s*\(#.*\)\?$'
        continue
      endif
      call add(syn_matches, matchstr(line, '^\S\+\t\s*\zs.*'))
    endfor
    exe 'syn match HieTerm /' . expand(join(syn_matches, '\\|'), '/') . '/ containedin=ALL'
  else
    call Hie_highlight_clear()
  endif
endfunction

function! Hie_highlight_clear()
  hi clear HieTerm
endfunction
