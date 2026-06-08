object FrmLicense: TFrmLicense
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'License activation'
  ClientHeight = 265
  ClientWidth = 540
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblInfo: TLabel
    Left = 20
    Top = 24
    Width = 500
    Height = 50
    AutoSize = False
    Caption = 
      'Enter your forum username and the license code you received afte' +
      'r purchase.'#13#10'An internet connection is required to verify the li' +
      'cense.'
    WordWrap = True
  end
  object lblForum: TLabel
    Left = 20
    Top = 92
    Width = 90
    Height = 15
    Caption = 'Forum username'
  end
  object lblLicense: TLabel
    Left = 20
    Top = 144
    Width = 68
    Height = 15
    Caption = 'License code'
  end
  object lblStatus: TLabel
    Left = 20
    Top = 193
    Width = 500
    Height = 15
    AutoSize = False
  end
  object edtForum: TEdit
    Left = 20
    Top = 112
    Width = 500
    Height = 23
    TabOrder = 0
  end
  object edtLicense: TEdit
    Left = 20
    Top = 164
    Width = 500
    Height = 23
    TabOrder = 1
  end
  object btnExit: TButton
    Left = 342
    Top = 214
    Width = 76
    Height = 28
    Caption = 'Exit'
    TabOrder = 2
    OnClick = btnExitClick
  end
  object btnActivate: TButton
    Left = 424
    Top = 214
    Width = 96
    Height = 28
    Caption = 'Activate'
    TabOrder = 3
    OnClick = btnActivateClick
  end
end
