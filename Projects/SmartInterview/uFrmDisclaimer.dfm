object FrmDisclaimer: TFrmDisclaimer
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Terms and Conditions'
  ClientHeight = 465
  ClientWidth = 565
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object memEula: TMemo
    Left = 16
    Top = 16
    Width = 540
    Height = 364
    Lines.Strings = (
      'END-USER LICENSE AGREEMENT AND DISCLAIMER OF LIABILITY'
      ''
      
        'Please read this agreement carefully. By checking the acceptance' +
        ' box and using this software '
      '(the '
      
        '"Software"), you acknowledge that you have read, understood, and' +
        ' agree to be bound by all of '
      'the terms below. If you do not agree, do not use the Software.'
      ''
      '1. LICENSE GRANT - PERSONAL, NON-TRANSFERABLE.'
      
        'The Software is licensed, not sold. You may use the Software onl' +
        'y if you have obtained a valid '
      
        'license key issued by the Provider for your computer and your fo' +
        'rum username. Each license is '
      
        'personal, non-transferable, and bound to the machine and usernam' +
        'e for which it was issued. '
      'You '
      
        'may not share, lend, resell, sublicense, or make the Software av' +
        'ailable to any third party.'
      ''
      '2. PROHIBITED CONDUCT.'
      
        'You must not: (a) copy, distribute, publish, upload, or share th' +
        'e Software or any license key; (b) '
      
        'attempt to crack, bypass, remove, or tamper with license protect' +
        'ion; (c) reverse engineer, '
      
        'decompile, or modify the Software except where expressly permitt' +
        'ed by law; (d) use another '
      
        'person'#39's license key or forum username; or (e) assist others in ' +
        'doing any of the above. '
      
        'Unauthorized distribution helps identify the source user through' +
        ' the licensed forum username '
      
        'embedded in the activation system. Any breach may result in imme' +
        'diate license revocation, '
      'permanent forum ban, and loss of access without refund.'
      ''
      '3. PURPOSE - STUDY AND INFORMATION ONLY.'
      
        'The Software is provided exclusively for personal study, researc' +
        'h, educational, and informational '
      
        'purposes. It is your responsibility to ensure that your use comp' +
        'lies with all applicable laws, '
      
        'regulations, policies, contracts, and rules of any third party, ' +
        'platform, employer, examiner, or '
      
        'institution. The Software must not be used for any unlawful, dec' +
        'eptive, fraudulent, or otherwise '
      'prohibited purpose.'
      ''
      '4. NO WARRANTY.'
      
        'The Software is provided "AS IS" and "AS AVAILABLE", without war' +
        'ranty of any kind, whether '
      
        'express, implied, statutory, or otherwise, including but not lim' +
        'ited to the implied warranties of '
      
        'merchantability, fitness for a particular purpose, accuracy, rel' +
        'iability, availability, and non-'
      
        'infringement. No advice or information obtained through the Soft' +
        'ware creates any warranty not '
      'expressly stated herein.'
      ''
      '5. COMPLETE DISCLAIMER OF LIABILITY.'
      
        'To the maximum extent permitted by applicable law, the author, d' +
        'eveloper, and licensor of the '
      
        'Software (collectively, the "Provider") shall not be liable for ' +
        'any direct, indirect, incidental, '
      'special, '
      
        'consequential, punitive, or exemplary damages, or for any loss o' +
        'f profits, data, goodwill, '
      
        'opportunity, or reputation, arising out of or in any way related' +
        ' to your access to, use of, inability '
      
        'to use, or reliance on the Software, even if advised of the poss' +
        'ibility of such damages. You '
      'assume '
      
        'the entire risk as to the quality, performance, and results of t' +
        'he Software.'
      ''
      '6. SOLE RESPONSIBILITY OF THE USER.'
      
        'You are solely and exclusively responsible for any and all use y' +
        'ou make of the Software and for '
      'any '
      
        'consequence, damage, claim, penalty, or problem of any nature re' +
        'sulting from such use, '
      
        'including any unlawful or prohibited activity. The Provider assu' +
        'mes no responsibility whatsoever '
      'for how the Software is used.'
      ''
      '7. INDEMNIFICATION.'
      
        'You agree to indemnify, defend, and hold harmless the Provider f' +
        'rom and against any and all '
      
        'claims, liabilities, damages, losses, and expenses (including re' +
        'asonable legal fees) arising out of '
      'or '
      
        'related to your use of the Software or your violation of these t' +
        'erms.'
      ''
      '8. THIRD-PARTY COMPONENTS.'
      
        'The Software may rely on third-party components and services, ea' +
        'ch governed by its own terms. '
      
        'The Provider makes no representations regarding, and is not resp' +
        'onsible for, such third-party '
      'components or services.'
      ''
      '9. TERMINATION AND ENFORCEMENT.'
      
        'Your right to use the Software ends immediately if you breach th' +
        'ese terms. The Provider may '
      
        'refuse, revoke, or decline to issue future licenses, permanently' +
        ' ban your forum account, and '
      
        'terminate your license without refund, notice, or liability in c' +
        'ase of misuse, license sharing, '
      
        'cracking, redistribution, or any unauthorized distribution. No r' +
        'efunds will be issued for revoked '
      'licenses due to breach of these terms.'
      ''
      '10. ENTIRE AGREEMENT.'
      
        'These terms constitute the entire agreement between you and the ' +
        'Provider regarding the '
      'Software '
      
        'and supersede any prior understanding. If any provision is held ' +
        'unenforceable, the remaining '
      'provisions shall remain in full force and effect.'
      ''
      
        'By checking the box below, you confirm that you accept these ter' +
        'ms and conditions in full.')
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object chkAccept: TCheckBox
    Left = 17
    Top = 386
    Width = 540
    Height = 17
    Caption = 'I accept the terms and conditions of service'
    TabOrder = 1
    OnClick = chkAcceptClick
  end
  object btnDecline: TButton
    Left = 326
    Top = 421
    Width = 132
    Height = 28
    Caption = 'Decline and Exit'
    TabOrder = 2
    OnClick = btnDeclineClick
  end
  object btnAccept: TButton
    Left = 464
    Top = 421
    Width = 84
    Height = 28
    Caption = 'Accept'
    TabOrder = 3
    OnClick = btnAcceptClick
  end
end
