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

/*
	** GDIp_Enums: https://github.com/mono/libgdiplus/blob/main/src/gdipenums.h **

;* enum ConsoleColor  ;: https://learn.microsoft.com/en-us/dotnet/api/system.consolecolor?view=net-7.0
	0x0 = Black
	0x9 = Blue
	0xB = Cyan
	0x1 = DarkBlue
	0x3 = DarkCyan
	0x8 = DarkGray
	0x2 = DarkGreen
	0x5 = DarkMagenta
	0x4 = DarkRed
	0x6 = DarkYellow
	0x7 = Gray
	0xA = Green
	0xD = Magenta
	0xC = Red
	0xF = White
	0xE = Yellow
*/

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
				throw (OSError())
			}

			consoleHandle := DllCall("Kernel32\GetConsoleWindow", "Ptr")

			if (!DllCall("User32\SetWindowPos", "Ptr", consoleHandle, "Ptr", -1  ;? -1 = HWND_TOPMOST
				, "Int", A_ScreenWidth - 800, "Int", 50, "Int", 750, "Int", 500, "UInt", 0x0080, "UInt")) {  ;? 0x0080 = SWP_HIDEWINDOW  ;: https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos
				throw (OSError())
			}

			WinSetStyle(-0x00E40000, consoleHandle)  ;? 0x00E40000 = WS_CAPTION | WS_THICKFRAME | WS_VSCROLL
			WinSetExStyle(+0x00000080, consoleHandle)  ;? 0x00000080 = WS_EX_TOOLWINDOW
			WinSetTransparent(200, consoleHandle)

			WinActivate(activeHandle)

			this.Input := DllCall("Kernel32\GetStdHandle", "Int", -10, "Ptr"), this.Output := DllCall("Kernel32\GetStdHandle", "Int", -11, "Ptr")

			this.SetTitle("Console")
			this.SetColor(0xA, 0x0)

			if (!DllCall("Kernel32\SetConsoleCtrlHandler", "UInt", this.__ConsoleCtrlHandlerCallback := CallbackCreate((ctrlType) => (ctrlType == 0 || ctrlType == 2), "Fast", 1), "UInt", 1, "UInt")) {  ;: https://docs.microsoft.com/en-us/windows/console/handlerroutine
				throw (OSError())
			}

			GroupAdd("Console", "ahk_ID" . consoleHandle)

			return (consoleHandle)
		}
	}

	static Delete() {
		this.Hide()

		CallbackFree(this.__ConsoleCtrlHandlerCallback)

		if (!DllCall("Kernel32\FreeConsole", "UInt")) {
			throw (OSError())
		}

		this.DeleteProp("Window")
	}

	static IsVisible {
		Get {
			hWnd := this.Handle

			return (DllCall("User32\IsWindowVisible", "UInt", hWnd, "UInt") && WinGetMinMax(hWnd) != -1)
		}
	}

	static Color {
		Get {
			return (this.GetColor())
		}
	}

	static GetColor() {
		if (!DllCall("Kernel32\GetConsoleScreenBufferInfo", "Ptr", this.Output, "Ptr", (consoleScreenBufferInfo := Buffer(20)).Ptr, "UInt")) {
			throw (OSError())
		}

		return ({BackgroundColor: Format("0x{:X}", NumGet(consoleScreenBufferInfo.Ptr + 8, "Short") >> 4), ForegroundColor: Format("0x{:X}", NumGet(consoleScreenBufferInfo.Ptr + 8, "Short") & 0xF)})
	}

	static SetColor(foregroundColor := 0xA, backgroundColor := 0x0) {
		if (!DllCall("Kernel32\SetConsoleTextAttribute", "Ptr", this.Output, "UInt", foregroundColor | backgroundColor << 4, "UInt")) {
			throw (OSError())
		}
	}

	static CursorPosition {
		Get {
			return (this.GetCursorPosition())
		}
	}

	static GetCursorPosition() {
		if (!DllCall("Kernel32\GetConsoleScreenBufferInfo", "Ptr", this.Output, "Ptr", (consoleScreenBufferInfo := Buffer(20)).Ptr, "UInt")) {
			throw (OSError())
		}

		return ({x: NumGet(consoleScreenBufferInfo.Ptr + 4, "Short"), y: NumGet(consoleScreenBufferInfo.Ptr + 6, "Short")})
	}

	static SetCursorPosition(x, y) {
		if (!DllCall("Kernel32\SetConsoleCursorPosition", "Ptr", this.Output, "UInt", x << 4 | y, "UInt")) {
			throw (OSError())
		}
	}

	static Size {
		Get {
			return (this.GetSize())
		}
	}

	static GetSize() {
		if (!DllCall("Kernel32\GetConsoleScreenBufferInfo", "Ptr", this.Output, "Ptr", (consoleScreenBufferInfo := Buffer(20)).Ptr, "UInt")) {
			throw (OSError())
		}

		return ({Width: NumGet(consoleScreenBufferInfo.Ptr, "Short"), Height: NumGet(consoleScreenBufferInfo.Ptr + 2, "Short")})
	}

	static SetSize(width, height) {
		if (!DllCall("Kernel32\SetConsoleScreenBufferSize", "Ptr", this.Output, "Ptr", __CreateCoord(width, height).Ptr, "UInt")) {
			throw (OSError())
		}

		__CreateCoord(x, y) {
			coord := Buffer(4), NumPut("Short", x, "Short", y, coord)
			return (coord)
		}

		if (!DllCall("Kernel32\SetConsoleWindowInfo", "Ptr", this.Output, "UInt", True, "Ptr", __CreateSmallRect(0, 0, width, height).Ptr, "UInt")) {
			throw (OSError())
		}

		__CreateSmallRect(x, y, width, height) {
			smallRect := Buffer(8), NumPut("Short", x, "Short", y, "Short", x + width - 1, "Short", y + height - 1, smallRect)
			return (smallRect)
		}

		return (DllCall("Kernel32\SetConsoleScreenBufferSize", "Ptr", this.Output, "UInt", width | height << 16, "UInt"))
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
			throw (OSError())
		}

		return (StrGet(title))
	}

	static SetTitle(title) {
		if (!DllCall("Kernel32\SetConsoleTitle", "Str", title, "UInt")) {
			throw (OSError())
		}
	}

	static FillOutputCharacter(character, length, x, y) {
		if (!DllCall("Kernel32\FillConsoleOutputCharacter", "Ptr", this.Output, "Short", Ord(character), "UInt", length, "UInt", x | y << 4, "UInt*", &(numberOfCharsWritten := 0), "UInt")) {
			throw (OSError())
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
				if (keyboardHook.__Class == "Hook") {
					this.KeyboardHook := keyboardHook
				}
				else if (this.KeyboardHook == "Default") {  ;* It is possible to set a hook prior to showing the console and/or not unhooking when hiding the console so only set the default hook if that is not the case and no hook was passed as a parameter.
					this.KeyboardHook := this.Hook(13, __LowLevelKeyboardProc)

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
				if (mouseHook.__Class == "Hook") {
					this.MouseHook := mouseHook
				}
				else if (this.MouseHook == "Default") {
					try {
						this.MouseHook := this.Hook(14, __LowLevelMouseProc)

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
	 * @param {String} characters - The characters to be written to the console output buffer.
	 * @param {Integer} [foregroundColor] -
	 * @param {Boolean} [newLine] - Whether or not to insert a newline character after `characters`.
	 * @return {Integer} - The number of characters actually written to the console output buffer.
	 */
	static Log(characters, foregroundColor?, newLine := True) {
		if (characters != "") {
			this.Show()

			if (characters.HasProp("Print")) {
				characters := characters.Print()
			}

			if (IsSet(foregroundColor)) {
				oldForegroundColor := this.GetColor().ForegroundColor

				this.SetColor(foregroundColor)
			}

			if (newLine) {
				characters .= "`n"
			}

			if (!DllCall("Kernel32\WriteConsole", "Ptr", this.Output, "Str", characters, "UInt", StrLen(characters), "UInt*", &(written := 0), "Ptr", 0, "UInt")) {  ;: https://learn.microsoft.com/en-us/windows/console/writeconsole
				throw (OSError())
			}

			if (IsSet(oldForegroundColor)) {
				this.SetColor(oldForegroundColor)
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

		if (!DllCall("Kernel32\ReadConsole", "Ptr", this.Input, "Ptr", (data := Buffer(numberOfCharsToRead*2)).Ptr, "UInt", numberOfCharsToRead, "UInt*", &(numberOfCharsRead := 0), "Ptr", __CreateConsoleReadConsoleControl(0, (1 << 0x0A) | (1 << 0x1B)).Ptr, "UInt")) {  ;: https://learn.microsoft.com/en-us/windows/console/readconsole
			throw (OSError())
		}

		__CreateConsoleReadConsoleControl(initialChars := 0, ctrlWakeupMask := 0x0A, controlKeyState := 0) {
			consoleReadConsoleControl := Buffer(16), NumPut("UInt", 16, "UInt", initialChars, "UInt", ctrlWakeupMask, "UInt", controlKeyState, consoleReadConsoleControl)
			return (consoleReadConsoleControl)
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

	class Hook {

		/**
		 * Creates a new Hook instance.
		 * @constructor
		 * @param {Integer} idHook - The type of hook procedure to be installed.
		 * @param {Function} function - The DLL or function to use as the callback for the hook.
		 * @param {String} [options]
		 * @returns {Hook}
		 */
		__New(idHook, function, options := "Fast") {
			if (!(hHook := DllCall("User32\SetWindowsHookEx", "Int", idHook, "Ptr", pCallback := CallbackCreate(function, options), "Ptr", DllCall("Kernel32\GetModuleHandle", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr"))) {  ;: https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowshookexw
				throw (OSError())
			}

			this.Handle := hHook, this.Callback := pCallback
				, this.State := 1
		}

		__Delete() {
			if (this.State && !DllCall("User32\UnhookWindowsHookEx", "Ptr", this.Handle, "UInt")) {
				throw (OSError())
			}

			CallbackFree(this.Callback)
		}

		Hook(function?, options := "Fast") {
			if (IsSet(function)) {
				if (this.State) {
					if (!DllCall("User32\UnhookWindowsHookEx", "Ptr", this.Handle, "UInt")) {
						throw (OSError())
					}

					CallbackFree(this.Callback)
				}

				if (!(this.Handle := DllCall("User32\SetWindowsHookEx", "Int", 13, "Ptr", this.Callback := CallbackCreate(function, options), "Ptr", DllCall("Kernel32\GetModuleHandle", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr"))) {
					throw (OSError())
				}
			}
			else if (!this.State && !(this.Handle := DllCall("User32\SetWindowsHookEx", "Int", 13, "Ptr", this.Callback, "Ptr", DllCall("Kernel32\GetModuleHandle", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr"))) {
				throw (OSError())
			}

			this.State := 1
		}

		UnHook() {
			if (!DllCall("User32\UnhookWindowsHookEx", "Ptr", this.Handle, "UInt")) {
				throw (OSError())
			}

			this.State := 0
		}
	}
}