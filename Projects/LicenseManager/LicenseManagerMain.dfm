object FrmLicenseManagerMain: TFrmLicenseManagerMain
  Left = 0
  Top = 0
  BorderStyle = bsSingle
  Caption = 'SmartInterview License Manager'
  ClientHeight = 630
  ClientWidth = 757
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
    Width = 757
    Height = 113
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblUsername: TLabel
      Left = 16
      Top = 16
      Width = 90
      Height = 15
      Caption = 'Forum username'
    end
    object lblExpiry: TLabel
      Left = 16
      Top = 45
      Width = 36
      Height = 15
      Caption = 'Expires'
    end
    object lblPresets: TLabel
      Left = 16
      Top = 78
      Width = 37
      Height = 15
      Caption = 'Presets'
    end
    object edtUsername: TEdit
      Left = 120
      Top = 13
      Width = 200
      Height = 23
      TabOrder = 0
    end
    object dtpExpiry: TDateTimePicker
      Left = 120
      Top = 42
      Width = 200
      Height = 23
      Date = 46021.000000000000000000
      Time = 0.999988425923220300
      TabOrder = 1
    end
    object chkLifetime: TCheckBox
      Left = 336
      Top = 45
      Width = 80
      Height = 17
      Caption = 'Lifetime'
      TabOrder = 2
      OnClick = chkLifetimeClick
    end
    object chkActive: TCheckBox
      Left = 408
      Top = 45
      Width = 60
      Height = 17
      Caption = 'Active'
      Checked = True
      State = cbChecked
      TabOrder = 3
    end
    object btnCreate: TButton
      Left = 628
      Top = 73
      Width = 120
      Height = 27
      Caption = 'Create license'
      TabOrder = 4
      OnClick = btnCreateClick
    end
    object btn1Month: TButton
      Left = 120
      Top = 74
      Width = 72
      Height = 25
      Caption = '+1 month'
      TabOrder = 5
      OnClick = btnPresetClick
    end
    object btn3Month: TButton
      Left = 198
      Top = 74
      Width = 72
      Height = 25
      Caption = '+3 months'
      TabOrder = 6
      OnClick = btnPresetClick
    end
    object btn6Month: TButton
      Left = 276
      Top = 74
      Width = 72
      Height = 25
      Caption = '+6 months'
      TabOrder = 7
      OnClick = btnPresetClick
    end
    object btn12Month: TButton
      Left = 354
      Top = 74
      Width = 80
      Height = 25
      Caption = '+12 months'
      TabOrder = 8
      OnClick = btnPresetClick
    end
  end
  object lvLicenses: TListView
    Left = 0
    Top = 113
    Width = 757
    Height = 517
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
    PopupMenu = pmLicenses
    TabOrder = 1
    ViewStyle = vsReport
    OnMouseDown = lvLicensesMouseDown
    OnSelectItem = lvLicensesSelectItem
  end
  object pmLicenses: TPopupMenu
    OnPopup = pmLicensesPopup
    Left = 320
    Top = 240
    object miCopyKey: TMenuItem
      Caption = 'Copy key'
      OnClick = miCopyKeyClick
    end
    object miDeleteUser: TMenuItem
      Caption = 'Delete user'
      OnClick = miDeleteUserClick
    end
  end
  object mmMain: TMainMenu
    Left = 400
    Top = 240
    object miKeys: TMenuItem
      Caption = 'Keys'
      object miGenKeys: TMenuItem
        Caption = 'Generate signing keys...'
        OnClick = miGenKeysClick
      end
    end
  end
end
