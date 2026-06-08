unit uReadAlongMatcher;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TReadAlongMatcher = class
  private
    FWords: TList<string>;
    FOffsets: TList<Integer>;
    FPointer: Integer;
    function GetCount: Integer;
    function GetAtEnd: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetText(const Text: string);
    function Advance(const SpokenText: string): Boolean;
    function CurrentCharOffset(TotalLength: Integer): Integer;
    property PointerIndex: Integer read FPointer;
    property Count: Integer read GetCount;
    property AtEnd: Boolean read GetAtEnd;
    property Words: TList<string> read FWords;
    property CharOffsets: TList<Integer> read FOffsets;
  end;

implementation

uses
  System.Math,
  System.Character,
  Winapi.Windows;

function NormalizeWord(const W: string): string;
var
  Nfd: string;
  I: Integer;
  C: Char;
begin
  SetLength(Nfd, Length(W) * 2 + 2);
  I := NormalizeString(NormalizationD, PWideChar(W), Length(W), PWideChar(Nfd), Length(Nfd));
  if I > 0 then
    SetLength(Nfd, I - 1)
  else
    Nfd := W;

  Result := '';
  for C in Nfd do
  begin
    if TCharacter.GetUnicodeCategory(C) = TUnicodeCategory.ucNonSpacingMark then
      Continue;
    if TCharacter.IsLetterOrDigit(C) then
      Result := Result + LowerCase(C);
  end;
end;

function Tokenize(const Text: string): TList<string>;
var
  I, Start: Integer;
  Norm: string;
begin
  Result := TList<string>.Create;
  I := 1;
  while I <= Length(Text) do
  begin
    if TCharacter.IsLetterOrDigit(Text[I]) then
    begin
      Start := I;
      while (I <= Length(Text)) and TCharacter.IsLetterOrDigit(Text[I]) do
        Inc(I);
      Norm := NormalizeWord(Copy(Text, Start, I - Start));
      if Length(Norm) >= 2 then
        Result.Add(Norm);
    end
    else
      Inc(I);
  end;
end;

function Levenshtein(const A, B: string): Integer;
var
  Prev, Cur: array of Integer;
  I, J, Cost: Integer;
begin
  SetLength(Prev, Length(B) + 1);
  SetLength(Cur, Length(B) + 1);
  for J := 0 to Length(B) do
    Prev[J] := J;
  for I := 1 to Length(A) do
  begin
    Cur[0] := I;
    for J := 1 to Length(B) do
    begin
      if A[I] = B[J] then
        Cost := 0
      else
        Cost := 1;
      Cur[J] := Min(Min(Prev[J] + 1, Cur[J - 1] + 1), Prev[J - 1] + Cost);
    end;
    Prev := Cur;
  end;
  Result := Prev[Length(B)];
end;

function WordsMatch(const A, B: string): Boolean;
begin
  if A = B then
    Exit(True);
  if (Length(A) >= 4) and (Length(B) >= 4) and
    (B.StartsWith(A) or A.StartsWith(B)) then
    Exit(True);
  if (Max(Length(A), Length(B)) >= 4) and (Levenshtein(A, B) <= 1) then
    Exit(True);
  Result := False;
end;

constructor TReadAlongMatcher.Create;
begin
  inherited Create;
  FWords := TList<string>.Create;
  FOffsets := TList<Integer>.Create;
  FPointer := 0;
end;

destructor TReadAlongMatcher.Destroy;
begin
  FWords.Free;
  FOffsets.Free;
  inherited;
end;

function TReadAlongMatcher.GetCount: Integer;
begin
  Result := FWords.Count;
end;

function TReadAlongMatcher.GetAtEnd: Boolean;
begin
  Result := FPointer >= FWords.Count - 2;
end;

procedure TReadAlongMatcher.SetText(const Text: string);
var
  I, Start: Integer;
  Norm: string;
begin
  FWords.Clear;
  FOffsets.Clear;
  FPointer := 0;
  I := 1;
  while I <= Length(Text) do
  begin
    if TCharacter.IsLetterOrDigit(Text[I]) then
    begin
      Start := I;
      while (I <= Length(Text)) and TCharacter.IsLetterOrDigit(Text[I]) do
        Inc(I);
      Norm := NormalizeWord(Copy(Text, Start, I - Start));
      if Norm <> '' then
      begin
        FWords.Add(Norm);
        FOffsets.Add(Start - 1);
      end;
    end
    else
      Inc(I);
  end;
end;

function TReadAlongMatcher.Advance(const SpokenText: string): Boolean;
var
  Spoken: TList<string>;
  TailLen, I, K, MaxK, Score, BestStart, BestScore, Need, NewPtr: Integer;
  BestVal: Double;
  Tail: TList<string>;
begin
  Result := False;
  if FWords.Count = 0 then
    Exit;

  Spoken := Tokenize(SpokenText);
  try
    if Spoken.Count = 0 then
      Exit;

    TailLen := Min(8, Spoken.Count);
    Tail := TList<string>.Create;
    try
      for I := Spoken.Count - TailLen to Spoken.Count - 1 do
        Tail.Add(Spoken[I]);

      BestStart := -1;
      BestScore := 0;
      BestVal := -MaxDouble;

      for I := 0 to FWords.Count - 1 do
      begin
        Score := 0;
        MaxK := Min(Tail.Count, FWords.Count - I);
        for K := 0 to MaxK - 1 do
          if WordsMatch(Tail[K], FWords[I + K]) then
            Inc(Score);
        if Score = 0 then
          Continue;

        if (Score * 1000.0 - Abs(I - FPointer)) > BestVal then
        begin
          BestVal := Score * 1000.0 - Abs(I - FPointer);
          BestScore := Score;
          BestStart := I;
        end;
      end;

      Need := Max(3, TailLen div 2);
      if (BestScore >= Need) and (BestStart >= 0) then
      begin
        NewPtr := Min(BestStart + TailLen, FWords.Count);
        if NewPtr <> FPointer then
        begin
          FPointer := NewPtr;
          Result := True;
        end;
      end;
    finally
      Tail.Free;
    end;
  finally
    Spoken.Free;
  end;
end;

function TReadAlongMatcher.CurrentCharOffset(TotalLength: Integer): Integer;
begin
  if FPointer < FOffsets.Count then
    Result := FOffsets[FPointer]
  else
    Result := TotalLength;
end;

end.
