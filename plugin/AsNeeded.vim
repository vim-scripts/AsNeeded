" AsNeeded: allows functions/maps to reside in .../.vim/AsNeeded/ directory
"           and will enable their loaded as needed
" Author:	Charles E. Campbell, Jr.
" Date:		Jul 12, 2005
" Version:	9
"
" Usage: {{{1
"
" Undefined functions will be caught and loaded automatically, although
" whatever invoked them will then need to be re-run
"
" Undefined maps and commands need to be processed first:
" 	:AsNeeded map         :AN map
" 	:AsNeeded command     :AN command
" will search for the map/command for *.vim files in the AsNeeded directory.
"
" To both find and execute a command or map, use
"   :ANX map
"   :ANX command
"
" To speed up the process, generate a ANtags file
"   :MakeANtags
"
" Isaiah 42:1 : Behold, my servant, whom I uphold; my chosen, in whom {{{1
" my soul delights: I have put my Spirit on him; he will bring forth
" justice to the Gentiles.
"
" GetLatestVimScripts: 915 1 :AutoInstall: AsNeeded.vim
" Load Once: {{{1
if exists("g:loaded_AsNeeded") || &cp
 finish
endif
let g:loaded_AsNeeded = "v9"
let s:keepcpo         = &cpo
set cpo&vim

" ---------------------------------------------------------------------
"  Public Interface:	{{{1
au FuncUndefined *       call AsNeeded(1,expand("<afile>"))
com! -nargs=1 AsNeeded   call AsNeeded(2,<q-args>)
com! -nargs=1 AN         call AsNeeded(2,<q-args>)
com! -nargs=1 ANX        call AsNeeded(3,<q-args>)
com! -nargs=0 MakeANtags call MakeANtags()

" ---------------------------------------------------------------------
"  AsNeeded: looks for maps in AsNeeded/*.vim using the runtimepath. {{{1
"            Returns 0=success
"                   -1=failure
fun! AsNeeded(type,cmdmap)
"  call Dfunc("AsNeeded(type=".a:type.",cmdmap<".a:cmdmap.">)")

  " ------------------------------
  " save&set registers and options {{{2
  " ------------------------------
  let keepa = @a
  let eikeep= &ei
  set lz
  set ei=all

  " -------------------------------------------
  " initialize search for requested command/map {{{2
  " -------------------------------------------
  let keeplastbufnr= bufnr("$")
"  call Decho("keeplastbufnr=".keeplastbufnr)
  silent 1new! AsNeededBuffer
  let asneededbufnr= bufnr("%")
"  call Decho("asneededbufnr=".asneededbufnr)
  setlocal buftype=nofile noswapfile noro nobl

  " -----------------------
  "  check for / use ANtags {{{2
  " -----------------------
  let ANtags= globpath(&rtp,"AsNeeded/ANtags")
  if ANtags != ""
   %d
   exe "silent 0r ".ANtags

   if     a:type ==1
    let srch= search("^f\t".a:cmdmap)
   elseif a:type >= 2
    let srchstring= substitute(a:cmdmap,' .*$','','e')
    if exists("g:mapleader") && match(srchstring,'^'.g:mapleader) == 0
	 let srchstring= substitute(srchstring,'^.\(.*\)$','&\\|<[lL][eE][aA][dD][eE][rR]>\1','')
	 if srchstring =~ '^\\'
	  let srchstring= '\\'.srchstring
	 endif
	endif
    let srch= search('^[mc]\t'.srchstring)
   endif
"   call Decho("using <ANtags>: srchstring<".srchstring."> srch=".srch)

   if srch != 0
   	let curline   = getline(".")
   	let vimfile   = substitute(curline,'^\%(.\+\t\)\{2}\(.*\)$','\1','')
	if curline !~ '^f'
   	 let mapstring = curline
	endif

"	call Decho("vimfile<".vimfile.">")
   endif

  else
"   call Decho("<ANtags> not found, using search")

   " --------------------
   " Set up search string {{{2
   " --------------------
   let srchstring= substitute(a:cmdmap,' .*$','','e')
   if     a:type == 1
    let srchstring= '\<fu\%[nction]!\=\s*\(<[sS][iI][dD]>\|[sS]:\)\='.srchstring.'\>'
   elseif a:type > 1
    if exists("g:mapleader") && match(srchstring,'^'.g:mapleader) == 0
     " allow srchstring to handle map...<Leader>modsrch
	 let  mlgt      = '[>'.escape(escape(g:mapleader,'\'),'\').']'
	 let  modsrch   = substitute(srchstring,g:mapleader,mlgt,'')
    else
     " support searching for maps or commands
	 let  mlgt      = '[>\\\\]'
	 let  modsrch   = substitute(srchstring,'^\\',mlgt,'')
    endif
"    call Decho("mlgt      <".mlgt.">")
"    call Decho("modsrch   <".modsrch.">")
    let srchstring= '\(map\|[nvoilc]m\%[ap]\|\([oilc]\=no\|[nv]n\)\%[remap]\|com\%[mand]\)!\=\s.*'.modsrch.'\s'
"    call Decho("srchstring<".srchstring.">")
   endif

   " --------------------------------
   " search for requested command/map {{{2
   " --------------------------------
   let vimfiles=substitute(globpath(&rtp,"AsNeeded/*.vim"),'\n',',',"ge")
   while vimfiles != ""
    let vimfile = substitute(vimfiles,',.*$','','e')
    let vimfiles= (vimfiles =~ ",")? substitute(vimfiles,'^[^,]*,\(.*\)$','\1','e') : ""
"    call Decho(".considering file<".vimfile.">")
    %d
    exe "silent 0r ".vimfile
    if bufnr("$") > asneededbufnr
"     call Decho("bwipe read-in buf#".bufnr("$")." (> asneededbufnr=".asneededbufnr.")")
     exe bufnr("$")."bwipe!"
    endif
    let srchresult= search(srchstring)
"	call Decho("srchresult=".srchresult)
    if srchresult != 0
     let mapstring = getline(srchresult)
"     call Decho("Found mapstring<".mapstring."> maparg<".maparg(mapstring,'n')."> line#".line(".")." col=".col(".")." <".getline(".").">")
     break
    endif
    let vimfile= ""
   endwhile
  endif
  q!

  " ------------------------------
  " restore registers and settings {{{2
  " ------------------------------
  set nolz
  let @a  = keepa
  let &ei = eikeep

  " ---------------------------
  " source in the selected file {{{2
  " ---------------------------
  if exists("vimfile") && vimfile != ""
"   call Decho("success: sourcing ".vimfile)
   exe "so ".vimfile
   if exists("g:AsNeededSuccess")
    let vimf=substitute(vimfile, $HOME, '\~', '')
    echomsg "***success*** AsNeeded found <".srchstring."> in <".vimf.">; now loaded"
   endif
   " successfully sourced file containing srchstring
   if a:type == 3 && exists("mapstring")
    let maprhs= maparg(a:cmdmap,'n')
"    call Decho("type==".a:type.": maprhs<".maprhs."> mapstring<".mapstring.">")
   	if maprhs == ""
	 " attempt to execute a:cmdmap as a command (with no arguments)
"	 call Decho("exe ".a:cmdmap)
   	 exe "silent! ".a:cmdmap
	else
	 " attempt to execute a:cmdmap as a normal command (ie. a map)
"	 call Decho("norm ".a:cmdmap)
   	 exe "norm ".a:cmdmap
	endif
   endif
   if asneededbufnr > keeplastbufnr
"   	call Decho("bwipe asneeded buf#".asneededbufnr)
    exe asneededbufnr."bwipe!"
   endif
"   call Dret("AsNeeded 0")
   return 0
  endif

  " ----------------------------------------------------------------
  " failed to find srchstring in *.vim files in AsNeeded directories {{{2
  " ----------------------------------------------------------------
"  call Decho("***warning*** AsNeeded unable to find <".a:cmdmap."> in the (runtimepath)/AsNeeded directory")
  echohl WarningMsg
  echomsg "***warning*** AsNeeded unable to find <".a:cmdmap."> in the (runtimepath)/AsNeeded directory"
  echohl NONE
  if asneededbufnr > keeplastbufnr
"   	call Decho("bwipe asneeded buf#".asneededbufnr)
   exe asneededbufnr."bwipe!"
  endif
"  call Dret("AsNeeded -1")
  return -1
endfun

" ---------------------------------------------------------------------
" MakeANtags: makes the (optional) ANtags file {{{1
fun! MakeANtags()
"  call Dfunc("MakeANtags()")

  " ------------------------------
  " save&set registers and options {{{2
  " ------------------------------
  let keepa = @a
  let eikeep= &ei
  set lz
  set ei=all

  " --------------------------------------------------------
  " initialize search for all commands, maps, and functions: {{{2
  " --------------------------------------------------------
  let keeplastbufnr= bufnr("$")
"  call Decho("keeplastbufnr=".keeplastbufnr)
  silent 1new! AsNeededBuffer
  let asneededbufnr= bufnr("%")
"  call Decho("asneededbufnr=".asneededbufnr)
  setlocal noswapfile

  let fncsrch  = '\<fu\%[nction]!\=\s\+\%([sS]:\|<[sS][iI][dD]>\)\@<!\(\u\w*\)\s*('
  let mapsrch  = '\<\%(map\|[nvoilc]m\%[ap]\|[oic]\=no\%[remap]\|[nl]n\%[oremap]\)!\=\s\+\%(<\%([sS][iI][lL][eE][nN][tT]\|[uU][nN][iI][qQ][uU][eE]\|[bB][uU][fF][fF][eE][rR]\|[sS][cC][rR][iI][pP][tT]\)>\s\+\)*\(\S\+\)\s'
  let cmdsrch  = '\<com\%[mand]!\=\s.\{-}\(\u\w*\)\>'
  let fmcsrch  = fncsrch.'\|'.mapsrch.'\|'.cmdsrch
  let mapreject= '\<\%(map\|[nvoilc]m\%[ap]\|[oic]\=no\%[remap]\|[nl]n\%[oremap]\)!\=\s\+\%(<\%([sS][iI][lL][eE][nN][tT]\|[uU][nN][iI][qQ][uU][eE]\|[bB][uU][fF][fF][eE][rR]\|[sS][cC][rR][iI][pP][tT]\)>\s\+\)*<[pP][lL][uU][gG]>\(\u\w*\)\s'

  " remove any old <ANtags>
  if filereadable(globpath(&rtp,"AsNeeded/ANtags"))
"   call Decho("removing old <ANtags>")
   call delete(globpath(&rtp,"AsNeeded/ANtags"))
  endif

  " ---------------------------------------------
  " search for all commands, maps, and functions: {{{2
  " ---------------------------------------------
  let vimfiles= substitute(globpath(&rtp,"AsNeeded/*.vim"),'\n',',',"ge")
  let ANtags  = substitute(vimfiles,'AsNeeded.*','AsNeeded/ANtags','e')
  let first   = 1
"  call Decho("ANtags<".ANtags.">")

  while vimfiles != ""
   let vimfile = substitute(vimfiles,',.*$','','e')
   let vimfiles= (vimfiles =~ ",")? substitute(vimfiles,'^[^,]*,\(.*\)$','\1','e') : ""
"   call Decho("considering file<".vimfile.">")
   %d
   exe "silent 0r ".vimfile
   if bufnr("$") > asneededbufnr
"   	call Decho(".bwipe read-in buf#".bufnr("$"))
    exe bufnr("$")."bwipe!"
   endif

   " clean out all non-map, non-command, non-function lines
   silent! g/^\s*"/d
   silent! g/\c<script>/d
   exe 'silent! %g@'.mapreject.'@d'
   silent! g/^\s*echo\(err\|msg\)\=\>/d
   silent! %s/^\s*exe\%[cute]\s\+['"]\(.*\)['"]/\1/e
   " remove anything that doesn't look like a map, command, or function
   exe "silent! v/".fmcsrch."/d"
"   call Decho("Before conversion to ANtags-style:")
"   call Dredir("%p")

   " convert remaining lines into ANtag-style search patterns
   exe 'silent! %s@^[ \t:]*'.fncsrch.'.*$@f\t\1\t'.escape(vimfile,'@ \').'@e'
   exe 'silent! %s@^.*'.mapsrch.'.*$@m\t\1\t'.escape(vimfile,'@ \').'@e'
   exe 'silent! %s@^[ \t:]*'.cmdsrch.'.*$@c\t\1\t'.escape(vimfile,'@ \').'@e'

   " clean up anything that snuck into <ANtags> that shouldn't be there.
   silent v/^[mfc]\t/d
   silent g/^m\t"\./d
   silent g/^m\t<[sS][iI][dD]>/d
   silent g/^m\t.*'\./d

   " record in <ANtags>
   if  line("$") <= 1 && col("$") <= 2
   	echoerr "***warning*** no tags found in file <".vimfile.">!"
"	call Decho("***warning*** no tags found in file <".vimfile.">!")
"	call Decho("line($)=".line("$")." col($)=".col("$"))
   else
    if first
"     call Decho(".write ".line("$")." tags to ANtags<".ANtags.">")
     exe "silent w! ".ANtags
 	let first= 0
    else
"     call Decho(".append ".line("$")." tags to ANtags<".ANtags.">")
     exe "silent w >>".ANtags
    endif
"	call Decho("After conversion to ANtags-style:")
"    call Dredir("%p")
   endif

   let vimfile= ""
  endwhile
  q!


  " ------------------------------
  " restore registers and settings {{{2
  " ------------------------------
  set nolz
  let @a  = keepa
  let &ei = eikeep

"  call Dret("MakeANtags")
endfun

let &cpo= s:keepcpo
unlet s:keepcpo
" ---------------------------------------------------------------------
" vim: ts=4 fdm=marker
" HelpExtractor:
"  Author:	Charles E. Campbell, Jr.
"  Version:	3
"  Date:	May 25, 2005
"
"  History:
"    v3 May 25, 2005 : requires placement of code in plugin directory
"                      cpo is standardized during extraction
"    v2 Nov 24, 2003 : On Linux/Unix, will make a document directory
"                      if it doesn't exist yet
"
" GetLatestVimScripts: 748 1 HelpExtractor.vim
" ---------------------------------------------------------------------
set lz
let s:HelpExtractor_keepcpo= &cpo
set cpo&vim
let docdir = expand("<sfile>:r").".txt"
if docdir =~ '\<plugin\>'
 let docdir = substitute(docdir,'\<plugin[/\\].*$','doc','')
else
 if has("win32")
  echoerr expand("<sfile>:t").' should first be placed in your vimfiles\plugin directory'
 else
  echoerr expand("<sfile>:t").' should first be placed in your .vim/plugin directory'
 endif
 finish
endif
if !isdirectory(docdir)
 if has("win32")
  echoerr 'Please make '.docdir.' directory first'
  unlet docdir
  finish
 elseif !has("mac")
  exe "!mkdir ".docdir
 endif
endif

let curfile = expand("<sfile>:t:r")
let docfile = substitute(expand("<sfile>:r").".txt",'\<plugin\>','doc','')
exe "silent! 1new ".docfile
silent! %d
exe "silent! 0r ".expand("<sfile>:p")
silent! 1,/^" HelpExtractorDoc:$/d
exe 'silent! %s/%FILE%/'.curfile.'/ge'
exe 'silent! %s/%DATE%/'.strftime("%b %d, %Y").'/ge'
norm! Gdd
silent! wq!
exe "helptags ".substitute(docfile,'^\(.*doc.\).*$','\1','e')

exe "silent! 1new ".expand("<sfile>:p")
1
silent! /^" HelpExtractor:$/,$g/.*/d
silent! wq!

set nolz
unlet docdir
unlet curfile
"unlet docfile
let &cpo= s:HelpExtractor_keepcpo
unlet s:HelpExtractor_keepcpo
finish

" ---------------------------------------------------------------------
" Put the help after the HelpExtractorDoc label...
" HelpExtractorDoc:
*asneeded.txt*	Loading Functions, Maps, and Commands AsNeeded	Feb 17, 2005

Author:  Charles E. Campbell, Jr.  <drNchipO@ScampbellPfamilyA.bizM>
	  (remove NOSPAM from Campbell's email to use)

==============================================================================
1. Contents						*asneeded-contents*

	1. Contents......................: |asneeded-contents|
	2. AsNeeded Manual...............: |asneeded|
	3. AsNeeded Global Variables.....: |asneeded-var|
	4. AsNeeded History..............: |asneeded-history|

==============================================================================
2. AsNeeded Manual				*asneeded*

	The AsNeeded plugin transforms plugin use to either automatically
	loading or assisting in loading plugins when they're needed. >

		:AN command     :ANX command
		:AN map         :ANX map
<
	or >

		:AsNeeded command
		:AsNeeded map
<
	Functions are automatically loaded when called using the FuncUndefined
	event that Vim provides.  :AN or :AsNeeded assists with loading
	commands or maps by searching through plugin files placed in >

		.vim/AsNeeded/       (Unix)
		vimfiles\AsNeeded\   (Windows)
<
	for one containing the desired map or command; once found, AsNeeded
	then loads it.

	The ANX command follows successful searches with an attempt to execute
	the requested command or map.

	For those who have large numbers of scripts in their AsNeeded directory,
	using >
		:MakeANtags
<
	will create a ANtags file in the AsNeeded directory.  This file will then
	be used to quickly look up the requested map, command, or function; the
	usual search of all scripts in the directory will then be bypassed.

==============================================================================
3. AsNeeded Global Variables				*asneeded-var*

   	g:AsNeededSuccess : if this variable exists, then AsNeeded
	                    will inform the user of successful loading
			    of AsNeeded functions/commands/mappings.

==============================================================================
4. AsNeeded History					*asneeded-history*

	v9 Mar 15, 2005 : * MakeANtags command search pattern improved
			  * MakeANtags' function search pattern improved
	   Apr 22, 2005   * maps beginning with a backslash needed one extra
	                    leading backslash in their search pattern for ANtags
	v8 Feb 16, 2005 : * With MakeANtags, AsNeeded's search pattern needed
			    to use \\| instead of \|
	v7 Feb 16, 2005 : * MakeANtags now warns the user when no tags were
			    found in some vim-script file 
			  * MakeANtags would occasionally miss certain maps
			    when making ANtags
			  * MakeANtags was omitting the backslashes in
			    Windows paths
	v6 Sep 20, 2004 : * bug left in debugging code fixed
	   Dec 29, 2004   * wipes out temporarily used buffers
	   Feb 09, 2005   * MakeANtags and ANtags support included
	v5 Aug 06, 2004 : * ANX cmd [args] now accepted.
	                  * improved command vs map detection: uses maparg()
			  * ANX bugfix, now detects maps vs commands and attempts
			    to execute them appropriately
	v4 Jul 12, 2004 : * bugfix: somewhen the AsNeeded loading of commands
			    got dropped.
	v3 May 19, 2004 : * bugfix: now works correctly when mapleader
	                    wasn't set by user explicitly
			  * ANX command/map (an AsNeeded find coupled with
			    execution)
	v2 Apr 05, 2004 : * bugfix: an error message showed up when the
	                    ../.vim/AsNeeded directory was empty of *.vim
			    files
			  * improved warning message when no matching
			    command/function/map is found
	v1 Feb 19, 2004 : AsNeeded first released

vim:tw=78:ts=8:ft=help

