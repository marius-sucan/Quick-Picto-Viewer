class cli {
; from Bugz000; thank you <3

; usage example:
; cmdObj := new cli("CMD.exe /Q /K","","CP850")
; cmdObj.Write("ping www.jesus.com")
; output := cmdObj.Read()
; cmdObj.Close()

    __New(sCmd, sDir:="",codepage:="CP850") {
      DllCall("CreatePipe","UPtr*",hStdInRd,"UPtr*",hStdInWr,"Uint",0,"Uint",0)
      DllCall("CreatePipe","UPtr*",hStdOutRd,"UPtr*",hStdOutWr,"Uint",0,"Uint",0)
      DllCall("SetHandleInformation","UPtr",hStdInRd,"Uint",1,"Uint",1)
      DllCall("SetHandleInformation","UPtr",hStdOutWr,"Uint",1,"Uint",1)
      if (A_PtrSize=4)
      {
         VarSetCapacity(pi, 16, 0)
         sisize := VarSetCapacity(si,68,0)
         NumPut(sisize, si,  0, "UInt")
         NumPut(0x100, si, 44, "UInt")
         NumPut(hStdInRd , si, 56, "UPtr")
         NumPut(hStdOutWr, si, 60, "UPtr")
         NumPut(hStdOutWr, si, 64, "UPtr")
      } else if (A_PtrSize=8)
      {
         VarSetCapacity(pi, 24, 0)
         sisize := VarSetCapacity(si,96,0)
         NumPut(sisize, si,  0, "UInt")
         NumPut(0x100, si, 60, "UInt")
         NumPut(hStdInRd , si, 80, "UPtr")
         NumPut(hStdOutWr, si, 88, "UPtr")
         NumPut(hStdOutWr, si, 96, "UPtr")
      }

      pid := DllCall("CreateProcess", "Uint", 0, "UPtr", &sCmd, "Uint", 0, "Uint", 0, "Int", True, "Uint", 0x08000000, "Uint", 0, "UPtr", sDir ? &sDir : 0, "UPtr", &si, "UPtr", &pi)
      DllCall("CloseHandle","UPtr",NumGet(pi,0))
      DllCall("CloseHandle","UPtr",NumGet(pi,A_PtrSize))
      DllCall("CloseHandle","UPtr",hStdOutWr)
      DllCall("CloseHandle","UPtr",hStdInRd)
      ; Create an object.
      this.hStdInWr  := hStdInWr
      this.hStdOutRd := hStdOutRd
      this.pid := pid
      this.codepage := (codepage="") ? A_FileEncoding : codepage
   }

    __Delete() {
        this.close()
    }

    close() {
       hStdInWr := this.hStdInWr
       hStdOutRd := this.hStdOutRd
       DllCall("CloseHandle","UPtr",hStdInWr)
       DllCall("CloseHandle","UPtr",hStdOutRd)
   }

   write(sInput:="") {
      If (sInput!="")
      {
         f := FileOpen(this.hStdInWr, "h", this.codepage)
         If IsObject(f)
         {
            f.Write(sInput)
            f.Close()
            return 1
         }
      }
      return 0
   }

   readline() {
      fout := FileOpen(this.hStdOutRd, "h", this.codepage)
      this.AtEOF := fout.AtEOF
      if IsObject(fout)
      {
         If (fout.AtEOF=0)
            z := fout.ReadLine()
         fout.Close()
         return z
      }
      return
   }

   read(chars:="") {
      fout := FileOpen(this.hStdOutRd, "h", this.codepage)
      this.AtEOF := fout.AtEOF
      if (IsObject(fout) && fout.AtEOF=0)
      {
         If (fout.AtEOF=0)
            z := (chars="") ? fout.Read() : fout.Read(chars)
         fout.Close()
         return z
      }
      return
   }
}

Cli_RunCMD(CmdLine, WorkingDir:="", Codepage:="CP850", Fn:="RunCMD_Output", maxDelay:=15250) {
  ; Local         ; RunCMD v0.94 by SKAN on D34E/D37C @ https://www.autohotkey.com/boards/viewtopic.php?t=74647                                                             
  ; Global A_Args ; Based on StdOutToVar.ahk by Sean @ https://www.autohotkey.com/board/topic/15455-stdouttovar
  ; modified by Marius Șucan; added the maxDelay parameter

  Fn := IsFunc(Fn) ? Func(Fn) : 0
  r := DllCall("CreatePipe", "UPtr*",hPipeR:=0, "UPtr*",hPipeW:=0, "UPtr",0, "Int",0)
  If (r=0 || r="")
     Return

  DllCall("SetHandleInformation", "UPtr",hPipeW, "Int",1, "Int",1)
  DllCall("SetNamedPipeHandleState","UPtr",hPipeR, "UInt*",PIPE_NOWAIT:=1, "UPtr",0, "UPtr",0)

  P8 := (A_PtrSize=8) ? 1 : 0
  VarSetCapacity(SI, P8 ? 104 : 68, 0)                          ; STARTUPINFO structure      
  NumPut(P8 ? 104 : 68, SI)                                     ; size of STARTUPINFO
  NumPut(STARTF_USESTDHANDLES:=0x100, SI, P8 ? 60 : 44,"UInt")  ; dwFlags
  NumPut(hPipeW, SI, P8 ? 88 : 60)                              ; hStdOutput
  NumPut(hPipeW, SI, P8 ? 96 : 64)                              ; hStdError
  VarSetCapacity(PI, P8 ? 24 : 16)                              ; PROCESS_INFORMATION structure
  g := DllCall("GetPriorityClass", "UPtr",-1, "UInt")
  r := DllCall("CreateProcess", "UPtr",0, "Str",CmdLine, "UPtr",0, "Int",0, "Int",1
            ,"Int",0x08000000 | g, "Int",0
            ,"UPtr",WorkingDir ? &WorkingDir : 0, "UPtr",&SI, "UPtr",&PI)

  If (r=0 || r="")
  {
     z := ErrorLevel "|" A_LastError
     DllCall("CloseHandle", "UPtr",hPipeW)
     DllCall("CloseHandle", "UPtr",hPipeR)
     Return ; z
  }

  DllCall("CloseHandle", "UPtr",hPipeW)
  PIDu := NumGet(PI, P8? 16 : 8, "UInt")
  hProcess := NumGet(PI, 0)
  hThread  := NumGet(PI, A_PtrSize)
  A_Args.RunCMD := {"PID": PIDu}
  FileObj := FileOpen(hPipeR, "h", Codepage)
  startTime := A_TickCount
  LineNum := 1,  sOutput := ""
  timeOut := 0
  While ((A_Args.RunCMD.PID + DllCall("Sleep", "Int",0)) && DllCall("PeekNamedPipe", "UPtr",hPipeR, "UPtr",0, "Int",0, "UPtr",0, "UPtr",0, "UPtr",0))
  {
       If (A_TickCount - startTime>maxDelay)
       {
          timeOut := 1
          Break
       }
       While (A_Args.RunCMD.PID and (Line := FileObj.ReadLine()))
       {
            sOutput .= Fn ? Fn.Call(Line, LineNum++) : Line
            If (A_TickCount - startTime>maxDelay)
            {
               timeOut := 1
               Break
            }
       }
  }

  If (timeOut=1)
  {
     SoundBeep 300, 100
     Process, Close, % PIDu
  }

  A_Args.RunCMD.PID := 0
  DllCall("GetExitCodeProcess", "UPtr",hProcess, "UPtr*",ExitCode:=0)
  DllCall("CloseHandle", "UPtr",hProcess)
  DllCall("CloseHandle", "UPtr",hThread)
  DllCall("CloseHandle", "UPtr",hPipeR)
  FileObj.Close()
  ErrorLevel := ExitCode
  Return sOutput
}
