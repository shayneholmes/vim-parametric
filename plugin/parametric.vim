" vim: et ts=2 sts=2 sw=2 fdm=marker

" get wordcount {{{1
function! g:ParametricCount()
  if s:is_cache_valid()
    return b:parametric_last_count
  endif

  let b:parametric_changedtick = b:changedtick
  let b:parametric_updates = get(b:, 'parametric_updates', 0) + 1

  let b:parametric_last_range = s:get_paragraph_range()
  let b:parametric_last_count = s:get_chars_in_range(b:parametric_last_range)
  return b:parametric_last_count
endfunction

function s:is_cache_valid()
  let currentline = line('.')
  return get(b:, 'parametric_changedtick', 0) == b:changedtick
        \ && exists('b:parametric_last_range')
        \ && currentline >= b:parametric_last_range[0] - 1
        \ && currentline < b:parametric_last_range[1]
endfunction

function s:get_paragraph_range()
  let blanklinepattern = '\m^$'

  let currentline = line('.')
  if empty(getline(currentline))
    " on a paragraph boundary now, choose which direction to look
    if !empty(getline(currentline+1))
      " there's a paragraph just below; use that one
      let precedingblank = currentline
    else
      " nothing forward; consider this the end (look backward)
      let followingblank = currentline
    endif
  endif

  if !exists('precedingblank')
    let precedingblank = search(blanklinepattern, 'nWb')
  endif
  if !exists('followingblank')
    let followingblank = search(blanklinepattern, 'nW')
    if followingblank == 0
      " no match; treat eof as blank
      let followingblank = line('$')+1
    endif
  endif

  let firstline = precedingblank + 1
  let followingline = followingblank

  return [firstline, followingline]
endfunction

function s:get_chars_in_range(range)
  let firstline = a:range[0]
  let followingline = a:range[1]
  let firstchar = line2byte(firstline)
  let followingchar = line2byte(followingline)

  if firstchar < 0 || followingchar < 0
    " invalid lines, like in an empty file
    let firstchar = 0
    let followingchar = 0
  endif

  let size = followingchar - firstchar

  call assert_true(size >= 0, 'Expected size non-negative, but got '.size)

  if &verbose > 0
    let b:parametric_last_count = printf(
          \ '%d updates | %d@%d -> %d@%d = %d',
          \ b:parametric_updates, firstline, firstchar, followingline, followingchar, size)
  else
    let b:parametric_last_count = printf('%d', size)
  endif
  return b:parametric_last_count
endfunction

" airline functions {{{1
if !empty(globpath(&runtimepath, 'plugin/airline.vim', 1))
  function! g:ParametricAirlinePlugin(...)
    function! g:ParametricAirlineFormat()
      let str = printf('¶ %s', ParametricCount())
      return str . g:airline_symbols.space . g:airline_right_alt_sep . g:airline_symbols.space
    endfunction

    let filetypes = get(g:, 'airline#extensions#wordcount#filetypes',
      \ ['asciidoc', 'help', 'mail', 'markdown', 'org', 'rst', 'tex', 'text'])
    if index(filetypes, &filetype) > -1
      call airline#extensions#prepend_to_section(
          \ 'z', '%{ParametricAirlineFormat()}')
    endif
  endfunction

  call airline#add_statusline_func('ParametricAirlinePlugin')
endif
