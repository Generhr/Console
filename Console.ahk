#Requires AutoHotkey v2.0-beta.12

/*
* MIT License
*
* Copyright (c) 2022 Onimuru
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

;============ Auto-Execute ====================================================;

#Include ..\Core.ahk

;===============  Class  =======================================================;

class Console {
	static Handle := this.Create()
		, KeyboardHook := "Default", MouseHook := "Default"

	__New(params*) {
		throw (TargetError("This class may not be constructed.", -1))
	}

	static Create() {
		if (!this.HasProp("Window")) {
			try {
				activeHandle := WinGetID("A")
			}
			catch {
				try {
					WinActivate("A")
				}
				catch {
					Send("!{Escape}")
				}
				finally {
					activeHandle := WinGetID("A")
				}
			}

			if (!DllCall("Kernel32\AllocConsole", "UInt")) {
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}

			consoleHandle := DllCall("Kernel32\GetConsoleWindow")

			if (!DllCall("User32\SetWindowPos", "Ptr", consoleHandle, "Ptr", -1  ;? -1 = HWND_TOPMOST
				, "Int", A_ScreenWidth - 800, "Int", 50, "Int", 750, "Int", 500, "UInt", 0x0080, "UInt")) {  ;? 0x0080 = SWP_HIDEWINDOW  ;: https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}

			WinSetStyle(-0x00E40000, consoleHandle)  ;? 0x00E40000 = WS_CAPTION | WS_THICKFRAME | WS_VSCROLL
			WinSetExStyle(+0x00000080, consoleHandle)  ;? 0x00000080 = WS_EX_TOOLWINDOW
			WinSetTransparent(200, consoleHandle)

			WinActivate(activeHandle)

			this.Input := DllCall("Kernel32\GetStdHandle", "Int", -10, "Ptr"), this.Output := DllCall("Kernel32\GetStdHandle", "Int", -11, "Ptr")

			this.SetTitle("Console")
			this.SetColor(0x0, 0xA)

			if (!DllCall("Kernel32\SetConsoleCtrlHandler", "UInt", this.__ConsoleCtrlHandlerCallback := CallbackCreate((ctrlType) => (ctrlType == 0 || ctrlType == 2), "Fast", 1), "UInt", 1, "UInt")) {  ;: https://docs.microsoft.com/en-us/windows/console/handlerroutine
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}

			GroupAdd("Console", "ahk_ID" . consoleHandle)

			return (consoleHandle)
		}
	}

	static Delete() {
		this.Hide()

		CallbackFree(this.__ConsoleCtrlHandlerCallback)

		if (!DllCall("Kernel32\FreeConsole", "UInt")) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		this.DeleteProp("Window")
	}

	static IsVisible {
		Get {
			hWnd := this.Handle

			return (DllCall("User32\IsWindowVisible", "UInt", hWnd, "UInt") && (WinGetMinMax(hWnd) != -1))
		}
	}

	static Color {
		Get {
			return (this.GetColor())
		}
	}

	static GetColor() {
		if (!DllCall("Kernel32\GetConsoleScreenBufferInfo", "Ptr", this.Output, "Ptr", (consoleScreenBufferInfo := Buffer(20)).Ptr, "UInt")) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return ({BackgroundColor: Format("0x{:X}", NumGet(consoleScreenBufferInfo.Ptr + 8, "Short") >> 4), ForegroundColor: Format("0x{:X}", NumGet(consoleScreenBufferInfo.Ptr + 8, "Short") & 0xF)})
	}

	static SetColor(backgroundColor := 0x0, foregroundColor := 0xF) {
		if (!DllCall("Kernel32\SetConsoleTextAttribute", "Int", this.Output, "Int", backgroundColor << 4 | foregroundColor)) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}
	}

	static CursorPosition {
		Get {
			return (this.GetCursorPosition())
		}
	}

	static GetCursorPosition() {
		if (!DllCall("Kernel32\GetConsoleScreenBufferInfo", "Ptr", this.Output, "Ptr", (consoleScreenBufferInfo := Buffer(20)).Ptr)) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return ({x: consoleScreenBufferInfo.NumGet(4, "Short"), y: consoleScreenBufferInfo.NumGet(6, "Short")})
	}

	static SetCursorPosition(x, y) {
		if (!DllCall("Kernel32\SetConsoleCursorPosition", "Ptr", this.Output, "UInt", x << 4 | y, "UInt")) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}
	}

	static Size {
		Get {
			return (this.GetSize())
		}
	}

	static GetSize() {
		if (!DllCall("Kernel32\GetConsoleScreenBufferInfo", "Ptr", this.Output, "Ptr", (consoleScreenBufferInfo := Buffer(20)).Ptr)) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return ({Width: consoleScreenBufferInfo.NumGet(0, "Short"), Height: consoleScreenBufferInfo.NumGet(2, "Short")})
	}

	static SetSize(width, height) {
		if (!DllCall("Kernel32\SetConsoleScreenBufferSize", "Ptr", this.Output, "Ptr", Buffer.CreateCoord(width, height).Ptr)) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		if (!DllCall("Kernel32\SetConsoleWindowInfo", "Ptr", this.Output, "UInt", True, "Ptr", Buffer.CreateSmallRect(0, 0, width, height).Ptr)) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return (DllCall("Kernel32\SetConsoleScreenBufferSize", "Ptr", this.Output, "UInt", width | height << 16))
	}

	static Title {
		Get {
			return (this.GetTitle())
		}

		Set {
			this.SetTitle(value)

			return (value)
		}
	}

	static GetTitle() {
		if (!DllCall("Kernel32\GetConsoleTitle", "Ptr", (title := Buffer(80)).Ptr, "UInt", 80, "UInt")) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return (StrGet(title))
	}

	static SetTitle(title) {
		if (!DllCall("Kernel32\SetConsoleTitle", "Str", title, "UInt")) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}
	}

	static FillOutputCharacter(character, length, x, y) {
		if (!DllCall("Kernel32\FillConsoleOutputCharacter", "Ptr", this.Output, "Short", Ord(character), "UInt", length, "UInt", x | y << 4, "UInt*", &(numberOfCharsWritten := 0), "UInt")) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return (numberOfCharsWritten)
	}

	/**
	 * Shows the console window if it is not already shown.
	 * @param {Boolean} [activate] - Whether or not to activate the console window.
	 * @param {Boolean|Hook} [keyboardHook] - A keyboard hook to be used instead of the default.
	 * @param {Boolean|Hook} [mouseHook] - A mouse hook to be used instead of the default.
	 */
	static Show(activate := False, keyboardHook := True, mouseHook := True) {
		if (!this.IsVisible) {
			DllCall("User32\ShowWindow", "Ptr", this.Handle, "Int", 4 + activate)  ;? 4 = SW_SHOWNOACTIVATE, 5 = SW_SHOW


			if (keyboardHook) {
				if (keyboardHook is Hook) {
					this.KeyboardHook := keyboardHook
				}
				else if (this.KeyboardHook == "Default") {  ;* It is possible to set a hook prior to showing the console and/or not unhooking when hiding the console so only set the default hook if that is not the case and no hook was passed as a parameter.
					this.KeyboardHook := Hook(13, __LowLevelKeyboardProc)

					time := A_TickCount

					__LowLevelKeyboardProc(nCode, wParam, lParam) {
						Critical(True)

						if (!nCode) {  ;? 0 = HC_ACTION
							if (Format("{:#x}", NumGet(lParam, "UInt")) == 0x1B && (WinActive("ahk_group Console") || A_TickCount - time <= 5000)) {  ;? 0x1B = VK_ESCAPE
								if (wParam == 0x0101) {  ;? 0x0101 = WM_KEYUP
									this.Hide()
								}

								return (1)
							}
						}

						return (DllCall("User32\CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr"))
					}
				}
			}

			if (mouseHook) {
				if (mouseHook is Hook) {
					this.MouseHook := mouseHook
				}
				else if (this.MouseHook == "Default") {
					this.MouseHook := Hook(14, __LowLevelMouseProc)

					__LowLevelMouseProc(nCode, wParam, lParam) {
						Critical(True)

						if (!nCode) {
							if (WinActive("ahk_group Console")) {
								switch (wParam) {
									case 0x0201:  ;? 0x0201 = WM_LBUTTONDOWN
								}
							}
						}

						return (DllCall("User32\CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr"))
					}
				}
			}
		}
	}

	/**
	 * Hides the console window if it is not already hidden.
	 * @param {Boolean} [unhook] - Whether or not to unhook the keyboard and mouse hooks.
	 */
	static Hide(unhook := True) {
		if (this.IsVisible) {
			WinHide(this.Handle)

			try {
				WinActivate("A")
			}
			catch {
				Send("!{Escape}")
			}

			if (unhook) {
				this.KeyboardHook := "Default", this.MouseHook := "Default"
			}
		}
	}

	/**
	 * Writes a character string to the console output buffer and shows the window if it is not already shown.
	 * @param {String} [characters] - The characters to be written to the console output buffer.
	 * @param {Boolean} [newLine] - Whether or not to insert a newline character after `characters`.
	 * @return {Integer} - The number of characters actually written to the console output buffer.
	 */
	static Log(characters := "", newLine := True) {
		if (characters != "") {
			this.Show()

			if (characters.HasProp("Print")) {
				characters := characters.Print()
			}

			if (newLine) {
				characters .= "`n"
			}

			if (!DllCall("Kernel32\WriteConsole", "Ptr", this.Output, "Str", characters, "UInt", StrLen(characters), "UInt*", &(written := 0), "Ptr", 0, "UInt")) {  ;: https://learn.microsoft.com/en-us/windows/console/writeconsole
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}

			return (written - !!newLine)  ;* Account for the newline character.
		}
	}

	/**
	 * Reads character input from the console input buffer.
	 * @param {Integer} [numberOfCharsToRead] - The number of characters to be read.
	 * @return {String} - The characters read from the console input buffer.
	 */
	static Read(numberOfCharsToRead := this.GetSize().Width) {
		this.Show()

		try {
			activeHandle := WinGetID("A")
		}
		catch {
			try {
				WinActivate("A")
			}
			catch {
				Send("!{Escape}")
			}
			finally {
				activeHandle := WinGetID("A")
			}
		}

		this.KeyboardHook.UnHook(), this.MouseHook.UnHook()

		WinActivate(this.Handle)

		if (!DllCall("Kernel32\ReadConsole", "Ptr", this.Input, "Ptr", (data := Buffer(numberOfCharsToRead*2)).Ptr, "UInt", numberOfCharsToRead, "UInt*", &(numberOfCharsRead := 0), "Ptr", Buffer.CreateConsoleReadConsoleControl(0, (1 << 0x0A) | (1 << 0x1B)).Ptr, "UInt")) {  ;: https://learn.microsoft.com/en-us/windows/console/readconsole
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		WinActivate(activeHandle)

		this.KeyboardHook.Hook(), this.MouseHook.Hook()

		return (SubStr(RegExReplace(data.StrGet(), "(.*?)\v*$", "$1"), 1, numberOfCharsRead))  ;* Strip the newline character from the end (captured if {Enter} was input before the string exceeded `numberOfCharsToRead`).
	}

	/**
	 * Clear the console output buffer and removes the vertical scroll bar.
	 * @return {Integer} - The number of characters actually written to the console output buffer.
	 */
	static Clear() {
		size := this.GetSize()

		this.SetCursorPosition(0, 0)
		numberOfCharsWritten := this.FillOutputCharacter(A_Space, size.Width*size.Height, 0, 0)

		WinSetStyle(-0x00200000, this.Handle)  ;? 0x00200000 = WS_VSCROLL

		return (numberOfCharsWritten)
	}
}