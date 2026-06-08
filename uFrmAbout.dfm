object FrmAbout: TFrmAbout
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'About'
  ClientHeight = 360
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
      Width = 45
      Height = 20
      Caption = 'About'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object lblAppName: TLabel
    Left = 20
    Top = 52
    Width = 120
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
    Top = 84
    Width = 80
    Height = 17
    Caption = 'Version 1.0.0'
  end
  object lblDesc: TLabel
    Left = 20
    Top = 112
    Width = 420
    Height = 60
    AutoSize = False
    Caption = 
      'Real-time interview assistant overlay. Captures system audio, transcribes on the GPU, ' +
      'and drafts an answer you can read aloud. Hidden from screen sharing.'#13#10#13#10'For study and ' +
      'informational use only.'
    WordWrap = True
  end
  object lblShortcuts: TLabel
    Left = 20
    Top = 184
    Width = 120
    Height = 15
    Caption = 'Keyboard shortcuts'
  end
  object memShortcuts: TMemo
    Left = 20
    Top = 204
    Width = 420
    Height = 72
    ReadOnly = True
    TabOrder = 1
  end
  object btnClose: TButton
    Left = 364
    Top = 292
    Width = 76
    Height = 28
    Caption = 'Close'
    TabOrder = 2
    OnClick = btnCloseClick
  end
end
