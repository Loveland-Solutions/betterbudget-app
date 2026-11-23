// Made by tool/gen_number_styles.py from Unicode CLDR. Change the tool,
// not this file.

part of 'money.dart';

/// How the people of each currency write an amount, where it isn't
/// `1,234.95`; the locale it's taken from after each.
const _styles = <String, NumberStyle>{
  'AFN': NumberStyle(whole: true), // fa-AF
  'ALL': NumberStyle(point: ',', group: '\u202f', whole: true), // sq
  'AMD': NumberStyle(point: ',', group: '\u202f'), // hy
  'AOA': NumberStyle(point: ',', group: '\u202f'), // pt-AO
  'ARS': NumberStyle(point: ',', group: '.'), // es-AR
  'AWG': NumberStyle(point: ',', group: '.'), // nl-AW
  'AZN': NumberStyle(point: ',', group: '.'), // az-Latn
  'BAM': NumberStyle(point: ',', group: '.'), // bs-Cyrl
  'BIF': NumberStyle(point: ',', group: '.'), // rn
  'BND': NumberStyle(point: ',', group: '.'), // ms-BN
  'BOB': NumberStyle(point: ',', group: '.'), // es-BO
  'BRL': NumberStyle(point: ',', group: '.'), // pt
  'BYN': NumberStyle(point: ',', group: '\u202f'), // ru-BY
  'CDF': NumberStyle(point: ',', group: '\u202f'), // fr-CD
  'CHF': NumberStyle(group: '\''), // de-CH
  'CLP': NumberStyle(point: ',', group: '.'), // es-CL
  'COP': NumberStyle(point: ',', group: '.', whole: true), // es-CO
  'CRC': NumberStyle(point: ',', group: '\u202f'), // es-CR
  'CVE': NumberStyle(point: ',', group: '\u202f'), // pt-CV
  'CZK': NumberStyle(point: ',', group: '\u202f'), // cs
  'DJF': NumberStyle(point: ',', group: '\u202f'), // fr-DJ
  'DKK': NumberStyle(point: ',', group: '.'), // da
  'DZD': NumberStyle(point: ',', group: '.'), // ar-DZ
  'EUR': NumberStyle(point: ',', group: '.'), // de
  'GEL': NumberStyle(point: ',', group: '\u202f'), // ka
  'GNF': NumberStyle(point: ',', group: '\u202f'), // fr-GN
  'HUF': NumberStyle(point: ',', group: '\u202f', whole: true), // hu
  'IDR': NumberStyle(point: ',', group: '.', whole: true), // id
  'IQD': NumberStyle(whole: true), // ar-IQ
  'IRR': NumberStyle(whole: true), // fa
  'ISK': NumberStyle(point: ',', group: '.'), // is
  'KGS': NumberStyle(point: ',', group: '\u202f'), // ky
  'KPW': NumberStyle(whole: true), // ko-KP
  'KZT': NumberStyle(point: ',', group: '\u202f'), // ru-KZ
  'LAK': NumberStyle(point: ',', group: '.', whole: true), // lo
  'LBP': NumberStyle(point: ',', group: '.', whole: true), // ar-LB
  'LYD': NumberStyle(point: ',', group: '.'), // ar-LY
  'MAD': NumberStyle(point: ',', group: '.'), // ar-MA
  'MDL': NumberStyle(point: ',', group: '.'), // ro-MD
  'MGA': NumberStyle(whole: true), // mg
  'MKD': NumberStyle(point: ',', group: '.'), // mk
  'MMK': NumberStyle(whole: true), // my
  'MRU': NumberStyle(point: ',', group: '.'), // ar-MR
  'MUR': NumberStyle(point: ',', group: '\u202f'), // fr-MU
  'MZN': NumberStyle(point: ',', group: '\u202f'), // pt-MZ
  'NOK': NumberStyle(point: ',', group: '\u202f'), // no
  'PLN': NumberStyle(point: ',', group: '\u202f'), // pl
  'RON': NumberStyle(point: ',', group: '.'), // ro
  'RSD': NumberStyle(point: ',', group: '.'), // sr-Latn
  'RUB': NumberStyle(point: ',', group: '\u202f'), // ru
  'RWF': NumberStyle(point: ',', group: '.'), // rw
  'SCR': NumberStyle(point: ',', group: '\u202f'), // fr-SC
  'SEK': NumberStyle(point: ',', group: '\u202f'), // sv
  'SOS': NumberStyle(whole: true), // so
  'SRD': NumberStyle(point: ',', group: '.'), // nl-SR
  'STN': NumberStyle(point: ',', group: '\u202f'), // pt-ST
  'SYP': NumberStyle(whole: true), // ar-SY
  'TJS': NumberStyle(point: ',', group: '\u202f'), // tg
  'TMT': NumberStyle(point: ',', group: '\u202f'), // tk
  'TND': NumberStyle(point: ',', group: '.'), // ar-TN
  'TOP': NumberStyle(group: '\u202f'), // to
  'TRY': NumberStyle(point: ',', group: '.'), // tr
  'UAH': NumberStyle(point: ',', group: '\u202f'), // uk
  'UYU': NumberStyle(point: ',', group: '.'), // es-UY
  'UZS': NumberStyle(point: ',', group: '\u202f'), // uz-Latn
  'VES': NumberStyle(point: ',', group: '.'), // es-VE
  'VND': NumberStyle(point: ',', group: '.'), // vi
  'XAF': NumberStyle(point: ',', group: '\u202f'), // fr-CM
  'XOF': NumberStyle(point: ',', group: '\u202f'), // fr-CI
  'XPF': NumberStyle(point: ',', group: '\u202f'), // fr-NC
  'YER': NumberStyle(whole: true), // ar-YE
  'ZAR': NumberStyle(group: '\u202f'), // en-ZA, point as on statements
};
