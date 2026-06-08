object FrmLicense: TFrmLicense
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'License activation'
  ClientHeight = 280
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
  object pnlTitle: TPanel
    Left = 0
    Top = 0
    Width = 540
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 10
      Width = 120
      Height = 20
      Caption = 'License activation'
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
    Width = 500
    Height = 50
    AutoSize = False
    Caption = 
      'Enter your forum username and the license code you received after purchase.'#13#10'An internet connection is required to verify the license.'
    WordWrap = True
  end
  object lblForum: TLabel
    Left = 20
    Top = 116
    Width = 90
    Height = 15
    Caption = 'Forum username'
  end
  object edtForum: TEdit
    Left = 20
    Top = 136
    Width = 500
    Height = 23
    TabOrder = 1
  end
  object lblLicense: TLabel
    Left = 20
    Top = 168
    Width = 70
    Height = 15
    Caption = 'License code'
  end
  object edtLicense: TEdit
    Left = 20
    Top = 188
    Width = 500
    Height = 23
    TabOrder = 2
  end
  object lblStatus: TLabel
    Left = 20
    Top = 220
    Width = 500
    Height = 15
    AutoSize = False
    Caption = ''
  end
  object btnExit: TButton
    Left = 344
    Top = 236
    Width = 76
    Height = 28
    Caption = 'Exit'
    TabOrder = 3
    OnClick = btnExitClick
  end
  object btnActivate: TButton
    Left = 424
    Top = 236
    Width = 96
    Height = 28
    Caption = 'Activate'
    TabOrder = 4
    OnClick = btnActivateClick
  end
end
