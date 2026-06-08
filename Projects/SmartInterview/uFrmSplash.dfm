object FrmSplash: TFrmSplash
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'SmartInterview'
  ClientHeight = 282
  ClientWidth = 560
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object imgSplash: TImage
    Left = 0
    Top = 0
    Width = 560
    Height = 282
    Align = alClient
    Proportional = True
    Stretch = True
    ExplicitTop = -6
    ExplicitHeight = 288
  end
  object lblStatus: TLabel
    Left = 0
    Top = 224
    Width = 560
    Height = 58
    Alignment = taCenter
    AutoSize = False
    Caption = 'Starting...'
    Layout = tlCenter
  end
end
