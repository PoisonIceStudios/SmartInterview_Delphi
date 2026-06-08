object FrmMicSettings: TFrmMicSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Microphone'
  ClientHeight = 330
  ClientWidth = 430
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object lblInfo: TLabel
    Left = 20
    Top = 52
    Width = 390
    Height = 32
    AutoSize = False
    Caption = 
      'Optional microphone for manual mode: pick your device and set how ' +
      'loud your voice must be before the mic is used. PC audio is alwa' +
      'ys the default source.'
    WordWrap = True
  end
  object lblDevice: TLabel
    Left = 20
    Top = 120
    Width = 104
    Height = 15
    Caption = 'Microphone device'
  end
  object lblMeter: TLabel
    Left = 20
    Top = 176
    Width = 240
    Height = 15
    Caption = 'Microphone level (line = activation threshold)'
  end
  object lblState: TLabel
    Left = 20
    Top = 228
    Width = 40
    Height = 15
    Caption = 'Silence'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblThresh: TLabel
    Left = 20
    Top = 256
    Width = 120
    Height = 15
    Caption = 'Microphone threshold'
  end
  object pnlTitle: TPanel
    Left = 0
    Top = 0
    Width = 430
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 10
      Width = 80
      Height = 20
      Caption = 'Microphone'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object chkUseMic: TCheckBox
    Left = 20
    Top = 92
    Width = 390
    Height = 17
    Caption = 'Also use microphone while holding the listening key (manual mode)'
    TabOrder = 1
    OnClick = chkUseMicClick
  end
  object cmbDevice: TComboBox
    Left = 20
    Top = 140
    Width = 390
    Height = 23
    Style = csDropDownList
    TabOrder = 2
    OnChange = cmbDeviceChange
  end
  object pnlMeterWrap: TPanel
    Left = 20
    Top = 196
    Width = 390
    Height = 22
    BevelOuter = bvNone
    TabOrder = 3
    object prgMeter: TProgressBar
      Left = 0
      Top = 0
      Width = 390
      Height = 22
      Align = alClient
      Smooth = True
      TabOrder = 0
    end
    object pbMeterOverlay: TPaintBox
      Left = 0
      Top = 0
      Width = 390
      Height = 22
      Align = alClient
      OnPaint = pbMeterOverlayPaint
    end
  end
  object trkThresh: TTrackBar
    Left = 16
    Top = 273
    Width = 398
    Height = 33
    Max = 1000
    Position = 500
    TabOrder = 4
    TickMarks = tmBoth
    OnChange = trkThreshChange
  end
  object tmrMeter: TTimer
    Enabled = False
    Interval = 50
    OnTimer = tmrMeterTimer
    Left = 384
    Top = 8
  end
end
