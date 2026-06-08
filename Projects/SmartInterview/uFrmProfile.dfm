object FrmProfile: TFrmProfile
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Interview setup (optional)'
  ClientHeight = 480
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
      Width = 180
      Height = 20
      Caption = 'Interview setup (optional)'
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
    Top = 52
    Width = 500
    Height = 30
    AutoSize = False
    Caption = 'All fields are optional. Fill only what helps; the app works fine with everything empty.'
    WordWrap = True
  end
  object lblRole: TLabel
    Left = 20
    Top = 92
    Width = 65
    Height = 15
    Caption = 'Target role'
  end
  object edtRole: TEdit
    Left = 20
    Top = 112
    Width = 500
    Height = 23
    TabOrder = 1
  end
  object lblStack: TLabel
    Left = 20
    Top = 144
    Width = 60
    Height = 15
    Caption = 'Tech stack'
  end
  object edtStack: TEdit
    Left = 20
    Top = 164
    Width = 500
    Height = 23
    TabOrder = 2
  end
  object lblJob: TLabel
    Left = 20
    Top = 196
    Width = 130
    Height = 15
    Caption = 'Job description / focus'
  end
  object memJob: TMemo
    Left = 20
    Top = 216
    Width = 500
    Height = 72
    ScrollBars = ssVertical
    TabOrder = 3
  end
  object lblExp: TLabel
    Left = 20
    Top = 296
    Width = 130
    Height = 15
    Caption = 'Experience / CV summary'
  end
  object memExp: TMemo
    Left = 20
    Top = 316
    Width = 500
    Height = 90
    ScrollBars = ssVertical
    TabOrder = 4
  end
  object btnLater: TButton
    Left = 260
    Top = 424
    Width = 84
    Height = 28
    Caption = 'Not now'
    TabOrder = 5
    OnClick = btnLaterClick
  end
  object btnClear: TButton
    Left = 352
    Top = 424
    Width = 88
    Height = 28
    Caption = 'Clear all'
    TabOrder = 6
    OnClick = btnClearClick
  end
  object btnSave: TButton
    Left = 444
    Top = 424
    Width = 76
    Height = 28
    Caption = 'Save'
    TabOrder = 7
    OnClick = btnSaveClick
  end
end
