" vim: et ts=2 sts=2 sw=2 fdm=marker

" get wordcount
function! g:ParametricCount()
  return parametric#get()
endfunction

" airline functions
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
