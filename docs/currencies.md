# Currencies

Every currency BetterBudget offers (owner, 2026-10-02: "I want to support all the
currencies"). The list is built into the app: `app/lib/domain/currencies.dart` (code,
symbol, decimals) and `app/lib/l10n/currency_names.dart` (English and Mongolian
names), both written by `app/tool/gen_currencies.py` from the sources below. The
database stores each account's currency as its code.

## Where the list comes from

- **Codes, names and decimals:** ISO 4217 "List One", the current currencies, from
  SIX, which maintains the standard for ISO (published 2026-09-17).
- **Symbols and the English and Mongolian names:** Unicode CLDR (`cldr-numbers-full`,
  `en` and `mn`). The symbol is CLDR's narrow one (`$`, not `US$`).
- Downloaded once while writing this document. The app itself never fetches it
  (nothing leaves the machine); the list would be compiled in.

## What's in and out

**155 currencies are in.** 23 ISO codes are left out because they aren't money a
person holds: gold, silver, platinum and palladium (XAU, XAG, XPT, XPD); bond-market
and accounting units (XBA, XBB, XBC, XBD, XDR, XUA, XSU, XAD); funds and indexed units
(BOV, CLF, COU, MXV, CHE, CHW, USN, UYI, UYW); and the test and "no currency" codes
(XTS, XXX).

## How the app treats them (built 2026-10-02)

1. **Each currency has its own decimals.** 132 have 2, 16 have none (yen, won, dong)
   and 7 have 3 (the Kuwaiti, Bahraini, Jordanian, Omani, Tunisian, Libyan and Iraqi
   dinars). Amounts are whole minor units of the account's currency: ¥1,200 is
   stored as 1200, KWD 1.500 as 1500. Typing, showing and bank-file import all go
   by the account's currency.
2. **Every currency has a symbol, the one its people write** (owner, 2026-10-02).
   - 84 come from CLDR's short symbols: `$` for every dollar and peso, `¥` for yen
     and yuan, `£`, `kr`, `zł`, `R`, `FG`, `FCFA`.
   - The other 71, where CLDR has none, are in `SYMBOLS` in
     `app/tool/gen_currencies.py`: the sign or abbreviation in common use, checked
     against the open `xsolla/currency-format` data where it has one (`฿`, `₦`,
     `₸`, `₾`, `Fr.`, `KSh`, `S/`).
   - **Where the native symbol is in Arabic script** (the Gulf and North African
     dinars, dirhams and riyals, the afghani) the Latin abbreviation used beside
     English is given: `KD`, `Dh`, `SR`, `Af`. The app's languages read left to
     right; the Arabic forms would be for an Arabic interface.
   - Letters are set off from the amount by a space (`kr 1,200.00`, `KD 1.500`); a
     sign isn't (`฿1,200.00`).
   - **A small font is bundled for 13 signs** neither Onest nor Manrope has (֏ ৳ ฿
     ៛ ₡ ₦ ₭ ₲ ₵ ₸ ₼ ₾ ⃀): `BetterBudgetSymbols.ttf`, 3 KB, cut from Noto fonts
     (SIL Open Font License) by `app/tool/gen_symbol_font.py`. The generator stops
     if a symbol can't be drawn.
3. **Two currencies with one symbol are told apart only while a ledger holds
   both.** A Canadian account alone reads `$1,200.00`; beside a US account it
   reads `CA$1,200.00` and the US one stays `$`. The longer form is CLDR's
   (`CA$`, `A$`, `CN¥`) or, with none, the code (`CLP 1,200` beside `COP 1,200`).
   No two longer forms are the same.
4. **The Symbol column below** is what the app shows as the symbol.
5. **A transfer between currencies** says its rate as what one unit of the dearer
   currency costs in the other ("₮3,450.00 per $1", "¥150 per $1").
6. **Add account** has a Currency dropdown of all of them with a search (by name or
   code): tugrik and dollars first, then by name. Each row is the symbol (when it
   has one), the name, and the code at the end. A category's Currency dropdown lists the currencies there are accounts in.
7. **The Mongolian names** are CLDR's (two it lacks, SVC and VED, are drafts) and
   need the native speaker's check with the rest.

**Not done:** Savings still counts one currency (the one most accounts are in);
import still recognises only tugrik or dollars named in a file, for its warning;
changing an account's currency after it's made (ROADMAP E).

## The list

"Where" is as ISO lists it, the first three places.

| Code | English | Монгол | Symbol | Decimals | Where |
|---|---|---|---|---|---|
| AED | United Arab Emirates Dirham | арабын нэгдсэн эмиратын дирхам | Dh | 2 | United Arab Emirates |
| AFN | Afghan Afghani | Афганистаны афгани | Af | 2 | Afghanistan |
| ALL | Albanian Lek | Албанийн лек | L | 2 | Albania |
| AMD | Armenian Dram | Арменийн драм | ֏ | 2 | Armenia |
| AOA | Angolan Kwanza | Анголын кванза | Kz | 2 | Angola |
| ARS | Argentine Peso | Аргентины песо | $ | 2 | Argentina |
| AUD | Australian Dollar | Австралийн доллар | $ | 2 | Australia, Christmas Island, Cocos (Keeling) Islands and 5 more |
| AWG | Aruban Florin | Арубын флорин | ƒ | 2 | Aruba |
| AZN | Azerbaijani Manat | Азербайжаны манат | ₼ | 2 | Azerbaijan |
| BAM | Bosnia-Herzegovina Convertible Mark | Босни-Герцеговины хөрвөгч марк | KM | 2 | Bosnia and Herzegovina |
| BBD | Barbadian Dollar | барбадос доллар | $ | 2 | Barbados |
| BDT | Bangladeshi Taka | Бангладешийн така | ৳ | 2 | Bangladesh |
| BHD | Bahraini Dinar | Бахрейн динар | BD | 3 | Bahrain |
| BIF | Burundian Franc | Бурундийн франк | FBu | 0 | Burundi |
| BMD | Bermudan Dollar | Бермудын доллар | $ | 2 | Bermuda |
| BND | Brunei Dollar | Брунейн доллар | $ | 2 | Brunei Darussalam |
| BOB | Bolivian Boliviano | Боливийн боливиано | Bs | 2 | Bolivia (Plurinational State Of) |
| BRL | Brazilian Real | Бразилийн реал | R$ | 2 | Brazil |
| BSD | Bahamian Dollar | Багамын доллар | $ | 2 | Bahamas |
| BTN | Bhutanese Ngultrum | Бутаны нгултрум | Nu. | 2 | Bhutan |
| BWP | Botswanan Pula | Ботсванийн пула | P | 2 | Botswana |
| BYN | Belarusian Ruble | Беларусийн рубль | Br | 2 | Belarus |
| BZD | Belize Dollar | Белизийн доллар | $ | 2 | Belize |
| CAD | Canadian Dollar | канад доллар | $ | 2 | Canada |
| CDF | Congolese Franc | Конгогийн франк | FC | 2 | Congo (The Democratic Republic of The) |
| CHF | Swiss Franc | Швейцарийн франк | Fr. | 2 | Liechtenstein, Switzerland |
| CLP | Chilean Peso | Чилийн песо | $ | 0 | Chile |
| CNY | Chinese Yuan | Хятадын юань | ¥ | 2 | China |
| COP | Colombian Peso | Колумбын песо | $ | 2 | Colombia |
| CRC | Costa Rican Colón | Коста-Рикагийн колон | ₡ | 2 | Costa Rica |
| CUP | Cuban Peso | Кубын песо | $ | 2 | Cuba |
| CVE | Cape Verdean Escudo | Кабо-Вердийн эскудо | Esc | 2 | Cabo Verde |
| CZK | Czech Koruna | Чехийн крон | Kč | 2 | Czechia |
| DJF | Djiboutian Franc | Жибутийн франк | Fdj | 0 | Djibouti |
| DKK | Danish Krone | Данийн крон | kr | 2 | Denmark, Faroe Islands, Greenland |
| DOP | Dominican Peso | Доминиканы песо | $ | 2 | Dominican Republic |
| DZD | Algerian Dinar | Алжирийн доллар | DA | 2 | Algeria |
| EGP | Egyptian Pound | Египетийн фунт | E£ | 2 | Egypt |
| ERN | Eritrean Nakfa | Эритрейн накфа | Nfk | 2 | Eritrea |
| ETB | Ethiopian Birr | Этиопын бирр | Br | 2 | Ethiopia |
| EUR | Euro | евро | € | 2 | Åland Islands, Andorra, Austria and 34 more |
| FJD | Fijian Dollar | Фижигийн доллар | $ | 2 | Fiji |
| FKP | Falkland Islands Pound | Фолклендийн арлуудын паунд | £ | 2 | Falkland Islands [Malvinas] |
| GBP | British Pound | Британийн фунт | £ | 2 | Guernsey, Isle of Man, Jersey and 1 more |
| GEL | Georgian Lari | Гүржийн лари | ₾ | 2 | Georgia |
| GHS | Ghanaian Cedi | Ганагийн седи | GH₵ | 2 | Ghana |
| GIP | Gibraltar Pound | Гибралтарын фунт | £ | 2 | Gibraltar |
| GMD | Gambian Dalasi | Гамбийн даласи | D | 2 | Gambia |
| GNF | Guinean Franc | Гвинейн франк | FG | 0 | Guinea |
| GTQ | Guatemalan Quetzal | Гватемалын кецал | Q | 2 | Guatemala |
| GYD | Guyanaese Dollar | Гайанын доллар | $ | 2 | Guyana |
| HKD | Hong Kong Dollar | Хонг Конгийн доллар | $ | 2 | Hong Kong |
| HNL | Honduran Lempira | Гондурасын лемпира | L | 2 | Honduras |
| HTG | Haitian Gourde | Гаитийн гурд | G | 2 | Haiti |
| HUF | Hungarian Forint | Унгарын форинт | Ft | 2 | Hungary |
| IDR | Indonesian Rupiah | Индонезийн рупи | Rp | 2 | Indonesia |
| ILS | Israeli New Shekel | Израилийн шинэ шекел | ₪ | 2 | Israel |
| INR | Indian Rupee | Энэтхэгийн рупи | ₹ | 2 | Bhutan, India |
| IQD | Iraqi Dinar | Иракийн динар | ID | 3 | Iraq |
| IRR | Iranian Rial | Ираны риял | Rl | 2 | Iran (Islamic Republic Of) |
| ISK | Icelandic Króna | Исландын крон | kr | 0 | Iceland |
| JMD | Jamaican Dollar | Ямайкийн доллар | $ | 2 | Jamaica |
| JOD | Jordanian Dinar | Йорданы динар | JD | 3 | Jordan |
| JPY | Japanese Yen | Японы иен | ¥ | 0 | Japan |
| KES | Kenyan Shilling | Кенийн шиллинг | KSh | 2 | Kenya |
| KGS | Kyrgyz Som | Кыргызын сом | ⃀ | 2 | Kyrgyzstan |
| KHR | Cambodian Riel | Камбожийн риел | ៛ | 2 | Cambodia |
| KMF | Comorian Franc | Коморын франк | CF | 0 | Comoros |
| KPW | North Korean Won | Хойд Солонгосын вон | ₩ | 2 | Korea (The Democratic People’S Republic Of) |
| KRW | South Korean Won | Өмнөд Солонгосын вон | ₩ | 0 | Korea (The Republic Of) |
| KWD | Kuwaiti Dinar | Кувейтийн динар | KD | 3 | Kuwait |
| KYD | Cayman Islands Dollar | Кайманы арлуудын доллар | $ | 2 | Cayman Islands |
| KZT | Kazakhstani Tenge | Казахстаны тэнгэ | ₸ | 2 | Kazakhstan |
| LAK | Laotian Kip | Лаосын кип | ₭ | 2 | Lao People’S Democratic Republic |
| LBP | Lebanese Pound | Ливаны фунт | L£ | 2 | Lebanon |
| LKR | Sri Lankan Rupee | Шри-Ланкийн рупи | Rs | 2 | Sri Lanka |
| LRD | Liberian Dollar | Либерийн доллар | $ | 2 | Liberia |
| LSL | Lesotho Loti | Лесото лоти | L | 2 | Lesotho |
| LYD | Libyan Dinar | Ливийн доллар | LD | 3 | Libya |
| MAD | Moroccan Dirham | Мороккогийн дирхэм | DH | 2 | Morocco, Western Sahara |
| MDL | Moldovan Leu | Молдовын лей | L | 2 | Moldova (The Republic Of) |
| MGA | Malagasy Ariary | Малагасийн ариари | Ar | 2 | Madagascar |
| MKD | Macedonian Denar | Македонийн динар | ден | 2 | North Macedonia |
| MMK | Myanmar Kyat | Мьянмарын киат | K | 2 | Myanmar |
| MNT | Mongolian Tugrik | Монгол төгрөг | ₮ | 2 | Mongolia |
| MOP | Macanese Pataca | Макаогийн патака | MOP$ | 2 | Macao |
| MRU | Mauritanian Ouguiya | Мавританийн угия | UM | 2 | Mauritania |
| MUR | Mauritian Rupee | Маврикийн рупи | Rs | 2 | Mauritius |
| MVR | Maldivian Rufiyaa | Мальдивийн руфия | Rf | 2 | Maldives |
| MWK | Malawian Kwacha | Малавийн квача | MK | 2 | Malawi |
| MXN | Mexican Peso | Мексикийн песо | $ | 2 | Mexico |
| MYR | Malaysian Ringgit | Малайзын рингит | RM | 2 | Malaysia |
| MZN | Mozambican Metical | Мозамбикийн метикал | MT | 2 | Mozambique |
| NAD | Namibian Dollar | Намибийн доллар | $ | 2 | Namibia |
| NGN | Nigerian Naira | Нигерийн найра | ₦ | 2 | Nigeria |
| NIO | Nicaraguan Córdoba | Никарагуагийн кордоба | C$ | 2 | Nicaragua |
| NOK | Norwegian Krone | Норвегийн крон | kr | 2 | Bouvet Island, Norway, Svalbard and Jan Mayen |
| NPR | Nepalese Rupee | Балбын рупи | Rs | 2 | Nepal |
| NZD | New Zealand Dollar | Шинэ Зеландын доллар | $ | 2 | Cook Islands, New Zealand, Niue and 2 more |
| OMR | Omani Rial | Оманийн риал | RO | 3 | Oman |
| PAB | Panamanian Balboa | Панамын бальбоа | B/. | 2 | Panama |
| PEN | Peruvian Sol | Перугийн соль | S/ | 2 | Peru |
| PGK | Papua New Guinean Kina | Папуа-Шинэ Гвинейн кина | K | 2 | Papua New Guinea |
| PHP | Philippine Peso | Филиппиний песо | ₱ | 2 | Philippines |
| PKR | Pakistani Rupee | Пакистаны рупи | Rs | 2 | Pakistan |
| PLN | Polish Zloty | Польшийн злот | zł | 2 | Poland |
| PYG | Paraguayan Guarani | Парагвайн гуарани | ₲ | 0 | Paraguay |
| QAR | Qatari Riyal | Катарын риал | QR | 2 | Qatar |
| RON | Romanian Leu | Румыны лей | lei | 2 | Romania |
| RSD | Serbian Dinar | Сербийн динар | дин. | 2 | Serbia |
| RUB | Russian Ruble | Оросын рубль | ₽ | 2 | Russian Federation |
| RWF | Rwandan Franc | Руандагийн франк | RF | 0 | Rwanda |
| SAR | Saudi Riyal | Саудын риял | SR | 2 | Saudi Arabia |
| SBD | Solomon Islands Dollar | Соломоны арлуудын доллар | $ | 2 | Solomon Islands |
| SCR | Seychellois Rupee | Сейшелийн рупи | SR | 2 | Seychelles |
| SDG | Sudanese Pound | Суданы фунт | LS | 2 | Sudan |
| SEK | Swedish Krona | Шведийн крон | kr | 2 | Sweden |
| SGD | Singapore Dollar | Сингапурын доллар | $ | 2 | Singapore |
| SHP | St. Helena Pound | Сент Хеленагийн фунт | £ | 2 | Saint Helena, Ascension and Tristan Da Cunha |
| SLE | Sierra Leonean Leone | Сьерра-Леоны леон | Le | 2 | Sierra Leone |
| SOS | Somali Shilling | Сомалийн шиллинг | Sh.So. | 2 | Somalia |
| SRD | Surinamese Dollar | Суринамын доллар | $ | 2 | Suriname |
| SSP | South Sudanese Pound | Өмнөд Суданы фунт | £ | 2 | South Sudan |
| STN | São Tomé & Príncipe Dobra | Сан-Томе ба Принсипигийн добра | Db | 2 | Sao Tome and Principe |
| SVC | Salvadoran Colón | (none in CLDR) | ₡ | 2 | El Salvador |
| SYP | Syrian Pound | Сирийн фунт | £ | 2 | Syrian Arab Republic |
| SZL | Swazi Lilangeni | Свазиландын лилангени | E | 2 | Eswatini |
| THB | Thai Baht | Тайландын бат | ฿ | 2 | Thailand |
| TJS | Tajikistani Somoni | Тажикийн сомон | SM | 2 | Tajikistan |
| TMT | Turkmenistani Manat | Туркмены манат | m | 2 | Turkmenistan |
| TND | Tunisian Dinar | Тунисын доллар | DT | 3 | Tunisia |
| TOP | Tongan Paʻanga | Тонгагийн панга | T$ | 2 | Tonga |
| TRY | Turkish Lira | Туркийн лира | ₺ | 2 | Türki̇ye |
| TTD | Trinidad & Tobago Dollar | Тринидад ба Тобагогийн доллар | $ | 2 | Trinidad and Tobago |
| TWD | New Taiwan Dollar | Шинэ Тайванийн доллар | $ | 2 | Taiwan (Province of China) |
| TZS | Tanzanian Shilling | Танзанийн шиллинг | TSh | 2 | Tanzania, United Republic Of |
| UAH | Ukrainian Hryvnia | Украины гривна | ₴ | 2 | Ukraine |
| UGX | Ugandan Shilling | Угандагийн шиллинг | USh | 0 | Uganda |
| USD | US Dollar | америк доллар | $ | 2 | American Samoa, Bonaire, Sint Eustatius and Saba, British Indian Ocean Territory and 16 more |
| UYU | Uruguayan Peso | Уругвайн песо | $ | 2 | Uruguay |
| UZS | Uzbekistani Som | Узбекийн сом | so’m | 2 | Uzbekistan |
| VED | Bolívar Soberano | (none in CLDR) | Bs.D | 2 | Venezuela (Bolivarian Republic Of) |
| VES | Venezuelan Bolívar | Венесуэлийн боливар | Bs.S | 2 | Venezuela (Bolivarian Republic Of) |
| VND | Vietnamese Dong | Вьетнамын донг | ₫ | 0 | Viet Nam |
| VUV | Vanuatu Vatu | Вануатугийн вату | VT | 0 | Vanuatu |
| WST | Samoan Tala | Самоагийн тала | WS$ | 2 | Samoa |
| XAF | Central African CFA Franc | Төв Африкийн франк | FCFA | 0 | Cameroon, Central African Republic, Chad and 3 more |
| XCD | East Caribbean Dollar | Зүүн Карибийн доллар | $ | 2 | Anguilla, Antigua and Barbuda, Dominica and 5 more |
| XCG | Caribbean guilder | Карибын гулдер | Cg. | 2 | Curaçao, Sint Maarten (Dutch Part) |
| XOF | West African CFA Franc | Баруун Африкийн франк | CFA | 0 | Benin, Burkina Faso, Côte D'Ivoire and 5 more |
| XPF | CFP Franc | Францын колонийн франк | CFPF | 0 | French Polynesia, New Caledonia, Wallis and Futuna |
| YER | Yemeni Rial | Йемений риял | YR | 2 | Yemen |
| ZAR | South African Rand | Өмнөд Африкийн ранд | R | 2 | Lesotho, Namibia, South Africa |
| ZMW | Zambian Kwacha | Замбийн квача | ZK | 2 | Zambia |
| ZWG | Zimbabwean Gold | Зимбабвегийн гоулд | ZiG | 2 | Zimbabwe |
