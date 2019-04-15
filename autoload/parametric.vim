" vim: et ts=2 sts=2 sw=2 fdm=marker

" wrapper {{{1
function! parametric#get()
  if s:is_cache_valid()
    return b:parametric_result
  endif

  let b:parametric_changedtick = b:changedtick
  let b:parametric_updates = get(b:, 'parametric_updates', 0) + 1

  let b:parametric_range = s:get_paragraph_range()
  let b:parametric_cache_inclusive = s:get_cached_range(b:parametric_range)

  let b:parametric_metrics = s:get_metrics(b:parametric_range)
  let b:parametric_result = s:format_wordcount(b:parametric_metrics)

  return b:parametric_result
endfunction

" caching {{{1
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

" computation {{{1
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

  let metrics_initial = s:get_metrics_at_line(first_line - 1)
  let metrics_final = s:get_metrics_at_line(following_line)

  " adjust bytes and chars to account for the extra newline we counted before
  " the paragraph
  return {
        \ 'bytes': metrics_final['bytes'] - metrics_initial['bytes'] - 1,
        \ 'chars': metrics_final['chars'] - metrics_initial['chars'] - 1,
        \ 'words': metrics_final['words'] - metrics_initial['words'],
        \ 'lines': lines,
        \ 'range': b:parametric_range,
        \ 'cache_range': b:parametric_cache_inclusive,
        \ }
endfunction

" Return the number of bytes, chars, and words from the beginning of the
" buffer to the indicated (blank) line.
" We have to use the blank lines because wordcount() counts a word at the
" cursor position.
function s:get_metrics_at_line(line)
  if a:line == 0
    " Hard-coded, because wordcount() needs a real line, and 0 never is:
    " it's just a convention to ask about the beginning of the buffer.
    return {
          \ 'bytes': 0,
          \ 'chars': 0,
          \ 'words': 0,
          \ }
  endif

  if a:line > line('$')
    " This line is at the end, so the buffer wordcount has the right
    " numbers, except that it doesn't include the trailing newline; add it
    " back in to byte and character counts
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

  " Always return at least 1 byte and char, even though wordcount() returns zero when
  " an empty buffer doesn't have a trailing newline.
  return {
        \ 'bytes': max([wc['cursor_bytes'], 1]),
        \ 'chars': max([wc['cursor_chars'], 1]),
        \ 'words': wc['cursor_words']
        \ }
endfunction

" formatting {{{1
let s:formatter = get(g:, 'parametric#formatter', 'default')

" convenience function to interface with the formatter call
function! s:format_wordcount(metrics)
  return parametric#formatters#{s:formatter}#to_string(a:metrics)
endfunction

" check that the formatter exists, otherwise fall back to default
if s:formatter !=# 'default'
  execute 'runtime! autoload/parametric/formatters/'.s:formatter.'.vim'
  if !exists('*parametric#formatters#{s:formatter}#to_string')
    let s:formatter = 'default'
  endif
endif
