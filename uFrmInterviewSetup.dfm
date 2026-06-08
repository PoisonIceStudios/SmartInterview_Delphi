object FrmInterviewSetup: TFrmInterviewSetup
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Interview setup'
  ClientHeight = 200
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object pnlTitle: TPanel
    Left = 0
    Top = 0
    Width = 460
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 10
      Width = 110
      Height = 20
      Caption = 'Interview setup'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object lblInfo: TLabel
    Left = 20
    Top = 56
    Width = 420
    Height = 60
    AutoSize = False
    Caption = 
      'You can optionally add your role, tech stack, or background so answers fit the interview ' +
      'better.'#13#10#13#10'Everything is optional. Data is saved in the Windows registry on this PC ' +
      'only.'
    WordWrap = True
  end
  object btnSetup: TButton
    Left = 20
    Top = 140
    Width = 112
    Height = 28
    Caption = 'Set up now'
    TabOrder = 1
    OnClick = btnSetupClick
  end
  object btnSkip: TButton
    Left = 328
    Top = 140
    Width = 108
    Height = 28
    Caption = 'Skip for now'
    TabOrder = 2
    OnClick = btnSkipClick
  end
end
