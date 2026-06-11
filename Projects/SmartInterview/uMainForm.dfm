object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'SmartInterview'
  ClientHeight = 479
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
  object pnlTitleBar: TPanel
    Left = 0
    Top = 0
    Width = 430
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    object pnlIndicators: TPanel
      Left = 0
      Top = 0
      Width = 89
      Height = 40
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 1
      object pbWaveform: TPaintBox
        Left = 17
        Top = 6
        Width = 32
        Height = 28
        OnPaint = pbWaveformPaint
      end
      object pbMic: TPaintBox
        Left = 51
        Top = 6
        Width = 32
        Height = 28
        OnPaint = pbMicPaint
      end
    end
    object pnlTitleButtons: TPanel
      Left = 89
      Top = 0
      Width = 341
      Height = 40
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 0
      ExplicitLeft = 88
      ExplicitTop = 2
      object btnPin: TSpeedButton
        Left = 305
        Top = 0
        Width = 36
        Height = 40
        Hint = 'Always on top'
        Align = alRight
        Caption = #59160
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe MDL2 Assets'
        Font.Style = []
        ParentFont = False
        OnClick = btnPinClick
        ExplicitLeft = 216
      end
      object btnMenu: TSpeedButton
        Left = 269
        Top = 0
        Width = 36
        Height = 40
        Hint = 'Menu'
        Align = alRight
        Caption = #59136
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe MDL2 Assets'
        Font.Style = []
        ParentFont = False
        OnClick = btnMenuClick
        ExplicitLeft = 180
      end
      object btnOpDn: TSpeedButton
        Left = 233
        Top = 0
        Width = 36
        Height = 40
        Hint = 'Less transparent'
        Align = alRight
        Caption = #59192
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe MDL2 Assets'
        Font.Style = []
        ParentFont = False
        OnClick = btnOpDnClick
        ExplicitLeft = 144
      end
      object btnOpUp: TSpeedButton
        Left = 197
        Top = 0
        Width = 36
        Height = 40
        Hint = 'More transparent'
        Align = alRight
        Caption = #59152
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe MDL2 Assets'
        Font.Style = []
        ParentFont = False
        OnClick = btnOpUpClick
        ExplicitLeft = 108
      end
      object btnNew: TSpeedButton
        Left = 145
        Top = 0
        Width = 52
        Height = 40
        Hint = 'New session (resets chat)'
        Align = alRight
        Caption = #59634'   0%'
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe MDL2 Assets'
        Font.Style = []
        ParentFont = False
        OnClick = btnNewClick
        ExplicitLeft = 72
      end
      object btnAuto: TSpeedButton
        Left = 109
        Top = 0
        Width = 36
        Height = 40
        Hint = 'Automatic mode'
        Align = alRight
        Caption = #61353
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe MDL2 Assets'
        Font.Style = []
        ParentFont = False
        OnClick = btnAutoClick
        ExplicitLeft = 36
      end
      object btnSetup: TSpeedButton
        Left = 73
        Top = 0
        Width = 36
        Height = 40
        Hint = 'Interview setup'
        Align = alRight
        Caption = #61015
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe MDL2 Assets'
        Font.Style = []
        ParentFont = False
        OnClick = btnSetupClick
        ExplicitLeft = 0
      end
    end
  end
  object pnlBody: TPanel
    Left = 0
    Top = 40
    Width = 430
    Height = 391
    Align = alClient
    BevelOuter = bvNone
    Ctl3D = True
    Padding.Left = 16
    Padding.Top = 8
    Padding.Right = 16
    Padding.Bottom = 8
    ParentBackground = False
    ParentCtl3D = False
    TabOrder = 1
    object lblHeard: TLabel
      Left = 16
      Top = 8
      Width = 398
      Height = 15
      Align = alTop
      Caption = 'HEARING'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
      ExplicitWidth = 51
    end
    object lblAnswer: TLabel
      Left = 16
      Top = 95
      Width = 398
      Height = 15
      Align = alTop
      Caption = 'RESPONSE'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
      ExplicitWidth = 58
    end
    object txtTranscript: TMemo
      Left = 16
      Top = 23
      Width = 398
      Height = 72
      Align = alTop
      ReadOnly = True
      TabOrder = 0
    end
    object rtbResponse: TRichEdit
      Left = 16
      Top = 110
      Width = 398
      Height = 293
      Align = alClient
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      TabOrder = 1
      ExplicitTop = 112
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 431
    Width = 430
    Height = 48
    Align = alBottom
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 2
    object lblInterviewTitle: TLabel
      Left = 0
      Top = 0
      Width = 430
      Height = 18
      Align = alTop
      Alignment = taCenter
      Caption = 'No interview profile set'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
      Transparent = True
      Layout = tlCenter
      ExplicitWidth = 130
    end
    object lblStatusBar: TLabel
      Left = 0
      Top = 18
      Width = 430
      Height = 30
      Align = alClient
      Alignment = taCenter
      BiDiMode = bdLeftToRight
      Caption = 'Ready'
      Color = clDefault
      ParentBiDiMode = False
      ParentColor = False
      Transparent = True
      Layout = tlCenter
      ExplicitWidth = 32
      ExplicitHeight = 15
    end
  end
  object mnuMain: TPopupMenu
    Left = 32
    Top = 160
    object miInterview: TMenuItem
      Caption = 'Interview'
      object miSetup: TMenuItem
        Caption = 'Interview setup (optional)...'
        OnClick = miSetupClick
      end
      object miLang: TMenuItem
        Caption = 'Interview language'
        object miLangEn: TMenuItem
          Caption = 'English'
          Checked = True
          RadioItem = True
          OnClick = miLangClick
        end
        object miLangEs: TMenuItem
          Caption = 'Spanish'
          RadioItem = True
          OnClick = miLangClick
        end
        object miLangFr: TMenuItem
          Caption = 'French'
          RadioItem = True
          OnClick = miLangClick
        end
        object miLangDe: TMenuItem
          Caption = 'German'
          RadioItem = True
          OnClick = miLangClick
        end
        object miLangIt: TMenuItem
          Caption = 'Italian'
          RadioItem = True
          OnClick = miLangClick
        end
        object miLangRu: TMenuItem
          Caption = 'Russian'
          RadioItem = True
          OnClick = miLangClick
        end
      end
      object miLength: TMenuItem
        Caption = 'Answer length'
        object miLenShort: TMenuItem
          Caption = 'Short (quick replies)'
          OnClick = miLengthClick
        end
        object miLenMedium: TMenuItem
          Caption = 'Medium (balanced)'
          Checked = True
          OnClick = miLengthClick
        end
        object miLenLong: TMenuItem
          Caption = 'Long (detailed)'
          OnClick = miLengthClick
        end
      end
    end
    object miModels: TMenuItem
      Caption = 'Models'
      object miTrans: TMenuItem
        Caption = 'Transcription (voice)'
        object miTransFast: TMenuItem
          Caption = 'Fast'
          OnClick = miTransClick
        end
        object miTransBalanced: TMenuItem
          Caption = 'Balanced (recommended)'
          Checked = True
          OnClick = miTransClick
        end
        object miTransMax: TMenuItem
          Caption = 'Maximum accuracy'
          OnClick = miTransClick
        end
        object miTransSep: TMenuItem
          Caption = '-'
        end
        object miRemoveWhisper: TMenuItem
          Caption = 'Remove downloaded voice model'
          object miRemoveTransFast: TMenuItem
            Caption = 'Fast'
            Visible = False
            OnClick = miRemoveTransClick
          end
          object miRemoveTransBalanced: TMenuItem
            Caption = 'Balanced'
            Visible = False
            OnClick = miRemoveTransClick
          end
          object miRemoveTransMax: TMenuItem
            Caption = 'Maximum accuracy'
            Visible = False
            OnClick = miRemoveTransClick
          end
        end
      end
      object miIntel: TMenuItem
        Caption = 'Response (AI)'
        object miIntelFast: TMenuItem
          Caption = 'Fast'
          OnClick = miIntelClick
        end
        object miIntelBalanced: TMenuItem
          Caption = 'Balanced (recommended)'
          Checked = True
          OnClick = miIntelClick
        end
        object miIntelMax: TMenuItem
          Caption = 'Maximum accuracy'
          OnClick = miIntelClick
        end
        object miIntelSep: TMenuItem
          Caption = '-'
        end
        object miRemoveModel: TMenuItem
          Caption = 'Remove downloaded AI model'
          object miRemoveFast: TMenuItem
            Caption = 'Fast'
            Visible = False
            OnClick = miRemoveModelClick
          end
          object miRemoveBalanced: TMenuItem
            Caption = 'Balanced'
            Visible = False
            OnClick = miRemoveModelClick
          end
          object miRemoveMax: TMenuItem
            Caption = 'Maximum accuracy'
            Visible = False
            OnClick = miRemoveModelClick
          end
        end
      end
      object miGpuSep: TMenuItem
        Caption = '-'
      end
      object miForceCuda: TMenuItem
        Caption = 'Force CUDA on RTX 50xx (restarts engine)'
        OnClick = miForceCudaClick
      end
    end
    object miListening: TMenuItem
      Caption = 'Listening'
      object miListenKey: TMenuItem
        Caption = 'Listening key'
        object miKeyCtrl: TMenuItem
          Caption = 'Ctrl (hold)'
          Checked = True
          RadioItem = True
          OnClick = miListenKeyClick
        end
        object miKeyShift: TMenuItem
          Caption = 'Shift (hold)'
          RadioItem = True
          OnClick = miListenKeyClick
        end
        object miKeyAlt: TMenuItem
          Caption = 'Alt (hold)'
          RadioItem = True
          OnClick = miListenKeyClick
        end
      end
      object miAutoCfg: TMenuItem
        Caption = 'Automatic mode settings...'
        OnClick = miAutoCfgClick
      end
      object miMicCfg: TMenuItem
        Caption = 'Microphone settings...'
        OnClick = miMicCfgClick
      end
      object miScroll: TMenuItem
        Caption = 'Response scroll'
        object miScrollOff: TMenuItem
          Caption = 'Off'
          OnClick = miScrollClick
        end
        object miScrollAuto: TMenuItem
          Caption = 'Automatic (word by word)'
          Checked = True
          OnClick = miScrollClick
        end
        object miScrollVoice: TMenuItem
          Caption = 'Voice (follows your reading)'
          OnClick = miScrollClick
        end
        object miScrollSep: TMenuItem
          Caption = '-'
        end
        object miSpeed: TMenuItem
          Caption = 'Speed (Auto)'
          object miSpeedVSlow: TMenuItem
            Caption = 'Very slow'
            OnClick = miSpeedClick
          end
          object miSpeedSlow: TMenuItem
            Caption = 'Slow'
            OnClick = miSpeedClick
          end
          object miSpeedMed: TMenuItem
            Caption = 'Medium'
            Checked = True
            OnClick = miSpeedClick
          end
          object miSpeedFast: TMenuItem
            Caption = 'Fast'
            OnClick = miSpeedClick
          end
          object miSpeedVFast: TMenuItem
            Caption = 'Very fast'
            OnClick = miSpeedClick
          end
        end
      end
      object miAudio: TMenuItem
        Caption = 'Audio'
        Visible = False
        object miMicMenu: TMenuItem
          Caption = 'Microphone'
          object miMicDefault: TMenuItem
            Caption = 'System default'
            Checked = True
            OnClick = miMicClick
          end
          object miMic01: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic02: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic03: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic04: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic05: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic06: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic07: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic08: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic09: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic10: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic11: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic12: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic13: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic14: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
          object miMic15: TMenuItem
            Visible = False
            OnClick = miMicClick
          end
        end
        object miUseMic: TMenuItem
          Caption = 'Use microphone (with Ctrl)'
          Checked = True
          OnClick = miUseMicClick
        end
      end
    end
    object miView: TMenuItem
      Caption = 'View'
      object miWindow: TMenuItem
        Caption = 'Window'
        object miTopmost: TMenuItem
          Caption = 'Always on top'
          OnClick = miTopmostClick
        end
        object miHideCapture: TMenuItem
          Caption = 'Invisible to screen sharing'
          Checked = True
          OnClick = miHideCaptureClick
        end
        object miWinSep: TMenuItem
          Caption = '-'
        end
        object miMinimize: TMenuItem
          Caption = 'Minimize'
          OnClick = miMinimizeClick
        end
      end
      object miRespAppear: TMenuItem
        Caption = 'Response appearance'
        object miTextSize: TMenuItem
          Caption = 'Text size'
          object miSize9: TMenuItem
            Caption = '9 pt'
            OnClick = miTextSizeClick
          end
          object miSize10: TMenuItem
            Caption = '10 pt'
            Checked = True
            OnClick = miTextSizeClick
          end
          object miSize12: TMenuItem
            Caption = '12 pt'
            OnClick = miTextSizeClick
          end
          object miSize14: TMenuItem
            Caption = '14 pt'
            OnClick = miTextSizeClick
          end
          object miSize16: TMenuItem
            Caption = '16 pt'
            OnClick = miTextSizeClick
          end
          object miSize20: TMenuItem
            Caption = '20 pt'
            OnClick = miTextSizeClick
          end
        end
        object miTextColor: TMenuItem
          Caption = 'Text color'
          object miColWhite: TMenuItem
            Caption = 'Cyan (default)'
            OnClick = miTextColorClick
          end
          object miColBlue: TMenuItem
            Caption = 'Light blue'
            OnClick = miTextColorClick
          end
          object miColGreen: TMenuItem
            Caption = 'Green'
            OnClick = miTextColorClick
          end
          object miColYellow: TMenuItem
            Caption = 'Yellow'
            OnClick = miTextColorClick
          end
          object miColMagenta: TMenuItem
            Caption = 'Magenta'
            OnClick = miTextColorClick
          end
        end
      end
    end
    object miAboutSep: TMenuItem
      Caption = '-'
    end
    object miAbout: TMenuItem
      Caption = 'About SmartInterview...'
      OnClick = miAboutClick
    end
    object miExit: TMenuItem
      Caption = 'Exit'
      OnClick = miExitClick
    end
  end
  object trayIcon: TTrayIcon
    Hint = 'SmartInterview'
    PopupMenu = mnuTray
    OnDblClick = trayIconDblClick
    Left = 376
    Top = 392
  end
  object mnuTray: TPopupMenu
    Left = 88
    Top = 160
    object miTrayShow: TMenuItem
      Caption = 'Show / bring to front'
      OnClick = trayIconDblClick
    end
    object miTrayExit: TMenuItem
      Caption = 'Exit'
      OnClick = miExitClick
    end
  end
  object tmrLive: TTimer
    Enabled = False
    Interval = 450
    OnTimer = tmrLiveTimer
    Left = 144
    Top = 160
  end
  object tmrRead: TTimer
    Enabled = False
    Interval = 600
    OnTimer = tmrReadTimer
    Left = 200
    Top = 160
  end
  object tmrAnim: TTimer
    Enabled = False
    Interval = 25
    OnTimer = tmrAnimTimer
    Left = 256
    Top = 160
  end
  object tmrIcon: TTimer
    Enabled = False
    Interval = 100
    OnTimer = tmrIconTimer
    Left = 312
    Top = 160
  end
  object tmrEngine: TTimer
    Enabled = False
    Interval = 30000
    OnTimer = tmrEngineTimer
    Left = 368
    Top = 160
  end
end
