function parametric#formatters#debug#to_string(metrics)
  return printf(
        \ '%d updates | %s',
        \ get(b:, 'parametric_updates', 0),
        \ a:metrics)
endfunction
