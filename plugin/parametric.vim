" vim: et ts=2 sts=2 sw=2 fdm=marker

" get wordcount {{{1
function! g:ParametricCount()
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

function s:get_paragraph_range()
  let blankline_pattern = '\m^$'

  let current_line = line('.')
  if empty(getline(current_line))
    " on a paragraph boundary now, choose which direction to look
    if !empty(getline(current_line+1))
      " there's a paragraph just below; use that one
      let preceding_blank = current_line
    else
      " nothing forward; consider this the end (look backward)
      let following_blank = current_line
    endif
  endif

  if !exists('preceding_blank')
    let preceding_blank = search(blankline_pattern, 'nWb')
  endif
  if !exists('following_blank')
    let following_blank = search(blankline_pattern, 'nW')
    if following_blank == 0
      " no match; treat eof as blank
      let following_blank = line('$')+1
    endif
  endif

  let first_line = preceding_blank + 1
  let following_line = following_blank

  return [first_line, following_line]
endfunction

function s:get_metrics(range)
  if mode() =~? '[vs]'
    " visual mode; don't try for now
    return {
          \ 'bytes': 0,
          \ 'chars': 0,
          \ 'words': 0,
          \ 'lines': 0,
          \ }
  endif

  let first_line = a:range[0]
  let following_line = a:range[1]

  " compute lines directly, since wordcount() doesn't provide them
  let lines = following_line - first_line

  call assert_true(lines >= 0, 'Expected lines non-negative, but got '.lines)

  let metrics_initial = s:get_initial_metrics(first_line)
  let metrics_final = s:get_final_metrics(following_line)

  return {
        \ 'bytes': metrics_final['bytes'] - metrics_initial['bytes'],
        \ 'chars': metrics_final['chars'] - metrics_initial['chars'],
        \ 'words': metrics_final['words'] - metrics_initial['words'],
        \ 'lines': lines,
        \ 'range': b:parametric_range,
        \ }
endfunction

function s:get_initial_metrics(line)
  if a:line == 1
    " first line, hard-code this because wordcount() counts the word the
    " cursor is on, which may be a word, or may not, if it's whitespace
    return {
          \ 'bytes': 1,
          \ 'chars': 1,
          \ 'words': 0,
          \ }
  endif

  let measurement_line = a:line - 1 " this should be a blank line
  let save_pos = getcurpos()
  call cursor(measurement_line, 1)
  let wc = wordcount()
  call setpos('.', save_pos)

  " add a byte and a character to account for the newline
  let metrics = {
        \ 'bytes': wc['cursor_bytes'] + 1,
        \ 'chars': wc['cursor_chars'] + 1,
        \ 'words': wc['cursor_words']
        \ }

  return metrics
endfunction

function s:get_final_metrics(line)
  if a:line > line('$')
    " the paragraph is at the end, so buffer information has the metrics
    let wc = wordcount()
    let metrics = {
          \ 'bytes': wc['bytes'],
          \ 'chars': wc['chars'],
          \ 'words': wc['words'],
          \ }
  else
    let save_pos = getcurpos()
    call cursor(a:line, 1)
    let wc = wordcount()
    call setpos('.', save_pos)
        " remove the trailing newline, though
    let metrics = {
          \ 'bytes': wc['cursor_bytes'] - 1,
          \ 'chars': wc['cursor_chars'] - 1,
          \ 'words': wc['cursor_words']
          \ }
  endif

  return metrics
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
