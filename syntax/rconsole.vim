"" Syntax highlighting for R console output

if exists("b:current_syntax")
  finish
endif

syn match rPrompt "^>"
syn match rComment "#.*"
syn match rError "^Error"
syn match rWarning "^Warning"
syn match rWarning "^Warning message:"
syn match rWarning "^There were \d* or more warnings"
syn match rWarning "^There were \d* warnings"

syn keyword rConstant NULL
syn keyword rBoolean  FALSE TRUE
syn keyword rNumber   NA Inf NaN

hi def link rPrompt     PreProc
hi def link rComment    Comment
hi def link rConstant   Constant
hi def link rBoolean    Boolean
hi def link rBoolean    Number
hi def link rError      Error
hi def link rWarning    WarningMsg
