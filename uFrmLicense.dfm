object FrmLicense: TFrmLicense
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'License activation'
  ClientHeight = 420
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
    Height = 40
    AutoSize = False
    Caption = 
      'Generate an activation request code and email it to licensing@smartinterview.app to receive ' +
      'your license key.'
    WordWrap = True
  end
  object lblForum: TLabel
    Left = 20
    Top = 108
    Width = 90
    Height = 15
    Caption = 'Forum username'
  end
  object edtForum: TEdit
    Left = 20
    Top = 128
    Width = 500
    Height = 23
    TabOrder = 1
  end
  object lblActivation: TLabel
    Left = 20
    Top = 160
    Width = 130
    Height = 15
    Caption = 'Activation request code'
  end
  object edtActivation: TEdit
    Left = 20
    Top = 180
    Width = 500
    Height = 23
    ReadOnly = True
    TabOrder = 2
  end
  object btnGenerate: TButton
    Left = 20
    Top = 212
    Width = 88
    Height = 28
    Caption = 'Generate'
    TabOrder = 3
    OnClick = btnGenerateClick
  end
  object btnCopy: TButton
    Left = 114
    Top = 212
    Width = 118
    Height = 28
    Caption = 'Copy for email'
    TabOrder = 4
    OnClick = btnCopyClick
  end
  object lblLicense: TLabel
    Left = 20
    Top = 252
    Width = 65
    Height = 15
    Caption = 'License key'
  end
  object edtLicense: TEdit
    Left = 20
    Top = 272
    Width = 500
    Height = 23
    TabOrder = 5
  end
  object lblStatus: TLabel
    Left = 20
    Top = 304
    Width = 500
    Height = 15
    AutoSize = False
    Caption = ''
  end
  object btnExit: TButton
    Left = 344
    Top = 336
    Width = 76
    Height = 28
    Caption = 'Exit'
    TabOrder = 6
    OnClick = btnExitClick
  end
  object btnActivate: TButton
    Left = 424
    Top = 336
    Width = 96
    Height = 28
    Caption = 'Activate'
    TabOrder = 7
    OnClick = btnActivateClick
  end
end
