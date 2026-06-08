object FrmSplash: TFrmSplash
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'SmartInterview'
  ClientHeight = 320
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
    Height = 288
    Align = alClient
    Proportional = True
    Stretch = True
    ExplicitTop = -6
  end
  object lblStatus: TLabel
    Left = 0
    Top = 288
    Width = 560
    Height = 32
    Align = alBottom
    Alignment = taCenter
    AutoSize = False
    Caption = 'Starting...'
    Layout = tlCenter
    ExplicitTop = 296
  end
end
