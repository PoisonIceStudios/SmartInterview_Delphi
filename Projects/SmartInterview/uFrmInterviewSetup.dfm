object FrmInterviewSetup: TFrmInterviewSetup
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Interview setup'
  ClientHeight = 145
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lblInfo: TLabel
    Left = 20
    Top = 24
    Width = 420
    Height = 60
    AutoSize = False
    Caption = 
      'You can optionally add your role, tech stack, or background so a' +
      'nswers fit the interview better.'#13#10#13#10'Everything is optional. Data' +
      ' is saved in the Windows registry on this PC only.'
    WordWrap = True
  end
  object btnSetup: TButton
    Left = 20
    Top = 98
    Width = 112
    Height = 28
    Caption = 'Set up now'
    TabOrder = 0
    OnClick = btnSetupClick
  end
  object btnSkip: TButton
    Left = 332
    Top = 98
    Width = 108
    Height = 28
    Caption = 'Skip for now'
    TabOrder = 1
    OnClick = btnSkipClick
  end
end
