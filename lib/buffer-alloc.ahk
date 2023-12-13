; ========================================================================
; Buffer class for AHK v1
; developed by TheArkive: source https://www.autohotkey.com/boards/viewtopic.php?f=6&t=123803
; #Requires AutoHotkey v1.1
;
;   Usage:
;
;   var := new Buffer(size, zero := true, chk_err := true)
;
;       By default, all new buffers require a size to be given, and the
;       memory is filled with zeros.  If you do not want to fill the
;       memory with zeros, then set the [zero] param to FALSE.
;
;       Error checking is enabled by default.  If you want to disable it
;       then set the last param to false.  Basically, when a buffer is
;       freed (in __Delete() meta func) then, if error checkig is enabled,
;       an error is thrown.
;
;       In recent tests, and in normal circumstances, errors are not thrown.
;
;   Properties:
;
;       ptr  = the pointer to the memory block
;       size = the size of the memory block
;
;   NOTES:
;
;   These class objects will self destruct when they go out of scope.
; ========================================================================
; class Buffer {
    ; __New(size, zero := true, chk_err := true) {
        ; If !(this.hp := DllCall("Kernel32\GetProcessHeap","UPtr")) ; process heap handle
            ; throw Exception("Failed to get default process heap handle.",-1)
        ; If !(ptr := DllCall("Kernel32\HeapAlloc","UPtr",this.hp,"UInt",(zero?8:0),"UPtr",size,"UPtr"))
            ; throw Exception("Failed to allocate memory.",-1)
        ; this["ptr"] := this["p"] := ptr, this["size"] := this["s"] := size, this["chk_err"] := chk_err
    ; }
    ; __Delete() {
        ; If !DllCall("Kernel32\HeapFree","UPtr",this.hp,"UInt",0,"UPtr",this.ptr) && this["chk_err"]
            ; throw Exception("Freeing of memory block failed.",-1)
    ; }
; }

; ========================================================================
; Buffer class for AHK v1
;
;   Usage:
;
;   var := new Buffer(size, zero := true, chk_err := true)
;
;       By default, all new buffers require a size to be given, and the
;       memory is filled with zeros.  If you do not want to fill the
;       memory with zeros, then set the [zero] param to FALSE.
;
;       Error checking is enabled by default.  If you want to disable it
;       then set the last param to false.  Basically, when a buffer is
;       freed (in __Delete() meta func) then, if error checkig is enabled,
;       an error is thrown.
;
;       In recent tests, and in normal circumstances, errors are not thrown.
;
;   Methods:
;
;       Free(err := true)
;
;           This will manually free the memory block, and returns the
;           error code.
;
;           NOTE: Simply freeing the var with [var := ""] also works, but
;                 no error checking is done in this case.  Usually, as long
;                 as the script is not about to exit, there is no issue
;                 with freeing memory, especially in a single thread context.
;
;       Realloc(size := "", zero := true)
;
;           Reuse the same memory block.  If no params are given, then the
;           original size is used, and the memory is zeroed out.  The ptr
;           may still change.  Returns the new pointer (may change or not).
;
;       SizeCheck(compare := false)
;
;           If [compare = FALSE], then it simply returns the size as reported
;           by the heap.  Otherwise, it compares the heap allocation size to
;           the internally recorded size, and returns TRUE if the sizes match.
;
;   Properties:
;
;       ptr  (or p) = the pointer to the memory block
;       size (or s) = the size of the memory block
;
;   NOTES:
;
;   These class objects will self destruct when they go out of scope.
; ========================================================================
class Buffer {
    __New(sz, z := true) {
        If !(this.hp := DllCall("GetProcessHeap","UPtr"))
            return 0
        If !(ptr:=DlLCall("HeapAlloc","UPtr",this.hp,"UInt",(z?8:0),"UPtr",sz,"UPtr"))
            return -1

        this["ptr"] := ptr
        this["size"] := size
        return 1
    }

    Free() { ; return of zero = fail
        return DllCall("HeapFree","UPtr",this.hp,"UInt",0,"UPtr",this.ptr,"UPtr")
    }

    Realloc(sz := "", z := true) {
        If !(ptr := DllCall("HeapReAlloc","UPtr",this.hp,"UInt",(z?8:0),"UPtr",this.ptr,"UPtr",ns:=((sz="")?this.size:sz)),"UPtr")
            Return 0
        
        this["ptr"] := ptr
        this["size"] := ns
        return ptr
    }

    SizeCheck(compare := false) { ; to check reported size against "this.size"
        sz := DllCall("Kernel32\HeapSize","UPtr",this.hp,"UInt",0,"UPtr",this.ptr,"UPtr")
        return (compare ? (sz = this.size) : sz)
    }

    __Delete() {
        return this.Free()
    }
}

; =========================================
; simple test
; =========================================

; t := new Buffer(5)
; NumPut(-123,t.ptr,"Int")
; msgbox % NumGet(t.ptr,"Int") " / size: " t.SizeCheck()

; =========================================
; byref test
; =========================================

; t := new Buffer(4)

; myFunc(t)
; msgbox % NumGet(t.ptr,"Int") " / size: " t.SizeCheck()

; myfunc(ByRef buf) {
    ; NumPut(-123,buf.ptr,"Int")
; }

; =========================================
; pass from func test
; =========================================

; t := myFunc2()
; msgbox % NumGet(t.ptr,"Int") " / size: " t.SizeCheck()

; myfunc2() {
    ; buf := new Buffer(4)
    ; NumPut(-123,buf.ptr,"Int")
    ; return buf
; }

; t["chk_err"] := true


; =========================================
; mem and speed test
; =========================================

; F1::
    ; msgbox check mem usage now
    ; tick := A_TickCount

    ; Loop 200000
        ; t := new Buffer(4)

    ; time := a_TickCount - tick
    ; msgbox % "time: " time "`n`ncheck mem usage again"
; return
