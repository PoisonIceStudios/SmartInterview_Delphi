object FrmAbout: TFrmAbout
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'About SmartInterview'
  ClientHeight = 273
  ClientWidth = 458
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblAppName: TLabel
    Left = 20
    Top = 20
    Width = 138
    Height = 25
    Caption = 'SmartInterview'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblVersion: TLabel
    Left = 20
    Top = 51
    Width = 65
    Height = 15
    Caption = 'Version 1.0.0'
  end
  object lblRegistered: TLabel
    Left = 20
    Top = 75
    Width = 75
    Height = 15
    Caption = 'Registered to: '
  end
  object lblExpiry: TLabel
    Left = 20
    Top = 99
    Width = 84
    Height = 15
    Caption = 'License expires: '
  end
  object lblShortcuts: TLabel
    Left = 20
    Top = 127
    Width = 102
    Height = 15
    Caption = 'Keyboard shortcuts'
  end
  object memShortcuts: TMemo
    Left = 20
    Top = 147
    Width = 420
    Height = 72
    ReadOnly = True
    TabOrder = 0
  end
  object btnClose: TButton
    Left = 364
    Top = 225
    Width = 76
    Height = 28
    Caption = 'Close'
    TabOrder = 1
    OnClick = btnCloseClick
  end
end
