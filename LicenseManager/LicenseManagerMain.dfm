object FrmLicenseManagerMain: TFrmLicenseManagerMain
  Left = 0
  Top = 0
  Caption = 'SmartInterview License Manager'
  ClientHeight = 580
  ClientWidth = 980
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 980
    Height = 172
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 8
      Width = 115
      Height = 20
      Caption = 'License Manager'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblHint: TLabel
      Left = 16
      Top = 32
      Width = 700
      Height = 30
      AutoSize = False
      Caption = 
        'Create license keys with embedded expiry (v4). Lifetime = no exp' +
        'iry. Use presets for quick dates.'
      WordWrap = True
    end
    object lblUsername: TLabel
      Left = 16
      Top = 72
      Width = 90
      Height = 15
      Caption = 'Forum username'
    end
    object lblExpiry: TLabel
      Left = 16
      Top = 104
      Width = 36
      Height = 15
      Caption = 'Expires'
    end
    object lblPresets: TLabel
      Left = 16
      Top = 136
      Width = 37
      Height = 15
      Caption = 'Presets'
    end
    object edtUsername: TEdit
      Left = 120
      Top = 69
      Width = 200
      Height = 23
      TabOrder = 0
    end
    object dtpExpiry: TDateTimePicker
      Left = 120
      Top = 101
      Width = 200
      Height = 23
      Date = 46021.000000000000000000
      Time = 0.999988425923220300
      TabOrder = 1
    end
    object chkLifetime: TCheckBox
      Left = 336
      Top = 103
      Width = 80
      Height = 17
      Caption = 'Lifetime'
      TabOrder = 2
      OnClick = chkLifetimeClick
    end
    object chkActive: TCheckBox
      Left = 424
      Top = 103
      Width = 60
      Height = 17
      Caption = 'Active'
      Checked = True
      State = cbChecked
      TabOrder = 3
    end
    object btnCreate: TButton
      Left = 860
      Top = 131
      Width = 120
      Height = 27
      Caption = 'Create license'
      TabOrder = 4
      OnClick = btnCreateClick
    end
    object btn1Month: TButton
      Left = 120
      Top = 132
      Width = 72
      Height = 25
      Caption = '+1 month'
      TabOrder = 5
      OnClick = btnPresetClick
    end
    object btn3Month: TButton
      Left = 200
      Top = 132
      Width = 72
      Height = 25
      Caption = '+3 months'
      TabOrder = 6
      OnClick = btnPresetClick
    end
    object btn6Month: TButton
      Left = 280
      Top = 132
      Width = 72
      Height = 25
      Caption = '+6 months'
      TabOrder = 7
      OnClick = btnPresetClick
    end
    object btn12Month: TButton
      Left = 360
      Top = 132
      Width = 80
      Height = 25
      Caption = '+12 months'
      TabOrder = 8
      OnClick = btnPresetClick
    end
  end
  object lvLicenses: TListView
    Left = 0
    Top = 172
    Width = 980
    Height = 408
    Align = alClient
    Columns = <
      item
        Caption = 'Username'
        Width = 120
      end
      item
        Caption = 'License key'
        Width = 340
      end
      item
        Caption = 'Registered'
        Width = 130
      end
      item
        Caption = 'Expiry'
        Width = 100
      end
      item
        Caption = 'Active'
        Width = 60
      end>
    GridLines = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnSelectItem = lvLicensesSelectItem
  end
end
