" File: apexExecuteAnonymous.vim
" This file is part of vim-force.com plugin
"   https://github.com/neowit/vim-force.com
" Author: Andrey Gavrikov 
" Maintainers: 
" Last Modified: 2014-11-27
"
" apexExecuteAnonymous.vim - support for calling 'executeAnonymous' &
" 'soqlQuery' commands
"
if exists("g:loaded_apexExecuteAnonymous") || &compatible
	  finish
endif
let g:loaded_apexExecuteAnonymous = 1

let s:lastExecuteAnonymousFilePath = ''
"execute piece of code via executeAnonymous
"This function can accept visual selection or whole buffer and
"runs executeAnonymous on that code
"Args:
"Param: filePath - file which contains the code to be executed
function apexExecuteAnonymous#run(method, filePath, ...) range
	let projectPair = apex#getSFDCProjectPathAndName(a:filePath)
	let projectName = projectPair.name
	if a:0 > 0 && len(a:1) > 0
		let projectName = apexUtil#unescapeFileName(a:1)
	endif
	
	let totalLines = line('$') " last line number in current buffer
	let lines = getbufline(bufnr("%"), a:firstline, a:lastline)

	if len(lines) < totalLines
		"looks like we are working with visual selection, not whole buffer
		"with visual selection we often select lines which are commented out
		"inside * block
		" pre-process lines - remove comment character '*'
		let processedLines = []
		for line in lines
			" remove * if it is first non-space character on the line
			let line = substitute(line, "^[ ]*\\*", "", "")
			call add(processedLines, line)
		endfor
		let lines = processedLines
	endif
	
	if !empty(lines)
		let codeFile = tempname()
		if 'executeAnonymous' == a:method
			let s:lastExecuteAnonymousFilePath = codeFile " record file path for future use in executeAnonymousRepeat
		elseif 'soqlQuery' == a:method
			let s:lastSoqlQueryFilePath = codeFile " record file path for future use in executeAnonymousRepeat
		endif
		call writefile(lines, codeFile)
		if 'executeAnonymous' == a:method
			call s:executeAnonymous(a:filePath, projectName, codeFile)
		elseif 'soqlQuery' == a:method
			call s:executeSoqlQuery(a:filePath, projectName, codeFile)
		endif
	endif
endfunction	

"re-run last block of code executed with ExecuteAnonymous
"Param1: (optional) - project name
function apexExecuteAnonymous#repeat(method, filePath, ...)
	let codeFile = s:lastExecuteAnonymousFilePath
	if 'soqlQuery' == a:method
		let codeFile = s:lastSoqlQueryFilePath
	endif
	if len(codeFile) < 1
		call apexUtil#warning('Nothing to repeat')
		return -1
	endif
	let projectPair = apex#getSFDCProjectPathAndName(a:filePath)
	let projectName = projectPair.name
	if a:0 > 0 && len(a:1) > 0
		let projectName = apexUtil#unescapeFileName(a:1)
	endif
	
	if 'executeAnonymous' == a:method
		call s:executeAnonymous(a:filePath, projectName, codeFile)
	elseif 'soqlQuery' == a:method
		call s:executeSoqlQuery(a:filePath, projectName, codeFile)
	endif
endfunction

function s:executeAnonymous(filePath, projectName, codeFile)
	call apexTooling#askLogLevel()

	let projectPair = apex#getSFDCProjectPathAndName(a:filePath)
	let projectPath = projectPair.path
	let l:extraParams = {"codeFile": apexOs#shellescape(a:codeFile)}
	" another org?
	if projectPair.name != a:projectName
		let l:extraParams["callingAnotherOrg"] = "true"
	endif
	let resMap = apexTooling#execute("executeAnonymous", a:projectName, projectPath, l:extraParams, [])
	if 'None' != g:apex_test_logType
		if "true" == resMap.success
			:ApexLog
		endif
	endif
endfunction	

let s:lastSoqlQueryFilePath = ''
function s:executeSoqlQuery(filePath, projectName, codeFile)
	"call apexTooling#askLogLevel()

	let projectPair = apex#getSFDCProjectPathAndName(a:filePath)
	let projectPath = projectPair.path
	let outputFilePath = tempname()
	let l:extraParams = {"queryFilePath": apexOs#shellescape(a:codeFile), 'outputFilePath':  apexOs#shellescape(outputFilePath)}
	" another org?
	if projectPair.name != a:projectName
		let l:extraParams["callingAnotherOrg"] = "true"
	endif
	let resMap = apexTooling#execute("soqlQuery", a:projectName, projectPath, l:extraParams, [])
	if "true" == resMap.success
		" load result file if available and show it in a read/only buffer
		if len(apexUtil#grepFile(resMap.responseFilePath, 'RESULT_FILE')) > 0
			execute "edit " . fnameescape(outputFilePath)
		endif
	endif
endfunction	
