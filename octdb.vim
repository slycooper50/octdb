vim9script
# Plugin for MRST-Octave
def Echoerr(msg: string)
  echohl ErrorMsg | echom $'[termdebug] {msg}' | echohl None
enddef

def Echowarn(msg: string)
  echohl WarningMsg | echom $'[termdebug] {msg}' | echohl None
enddef

command -nargs=* -complete=file -bang OctDb StartOctDb(<bang>0, <f-args>)
var octproc_id: number
var octbfnr: number
var outbfnr: number
var oct_win: number
var out_win: number
var srcwin: number
var brkpts: dict<any>
var brkpts_sgns: list<number>
var oct_bin: string
var err: string
var vvertical: bool
var allleft: bool 
var out_msg: list<string>
var rec_msg: bool
var brk_cnt: number

def Highlight(init: bool, old: string, new: string)
  var default = init ? 'default ' : ''
  if new ==# 'light' && old !=# 'light'
    exe $"hi {default}debugPC term=reverse ctermbg=lightblue guibg=lightblue"
  elseif new ==# 'dark' && old !=# 'dark'
    exe $"hi {default}debugPC term=reverse ctermbg=darkblue guibg=darkblue"
  endif
enddef

def InitHighlight()
  Highlight(true, '', &background)
  hi default debugBreakpoint term=reverse ctermbg=red guibg=red
  hi default debugBreakpointDisabled term=reverse ctermbg=gray guibg=gray
enddef

def InitVars()
	oct_bin = "octave"
	vvertical = true
	allleft = false 
	brkpts = {}
	brkpts_sgns = []
	rec_msg = false
	brk_cnt = 0

enddef

def OutCB(chan: channel, message: string)
	out_msg = split(message, "\r")
	var brkln = 0
	var entries = {}
	var fname = expand("%")
	for msg in out_msg 
		if msg =~ 'brk'
			brkln = str2nr(split(msg, '=')[1])
			brk_cnt += 1
			var label = slice(printf('%02X', brk_cnt), 0, 2)
			echom $"Breakpoint line number: {brkln}"
			if has_key(brkpts, fname)
				if index(brkpts[fname], brkln) == -1 
					brkpts[fname] = add(brkpts[fname], brkln)
				endif
			else
				brkpts[fname] = [brkln]
			endif
			echom brkpts
			sign_define($'dbgbrk{brkln}', {text: label, texthl: "debugBreakpoint"})
			sign_place(0, 'Breakpoint', $'dbgbrk{brkln}', $'{expand("%")}', {lnum: brkln})
		endif
	endfor	
	#var msg_type = out_msg[0]
	#echom msg_type
	#if msg_type =~ 'brk'
	#endif
enddef

def InitAutocmd()
  augroup TermDebug
    autocmd!
    autocmd ColorScheme * InitHighlight()
  augroup END
enddef

def QuoteArg(x: string): string
  # Find all the occurrences of " and \ and escape them and double quote
  # the resulting string.
  return printf('"%s"', x ->substitute('[\\"]', '\\&', 'g'))
enddef

def SetBreakpoint(at: string)
  # Setting a breakpoint may not work while the program is running.
  # Interrupt to make it work.
  #var do_continue = false
  #if !stopped
  #  do_continue = true
  #  StopCommand()
  #  sleep 10m
  #endif

  # Use the fname:lnum format, older gdb can't handle --source.
	var AT = empty(at) ? $"{QuoteArg(expand('<cword>'))}, {QuoteArg($"{line('.')}")}" : at
	var cmd = $"brk = dbstop ({AT})\r"
	term_sendkeys(octbfnr, cmd)
	#win_gotoid(oct_win)
  #if do_continue
  #  ContinueCommand()
  #endif
enddef

def InstallCommands()
  command -nargs=? Break  SetBreakpoint(<q-args>)
  #command Clear  ClearBreakpoint()
  #command Step  SendResumingCommand('-exec-step')
  #command Over  SendResumingCommand('-exec-next')
  #command -nargs=? Until  Until(<q-args>)
  #command Finish  SendResumingCommand('-exec-finish')
  #command -nargs=* Run  Run(<q-args>)
  #command -nargs=* Arguments  SendResumingCommand('-exec-arguments ' .. <q-args>)
  #command Stop StopCommand()
  #command Continue ContinueCommand()
  #command -nargs=* Frame  Frame(<q-args>)
  #command -count=1 Up  Up(<count>)
  #command -count=1 Down  Down(<count>)
  #command -range -nargs=* Evaluate  Evaluate(<range>, <q-args>)
  #command Gdb  win_gotoid(gdbwin)
  #command Program  GotoProgram()
  #command Source  GotoSourcewinOrCreateIt()
  #command Var  GotoVariableswinOrCreateIt()
  #command Winbar  InstallWinbar(true)
enddef

###################################################################################
# Main function #
# This is a big function break it down later.
def StartOctDb(bang: bool, ...octfile: list<string>)
	InitVars()
	if !executable(oct_bin)
		err = "Could not find Octave executable. "
		return
	endif

  # Assume current window is the source code window
  srcwin = win_getid()

	#################################
	#### Create Output PTY ####
	outbfnr = term_start('NONE', {term_name: "Octave Debugging", vertical: vvertical, out_cb: 'OutCB'})
	var outpty = job_info(term_getjob(outbfnr))['tty_out']
	out_win = win_getid()
  if vvertical
    # Assuming the source code window will get a signcolumn, use two more
    # columns for that, thus one less for the terminal window.
    exe $":{(&columns / 3 - 1)}wincmd |"
    if allleft
      # use the whole left column
      wincmd H
    endif
  endif
	#################################

	#################################
	#### Creat Octave Terminal ####
	octbfnr = term_start(oct_bin, {term_name: "Octave", term_finish: 'close'})
	oct_win = win_getid()
	term_sendkeys(octbfnr, $"PAGER('cat > {outpty}'); page_output_immediately(1);page_screen_output(1)\r")
	#################################

	#### Sign For Program Counter Line ####
  sign_define('debugPC', {linehl: 'debugPC'})
  # Install debugger commands in the text window.
  win_gotoid(srcwin)
  InstallCommands()

					
enddef


#g:octbufnr = term_start('octave', {out_cb: 'SlyCB'})
#term_sendkeys(g:octbufnr, "1+1\<CR>")
#g:octjob = term_getjob(g:octbufnr)
#
#g:shjob = job_start('bash', {callback: 'SlyCB', pty: 1})
#g:shch = job_getchannel(g:shjob)
#ch_sendraw(g:shjob, 'pwd')

InitHighlight()
InitAutocmd()
