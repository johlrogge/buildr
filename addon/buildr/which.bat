rem source: http://pankaj-k.net/weblog/2004/11/equivalent_of_which_in_windows.html
@echo off
rem --------------------------------------------------------
rem File: which.cmd
rem Description: Windows equivalent of Unix which command
rem Author: Pankaj Kumar
rem Copyright 2004 Pankaj Kumar. All Rights Reserved.
rem License: This software is available under GPL
rem ---------------------------------------------------------
setlocal
if "%1" == "" goto noArg


set fullpath=%~$PATH:1
if "%fullpath%" == "" goto notFound
echo Found in PATH: %fullpath%
goto end


:noArg
echo No Argument specified
goto end


:notFound
echo Argument "%1" not found in PATH


:end
endlocal
