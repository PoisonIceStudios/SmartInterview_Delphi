object FrmSettings: TFrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Automatic mode'
  ClientHeight = 360
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
  OnShow = FormShow
  TextHeight = 15
  object lblInfo: TLabel
    Left = 20
    Top = 52
    Width = 390
    Height = 40
    AutoSize = False
    Caption = 'Listens to PC audio only (interviewer). Your microphone is not used in automatic mode. Settings are saved automatically.'
    WordWrap = True
  end
  object lblMeter: TLabel
    Left = 20
    Top = 128
    Width = 280
    Height = 15
    Caption = 'PC audio level (line = voice threshold)'
  end
  object lblState: TLabel
    Left = 20
    Top = 180
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
    Top = 204
    Width = 81
    Height = 15
    Caption = 'Voice threshold'
  end
  object lblSilence: TLabel
    Left = 20
    Top = 256
    Width = 85
    Height = 15
    Caption = 'Silence duration'
  end
  object lblMin: TLabel
    Left = 20
    Top = 308
    Width = 93
    Height = 15
    Caption = 'Minimum speech'
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
      Width = 113
      Height = 20
      Caption = 'Automatic mode'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object chkAuto: TCheckBox
    Left = 20
    Top = 100
    Width = 200
    Height = 17
    Caption = 'Enable automatic mode'
    TabOrder = 1
    OnClick = chkAutoClick
  end
  object pnlMeterWrap: TPanel
    Left = 20
    Top = 148
    Width = 390
    Height = 22
    BevelOuter = bvNone
    TabOrder = 2
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
    Top = 220
    Width = 398
    Height = 33
    Max = 1000
    TabOrder = 3
    TickMarks = tmBoth
    OnChange = trkThreshChange
  end
  object trkSilence: TTrackBar
    Left = 16
    Top = 272
    Width = 398
    Height = 33
    Max = 2500
    Min = 200
    Frequency = 100
    Position = 800
    TabOrder = 4
    TickMarks = tmBoth
    OnChange = trkSilenceChange
  end
  object trkMin: TTrackBar
    Left = 16
    Top = 324
    Width = 398
    Height = 33
    Max = 2000
    Min = 100
    Frequency = 100
    Position = 400
    TabOrder = 5
    TickMarks = tmBoth
    OnChange = trkMinChange
  end
  object tmrMeter: TTimer
    Enabled = False
    Interval = 50
    OnTimer = tmrMeterTimer
    Left = 384
    Top = 8
  end
end
