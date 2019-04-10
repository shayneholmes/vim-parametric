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

  let b:parametric_result = printf("%d", b:parametric_metrics['bytes'])

  if &verbose > 0 " debug TODO: Move this to a formatter
    let b:parametric_result = printf(
          \ '%d updates | %s',
          \ b:parametric_updates,
          \ b:parametric_metrics)
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

  let lines = followingline - firstline

  call assert_true(lines >= 0, 'Expected lines non-negative, but got '.lines)

  let cursor_position = getcurpos()
  call cursor(firstline, 1)
  let first_metrics = wordcount()
  if followingline > line('$')
    " the paragraph is at the end, so buffer information has the metrics
    " remove the trailing newline, though
    let last_metrics = {
          \ 'cursor_bytes': first_metrics['bytes'] - 1,
          \ 'cursor_chars': first_metrics['chars'] - 1,
          \ 'cursor_words': first_metrics['words'],
          \ }
  else
    call cursor(followingline, 1)
    let last_metrics = wordcount()
  endif
  call setpos('.', cursor_position)

  return {
        \ 'bytes': last_metrics['cursor_bytes'] - first_metrics['cursor_bytes'],
        \ 'chars': last_metrics['cursor_chars'] - first_metrics['cursor_chars'],
        \ 'words': last_metrics['cursor_words'] - first_metrics['cursor_words'],
        \ 'lines': lines,
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
