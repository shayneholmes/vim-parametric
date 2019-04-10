" vim: et ts=2 sts=2 sw=2 fdm=marker

" get wordcount {{{1
function! g:ParametricCount()
  if s:is_cache_valid()
    return b:parametric_result
  endif

  let b:parametric_changedtick = b:changedtick
  let b:parametric_updates = get(b:, 'parametric_updates', 0) + 1

  let b:parametric_range = s:get_paragraph_range()
  let b:parametric_cache_inclusive = s:get_cached_range(b:parametric_range)

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
  let current_line = line('.')
  return get(b:, 'parametric_changedtick', 0) == b:changedtick
        \ && exists('b:parametric_result')
        \ && current_line >= b:parametric_cache_inclusive[0]
        \ && current_line <= b:parametric_cache_inclusive[1]
endfunction

" Return lines that are safe for us not to reevaluate
function s:get_cached_range(paragraph_range)
  let first_line = a:paragraph_range[0]
  let following_line = a:paragraph_range[1]

  let cached_begin = first_line
  let cached_end = following_line

  if first_line != following_line
    " non-empty paragraph, the line above it is safe
    let cached_begin -= 1

    if !empty(getline(following_line+1))
      " there is a paragraph immediately following this one, so the line in between belongs
      " to that one
      let cached_end -= 1
    end
  end

  return [cached_begin, cached_end]
endfunction

" return the range of the active paragraph: [first_line, following_line]
" following_line is the first line not part of the active paragraph
" first_line is part of the active paragraph
" A blank line surrounded by blanks is considered an empty paragraph, with
" both first_line and following_line equal to the current line
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

  " with length 0 chars, 0 words, 0 bytes, and 0 lines

  let metrics_initial = s:get_metrics_at_line(first_line-1)
  let metrics_final = s:get_metrics_at_line(following_line)

  " adjust bytes and chars to account for the extra newline before the
  " paragraph
  return {
        \ 'bytes': metrics_final['bytes'] - metrics_initial['bytes'] - 1,
        \ 'chars': metrics_final['chars'] - metrics_initial['chars'] - 1,
        \ 'words': metrics_final['words'] - metrics_initial['words'],
        \ 'lines': lines,
        \ 'range': b:parametric_range,
        \ 'cache_range': b:parametric_cache_inclusive,
        \ }
endfunction

" return the number of bytes, chars, and words from the beginning of the
" buffer to the indicated (blank) line
function s:get_metrics_at_line(line)
  if a:line == 0
    " Hard-coded, because wordcount() needs a real line, and 0 never is
    return {
          \ 'bytes': 0,
          \ 'chars': 0,
          \ 'words': 0,
          \ }
  endif

  if a:line > line('$')
    " This line is at the end, so the buffer information has the right
    " numbers, but add in the trailing newline that we count as part of the
    " paragraph.
    let wc = wordcount()
    return {
          \ 'bytes': wc['bytes'] + 1,
          \ 'chars': wc['chars'] + 1,
          \ 'words': wc['words'],
          \ }
  endif

  " This is a line in the middle of the buffer; move the cursor there, ask,
  " and restore the cursor
  let save_pos = getcurpos()
  call cursor(a:line, 1)
  let wc = wordcount()
  call setpos('.', save_pos)

  return {
        \ 'bytes': wc['cursor_bytes'],
        \ 'chars': wc['cursor_chars'],
        \ 'words': wc['cursor_words']
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
