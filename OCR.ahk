﻿;==============  Include  ======================================================;

#Include, %A_LineFile%\..\Core.ahk

;============== Function ======================================================;

OCR(file := "") {
	Static image := A_Temp . "\tesseract.tiff", text := A_Temp . "\tesseract"

	if (!(GDIp := LoadLibrary("Gdiplus"))) {
		throw (Exception(Format("0x{:08x}", ErrorLevel), -1, "Could not load the Gdiplus library."))
	}

	DllCall(GDIp.GdiplusStartup, "Ptr*", pToken, "Ptr", CreateGDIplusStartupInput().Ptr, "Ptr", 0)  ;: https://docs.microsoft.com/en-us/windows/win32/api/gdiplusinit/nf-gdiplusinit-gdiplusstartup

	if (FileExist(file)) {
		DllCall(GDIp.GdipCreateBitmapFromFile, "WStr", file, "Ptr*", pBitmap)
	}
	else {
		Static void := ObjBindMethod({}, {})

		Gui, GuiName: New, +AlwaysOnTop -Caption +Border +LastFound +ToolWindow +E0x20
		Gui, Color, % "0xFFFFFF"
		WinSet, Transparent, 80

		Gui, Show, % Format("x{} y{} w{} h{} NA", 0, 0, A_ScreenWidth, A_ScreenHeight)

		Hotkey, *LButton, % void, On
		KeyWait(["Esc", "LButton"], "D")

		start := MouseGet("Pos")

		while (GetKeyState("LButton", "P") && !GetKeyState("Esc", "P")) {
			current := MouseGet("Pos")
				, width := Abs(start.x - current.x) + 1, height := Abs(start.y - current.y) + 1

			if (width >= 5 && height >= 5) {
				x := (start.x < current.x) ? (start.x) : (current.x), y := (start.y < current.y) ? (start.y) : (current.y)

				Gui, Show, % Format("x{} y{} w{} h{} NA", x, y, width, height)
				ToolTip, % Format("{}, {}", width, height)
			}
			else {
				Gui, Hide
				ToolTip
			}

			Sleep, 10
		}

		if (width < 5 || height < 5) {
			x := DllCall("User32\GetSystemMetrics", "Int", 76), y := DllCall("User32\GetSystemMetrics", "Int", 77), width := DllCall("User32\GetSystemMetrics", "Int", 78), height := DllCall("User32\GetSystemMetrics", "Int", 79)
		}

		Gui, GuiName: Destroy
		Hotkey, *LButton, Off

		ToolTip

		if (GetKeyState("Esc", "P")) {
			GoTo, Shutdown
		}

		;* Create the bitmap:
		hDestinationDC := DllCall("Gdi32\CreateCompatibleDC", "Ptr", hSourceDC := DllCall("GetDC", "Ptr", 0, "Ptr"), "Ptr")  ;* Create a compatible DC, which is used in a BitBlt from the source DC (in this case the entire screen).
			, hCompatibleBitmap := DllCall("CreateDIBSection", "Ptr", hDestinationDC, "Ptr", CreateBitmapInfoHeader(width, -height).Ptr, "UInt", 0, "Ptr*", 0, "Ptr", 0, "UInt", 0, "Ptr"), hOriginalBitmap := DllCall("SelectObject", "Ptr", hDestinationDC, "Ptr", hCompatibleBitmap, "Ptr")  ;* Select the device-independent bitmap into the compatible DC.

		DllCall("Gdi32\BitBlt", "Ptr", hDestinationDC, "Int", 0, "Int", 0, "Int", width, "Int", height, "Ptr", hSourceDC, "Int", x, "Int", y, "UInt", 0x00CC0020 | 0x40000000)  ;* Copy a portion of the source DC's bitmap to the destination DC's bitmap.
		DllCall(GDIp.GdipCreateBitmapFromHBITMAP, "Ptr", hCompatibleBitmap, "Ptr", 0, "Ptr*", pBitmap := 0)  ;* Convert the hBitmap to a pBitmap.

		;* Cleanup up:
		DllCall("Gdi32\SelectObject", "Ptr", hDestinationDC, "Ptr", hOriginalBitmap), DllCall("DeleteObject", "Ptr", hCompatibleBitmap), DllCall("Gdi32\DeleteDC", "Ptr", hDestinationDC)
		DllCall("Gdi32\ReleaseDC", "Ptr", 0, "Ptr", hSourceDC)
	}

	;* Save the bitmap to file:
	if (DllCall(GDIp.GdipGetImageEncodersSize, "UInt*", number := 0, "UInt*", size := 0)) {  ;: https://docs.microsoft.com/en-us/windows/win32/gdiplus/-gdiplus-retrieving-the-class-identifier-for-an-encoder-use
		throw (Exception("Could not get a list of image codec encoders on this system."))
	}

	VarSetCapacity(encoders, size)  ;* Fill a buffer with the available encoders.
	DllCall(GDIp.GdipGetImageEncoders, "UInt", number, "UInt", size, "Ptr", (imageCodecInfo := new Structure(size)).Ptr)

	RegExMatch(image, "\.\w+$", extension)

	loop, % number {
		encoderExtensions := StrGet(imageCodecInfo.NumGet((index := (48 + 7*A_PtrSize)*(A_Index - 1)) + 32 + 3*A_PtrSize, "UPtr"), "UTF-16")

		if (InStr(encoderExtensions, "*" . extension)) {
			pCodec := imageCodecInfo.Ptr + index  ;* Get the pointer to the matching encoder.

			break
		}
	}

	if (!pCodec) {
		throw (Exception("Could not find a matching encoder for the specified file format."))
	}

	DllCall(GDIp.GdipSaveImageToFile, "Ptr", pBitmap, "WStr", image, "Ptr", pCodec, "UInt", 0)  ;* Save the bitmap to a .tiff file for tesseract to analyze.
	DllCall(GDIp.GdipDisposeImage, "Ptr", pBitmap)  ;* Dispose of the bitmap.

	RunWait, % Clipboard := Format("{} /c ""{} {} {}""", A_ComSpec, A_WorkingDir . "\bin\Tesseract\tesseract.exe", image, text), , Hide  ;* The extension for the output text file is automatically added here.
	FileRead, content, % text . ".txt"

	FileDelete, % image
	FileDelete, % text . ".txt"

	Shutdown:
	DllCall(GDIp.GdiplusShutdown, "Ptr", pToken)

	return (content)
}