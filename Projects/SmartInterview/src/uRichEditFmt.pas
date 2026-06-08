unit uRichEditFmt;

interface

uses
  Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics, Winapi.Windows, Winapi.Messages;

procedure ControlHideCaret(C: TWinControl);
procedure RichEditSetRangeColor(RE: TRichEdit; AStart, ALength: Integer; AColor: TColor);
procedure RichEditSetAllColor(RE: TRichEdit; AColor: TColor);
procedure RichEditHideCaret(RE: TRichEdit);

implementation

const
  EM_SETCHARFORMAT = WM_USER + 68;
  SCF_SELECTION = 1;
  CFM_COLOR = $40000000;

type
  TCharFormat2Rec = record
    cbSize: UINT;
    dwMask: Longint;
    dwEffects: Longint;
    yHeight: Longint;
    yOffset: Longint;
    crTextColor: COLORREF;
    bCharSet: Byte;
    bPitchAndFamily: Byte;
    szFaceName: array[0..31] of WideChar;
    wWeight: Word;
    sSpacing: Smallint;
    crBackColor: COLORREF;
    lcid: Longint;
    dwReserved: Longint;
    sStyle: Smallint;
    wKerning: Word;
    bUnderlineType: Byte;
    bAnimation: Byte;
    bRevAuthor: Byte;
    bReserved1: Byte;
  end;

procedure ControlHideCaret(C: TWinControl);
begin
  if C.HandleAllocated then
    HideCaret(C.Handle);
end;

procedure RichEditApplySelFormat(RE: TRichEdit; AColor: TColor);
var
  Fmt: TCharFormat2Rec;
begin
  ZeroMemory(@Fmt, SizeOf(Fmt));
  Fmt.cbSize := SizeOf(Fmt);
  Fmt.dwMask := CFM_COLOR;
  Fmt.crTextColor := ColorToRGB(AColor);
  SendMessage(RE.Handle, EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@Fmt));
end;

procedure RichEditSetRangeColor(RE: TRichEdit; AStart, ALength: Integer; AColor: TColor);
var
  OldStart: Integer;
begin
  if not RE.HandleAllocated then
    Exit;
  if ALength <= 0 then
    Exit;
  OldStart := RE.SelStart;
  RE.SelStart := AStart;
  RE.SelLength := ALength;
  RichEditApplySelFormat(RE, AColor);
  RE.SelStart := OldStart;
  RE.SelLength := 0;
  HideCaret(RE.Handle);
end;

procedure RichEditSetAllColor(RE: TRichEdit; AColor: TColor);
var
  Len: Integer;
begin
  if not RE.HandleAllocated then
    Exit;
  Len := Length(RE.Text);
  if Len = 0 then
    Len := Length(RE.Lines.Text);
  if Len > 0 then
    RichEditSetRangeColor(RE, 0, Len, AColor);
end;

procedure RichEditHideCaret(RE: TRichEdit);
begin
  ControlHideCaret(RE);
end;

end.
