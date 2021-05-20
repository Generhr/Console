;============ Auto-Execute ====================================================;
;======================================================  Include  ==============;

#Include %A_LineFile%\..\..\Core.ahk

;===============  Class  =======================================================;

class Console {
	static Window := this.Create()

	static Create() {
		if (!(this.HasProp("Window"))) {
			hWnd := WinGetID("A")

			if (!(DllCall("AllocConsole", "UInt"))) {
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}

			WinHide(DllCall("GetConsoleWindow"))
			WinActivate(hWnd)

			this.Input := DllCall("GetStdHandle", "Int", -10, "Ptr"), this.Output := DllCall("GetStdHandle", "Int", -11, "Ptr")

			this.SetTitle(A_ScriptName)
			this.SetColor(0x0, 0xA)

			if (!(DllCall("SetConsoleCtrlHandler", "UInt", CallbackCreate((ctrlType) => (ctrlType == 0 || ctrlType == 2), "Fast", 1), "UInt", 1, "UInt"))) {  ;: https://docs.microsoft.com/en-us/windows/console/handlerroutine
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}

			GroupAdd("Console", "ahk_id" . hWnd := DllCall("GetConsoleWindow"))

			return (hWnd)
		}
	}

	static Delete() {
		this.Hide()

		if (!(DllCall("FreeConsole", "UInt"))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		this.DeleteProp("Window")
	}

	;-------------- Property ------------------------------------------------------;

	static IsVisible {
		Get {
			return (DllCall("User32\IsWindowVisible", "UInt", this.Window, "UInt") && WinGetMinMax(this.Window) != -1)
		}
	}

	static Color {
		Get {
			return (this.GetColor())
		}
	}

	static GetColor() {
		if (!(DllCall("GetConsoleScreenBufferInfo", "Ptr", this.Output, "Ptr", (consoleScreenBufferInfo := Structure(20)).Ptr, "UInt"))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return ({BackgroundColor: Format("0x{:X}", NumGet(consoleScreenBufferInfo.Ptr + 8, "Short") >> 4), ForegroundColor: Format("0x{:X}", NumGet(consoleScreenBufferInfo.Ptr + 8, "Short") & 0xF)})
	}

	static SetColor(backgroundColor := 0x0, foregroundColor := 0xF) {
		if (!(DllCall("SetConsoleTextAttribute", "Int", this.Output, "Int", backgroundColor << 4 | foregroundColor))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}
	}

	static CursorPosition {
		Get {
			return (this.GetCursorPosition())
		}
	}

	static GetCursorPosition() {
		if (!(DllCall("GetConsoleScreenBufferInfo", "Ptr", this.Output, "Ptr", (consoleScreenBufferInfo := Structure(20)).Ptr))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return ({x: consoleScreenBufferInfo.NumGet(4, "Short"), y: consoleScreenBufferInfo.NumGet(6, "Short")})
	}

	static SetCursorPosition(x, y) {
		if (!(DllCall("SetConsoleCursorPosition", "Ptr", this.Output, "UInt", x << 4 | y, "UInt"))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}
	}

	static Size {
		Get {
			return (this.GetSize())
		}
	}

	static GetSize() {
		if (!(DllCall("GetConsoleScreenBufferInfo", "Ptr", this.Output, "Ptr", (consoleScreenBufferInfo := Structure(20)).Ptr))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return ({Width: consoleScreenBufferInfo.NumGet(0, "Short"), Height: consoleScreenBufferInfo.NumGet(2, "Short")})
	}

	static SetSize(width, height) {
		if (!(DllCall("SetConsoleScreenBufferSize", "Ptr", this.Output, "Ptr", Structure.CreateCoord(width, height).Ptr))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		if (!(DllCall("SetConsoleWindowInfo", "Ptr", this.Output, "UInt", True, "Ptr", Structure.CreateSmallRect(0, 0, width, height).Ptr))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return (DllCall("SetConsoleScreenBufferSize", "Ptr", this.Output, "UInt", width | height << 16))
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
		if (!(DllCall("GetConsoleTitle", "Ptr", (title := Structure(80)).Ptr, "UInt", 80, "UInt"))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return (StrGet(title))
	}

	static SetTitle(title) {
		if (!(DllCall("SetConsoleTitle", "Str", title, "UInt"))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}
	}

	;--------------- Method -------------------------------------------------------;

	static FillOutputCharacter(character, length, x, y) {
		if (!(DllCall("FillConsoleOutputCharacter", "Ptr", this.Output, "Short", Ord(character), "UInt", length, "UInt", x | y << 4, "UInt*", &(numberOfCharsWritten := 0), "UInt"))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return (numberOfCharsWritten)
	}

	static Clear() {
		size := this.GetSize()

		this.SetCursorPosition(0, 0)
		return (this.FillOutputCharacter(A_Space, size.Width*size.Height, 0, 0))
	}

	static Hide(disable := False) {
		visible := this.IsVisible

		if (disable || visible) {
			if (!(DllCall("UnhookWindowsHookEx", "Ptr", this.KeyboardHook, "UInt"))) {
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}

			if (!(DllCall("UnhookWindowsHookEx", "Ptr", this.MouseHook, "UInt"))) {
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}
		}

		if (!(disable) && visible) {
			WinHide(Format("ahk_id{}", this.Window))

			try {
				WinActivate("A")
			}
			catch {
				Send("!{Escape}")
			}
		}
	}

	static Show(enable := False) {
		visible := this.IsVisible

		if (enable || !(visible)) {
			if (!(this.KeyboardHook := DllCall("SetWindowsHookEx", "Int", 13, "Ptr", CallbackCreate(WindowsProc, "Fast"), "Ptr", DllCall("GetModuleHandle", "UInt", 0, "Ptr"), "UInt", 0, "Ptr"))) {
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}

			if (!(this.MouseHook := DllCall("SetWindowsHookEx", "Int", 14, "Ptr", CallbackCreate(WindowsProc, "Fast"), "Ptr", DllCall("GetModuleHandle", "UInt", 0, "Ptr"), "UInt", 0, "Ptr"))) {
				throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
			}

			WindowsProc(nCode, wParam, lParam) {  ;* ** GetAsyncKeyState ** ;: https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getasynckeystate
				Critical(True)

				if (WinActive("ahk_group Console")) {
					static clicked := False

					switch (wParam) {
						case 0x100:  ;? 0x100 = WM_KEYDOWN
							if (GetKeyName(Format("vk{:X}", NumGet(lParam + 0, "UInt"))) == "Escape") {
								Console.Hide()
							}

						case 0x0201:  ;? 0x0201 = WM_LBUTTONDOWN
							CoordMode("Mouse", "Client")
							MouseGetPos(&x, &y)

							if ((!(931 > x || x > 977 || -30 > y || y > -1))) {
								clicked := True
							}
						case 0x0202:  ;? 0x0202 = WM_LBUTTONUP
							if (clicked) {
								CoordMode("Mouse", "Client")
								MouseGetPos(&x, &y)

								if (!(931 > x || x > 977 || -30 > y || y > -1)) {
									Console.Hide()

									return
								}
							}

							clicked := False
					}
				}

				return (DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam))
			}
		}

		if (!(enable || visible)) {
			winTitle := this.Window

			WinShow(winTitle)
			WinSetAlwaysOnTop(True, winTitle)

			WinActivate(winTitle)
			WinWaitActive("A")
		}
	}

	static Read(numberOfCharsToRead := unset) {
		this.Show()

		if (!(IsSet(numberOfCharsToRead))) {
			numberOfCharsToRead := this.GetSize().Width
		}

		this.Hide(True)

		if (!(DllCall("ReadConsole", "Ptr", this.Input, "Ptr", (buffer := Structure(numberOfCharsToRead*2)).Ptr, "UInt", numberOfCharsToRead, "UInt*", &(numberOfCharsRead := 0), "Ptr", Structure.CreateConsoleReadConsoleControl(0, (1 << 0x0A) | (1 << 0x1B)).Ptr, "UInt"))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		this.Show(True)

		return (SubStr(buffer.StrGet(), 1, numberOfCharsRead - 2))  ;* Account for the newline and carriage return characters.
	}

	static Log(text, newLine := True) {
		this.Show()

		if (text.HasProp("Print")) {
			text := text.Print()
		}

		if (newLine) {
			text .= "`n"
		}

		if (!(DllCall("WriteConsole", "Ptr", this.Output, "Str", text, "UInt", StrLen(text), "UInt*", &(written := 0), "Ptr", 0, "UInt"))) {
			throw (ErrorFromMessage(DllCall("Kernel32\GetLastError")))
		}

		return (written - !!(newLine))  ;* Account for the newline character.
	}
}