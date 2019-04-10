function! g:ParametricCount()
  if s:isCacheValid()
    return b:parametric_last_count
  endif

  let b:parametric_changedtick = b:changedtick
  let b:parametric_updates = get(b:, 'parametric_updates', 0) + 1

  let b:parametric_last_range = s:getCurrentParagraphLineRange()
  let b:parametric_last_count = s:getCharacterCount(b:parametric_last_range)
  return b:parametric_last_count
endfunction

function s:isCacheValid()
  let currentline = line('.')
  return get(b:, 'parametric_changedtick', 0) == b:changedtick
        \ && exists('b:parametric_last_range')
        \ && currentline >= b:parametric_last_range[0] - 1
        \ && currentline < b:parametric_last_range[1]
endfunction

function s:getCurrentParagraphLineRange()
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

function s:getCharacterCount(range)
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

if !empty(globpath(&runtimepath, 'plugin/airline.vim', 1))
  function! ParagraphCharacterCountAirlinePlugin(...)
    function! ParagraphCharacterCountFormat()
      let str = printf('¶ %s', ParagraphCharacterCount())
      return str . g:airline_symbols.space . g:airline_right_alt_sep . g:airline_symbols.space
    endfunction

    let filetypes = get(g:, 'airline#extensions#wordcount#filetypes',
      \ ['asciidoc', 'help', 'mail', 'markdown', 'org', 'rst', 'tex', 'text'])
    if index(filetypes, &filetype) > -1
      call airline#extensions#prepend_to_section(
          \ 'z', '%{ParagraphCharacterCountFormat()}')
    endif
  endfunction

  call airline#add_statusline_func('ParagraphCharacterCountAirlinePlugin')
endif
