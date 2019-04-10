" vim: et ts=2 sts=2 sw=2 fdm=marker

" get wordcount {{{1
function! g:ParametricCount()
  if s:is_cache_valid()
    return b:parametric_result
  endif

  let b:parametric_changedtick = b:changedtick
  let b:parametric_updates = get(b:, 'parametric_updates', 0) + 1

  let b:parametric_range = s:get_paragraph_range()
  let b:parametric_metrics = s:get_metrics(b:parametric_range)

  let b:parametric_result = printf("%d", b:parametric_metrics['chars'])

  if &verbose > 0 " debug TODO: Move this to a formatter
    let b:parametric_result = printf(
          \ '%d updates | lines %d-%d = %d',
          \ b:parametric_updates,
          \ b:parametric_range[0], b:parametric_range[0],
          \ b:parametric_metrics['chars'])
  endif

  return b:parametric_result
endfunction

function s:is_cache_valid()
  let currentline = line('.')
  return get(b:, 'parametric_changedtick', 0) == b:changedtick
        \ && exists('b:parametric_result')
        \ && exists('b:parametric_range')
        \ && currentline >= b:parametric_range[0] - 1
        \ && currentline < b:parametric_range[1]
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

function s:get_metrics(range)
  let firstline = a:range[0]
  let followingline = a:range[1]
  let firstchar = line2byte(firstline)
  let followingchar = line2byte(followingline)

  if firstchar < 0 || followingchar < 0
    " invalid lines, like in an empty file
    let firstchar = 0
    let followingchar = 0
  endif

  let chars = followingchar - firstchar

  call assert_true(chars >= 0, 'Expected chars non-negative, but got '.chars)

  return {
        \ 'chars': chars,
        \ }
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
